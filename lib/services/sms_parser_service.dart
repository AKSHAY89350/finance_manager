import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import '../models/pending_transaction.dart';
import '../services/merchant_categorizer.dart';
import '../db/database_helper.dart';

/// On-Device Regular Expression parsing service for SMS and Push Notifications.
/// Runs 100% offline with zero network connectivity.
class SmsParserService {
  SmsParserService._();

  // ── Pre-Parsing Shield: Anti-Noise / OTP Blacklist ───────────
  static final RegExp _otpAndPromoRegex = RegExp(
    r'\b(otp|verification code|one time password|security code|login code|pre-approved|loan offer|apply now|win cash|cashback voucher|congratulations|reward points|flat \d+% off|deal of the day)\b',
    caseSensitive: false,
  );

  // ── Debit Alert Patterns (Expenses) ─────────────────────────
  // Matches: "Rs. 450 debited from A/c XX4589 to ZOMATO on 12-Oct-26"
  // or "Paid INR 1,299 via UPI to BLINKIT ref 429817291827"
  static final RegExp _debitRegex = RegExp(
    r'(?:Rs\.?|INR)\s*([0-9,]+(?:\.[0-9]{2})?)\s*(?:debited|spent|paid|withdrawn|transferred)\s*(?:from|using|via)?\s*(?:A/c|card|acct)?\s*([xX\d]+)?\s*(?:to|at|for|vpa)?\s*([^.]+?)(?:\.|\s+on|\s+avl|\s+ref|\s+UPI\s*ref|\s*$)',
    caseSensitive: false,
  );

  // Fallback debit pattern for UPI app notifications: "Paid ₹450 to Zomato"
  static final RegExp _upiDebitRegex = RegExp(
    r'(?:Paid|Sent)\s*(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]{2})?)\s*(?:to|for)\s*([^.]+?)(?:\s+via|\s+using|\.|\s*$)',
    caseSensitive: false,
  );

  // ── Credit Alert Patterns (Income / Salary) ─────────────────
  // Matches: "Rs 85,000 credited to A/c XX4589 on 01-Oct-26 by NEOSOFT SALARY"
  static final RegExp _creditRegex = RegExp(
    r'(?:Rs\.?|INR)\s*([0-9,]+(?:\.[0-9]{2})?)\s*(?:credited|deposited|received)\s*(?:to|in)?\s*(?:A/c|account)?\s*([xX\d]+)?(?:\s*by|\s*from)?\s*([^.]+)?(?:\.|\s+on|\s+avl|\s*$)',
    caseSensitive: false,
  );

  // ── Reference / UTR Number Extractor ────────────────────────
  static final RegExp _refIdRegex = RegExp(
    r'(?:ref|rrn|utr|txn|upi\s*ref)(?:\s*no\.?|\s*id)?[:\s]+([a-zA-Z0-9]+)',
    caseSensitive: false,
  );

  // ── Check if message is OTP / Promotional ───────────────────
  static bool isOtpOrPromotional(String text) {
    return _otpAndPromoRegex.hasMatch(text);
  }

  /// Parses a raw incoming message text.
  /// Returns a staged [PendingTransaction] ready for the Review Inbox,
  /// or null if the message is non-financial or spam.
  static Future<PendingTransaction?> parseMessage(
    String rawMessage, {
    DateTime? timestamp,
    String? sender,
  }) async {
    final cleanText = rawMessage.trim();
    if (cleanText.isEmpty || isOtpOrPromotional(cleanText)) {
      return null;
    }

    final dateNow = timestamp ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(dateNow);

    // Extract reference ID if available
    String? refId;
    final refMatch = _refIdRegex.firstMatch(cleanText);
    if (refMatch != null && refMatch.groupCount >= 1) {
      refId = refMatch.group(1)?.trim();
    }

    // ── 1. Check Debit (Expense) ──────────────────────────────
    final debitMatch = _debitRegex.firstMatch(cleanText);
    if (debitMatch != null) {
      final rawAmount = debitMatch.group(1)?.replaceAll(',', '');
      final amount = double.tryParse(rawAmount ?? '') ?? 0.0;
      if (amount <= 0) return null;

      final accountDigits = debitMatch.group(2)?.replaceAll(RegExp(r'[^0-9]'), '');
      var merchant = debitMatch.group(3)?.trim() ?? 'Unknown Merchant';
      merchant = _cleanMerchantName(merchant);

      // Determine Bank
      final bank = await _resolveBank(sender: sender, accountDigits: accountDigits);

      // Auto-categorize
      final (category, subCategory) = await MerchantCategorizer.categorize(merchant);

      // Deduplication fingerprint
      final fingerprint = _generateFingerprint(
        amount: amount,
        bank: bank,
        date: dateNow,
        merchant: merchant,
        refId: refId,
      );

      return PendingTransaction(
        fingerprint: fingerprint,
        date: dateStr,
        type: 'EXPENSE',
        amount: amount,
        bank: bank,
        accountDigits: accountDigits,
        merchant: merchant,
        suggestedCategory: category,
        suggestedSubCategory: subCategory,
        rawMessage: cleanText,
        refId: refId,
        createdAt: DateTime.now().toIso8601String(),
      );
    }

    // Check secondary UPI debit notification format
    final upiMatch = _upiDebitRegex.firstMatch(cleanText);
    if (upiMatch != null) {
      final rawAmount = upiMatch.group(1)?.replaceAll(',', '');
      final amount = double.tryParse(rawAmount ?? '') ?? 0.0;
      if (amount <= 0) return null;

      var merchant = upiMatch.group(2)?.trim() ?? 'Unknown Merchant';
      merchant = _cleanMerchantName(merchant);

      final bank = await _resolveBank(sender: sender, accountDigits: null);
      final (category, subCategory) = await MerchantCategorizer.categorize(merchant);

      final fingerprint = _generateFingerprint(
        amount: amount,
        bank: bank,
        date: dateNow,
        merchant: merchant,
        refId: refId,
      );

      return PendingTransaction(
        fingerprint: fingerprint,
        date: dateStr,
        type: 'EXPENSE',
        amount: amount,
        bank: bank,
        accountDigits: null,
        merchant: merchant,
        suggestedCategory: category,
        suggestedSubCategory: subCategory,
        rawMessage: cleanText,
        refId: refId,
        createdAt: DateTime.now().toIso8601String(),
      );
    }

    // ── 2. Check Credit (Income / Salary) ─────────────────────
    final creditMatch = _creditRegex.firstMatch(cleanText);
    if (creditMatch != null) {
      final rawAmount = creditMatch.group(1)?.replaceAll(',', '');
      final amount = double.tryParse(rawAmount ?? '') ?? 0.0;
      if (amount <= 0) return null;

      final accountDigits = creditMatch.group(2)?.replaceAll(RegExp(r'[^0-9]'), '');
      var source = creditMatch.group(3)?.trim() ?? 'Direct Deposit';
      source = _cleanMerchantName(source);

      final bank = await _resolveBank(sender: sender, accountDigits: accountDigits);

      final fingerprint = _generateFingerprint(
        amount: amount,
        bank: bank,
        date: dateNow,
        merchant: source,
        refId: refId,
      );

      return PendingTransaction(
        fingerprint: fingerprint,
        date: dateStr,
        type: 'INCOME',
        amount: amount,
        bank: bank,
        accountDigits: accountDigits,
        merchant: source,
        suggestedCategory: 'Income',
        suggestedSubCategory: 'Salary',
        rawMessage: cleanText,
        refId: refId,
        createdAt: DateTime.now().toIso8601String(),
      );
    }

    return null;
  }

  /// Resolve bank by account last 4 digits or sender mask
  static Future<String> _resolveBank({
    String? sender,
    String? accountDigits,
  }) async {
    // 1. Check account last 4 digits in DB
    if (accountDigits != null && accountDigits.length >= 3) {
      try {
        final last4 = accountDigits.length > 4
            ? accountDigits.substring(accountDigits.length - 4)
            : accountDigits;
        final matchedBank = await DatabaseHelper.instance.getBankByLast4(last4);
        if (matchedBank != null && matchedBank['name'] != null) {
          return matchedBank['name'] as String;
        }
      } catch (_) {}
    }

    // 2. Check sender header mask
    if (sender != null) {
      final s = sender.toUpperCase();
      if (s.contains('HDFC')) return 'HDFC';
      if (s.contains('SBI')) return 'SBI';
      if (s.contains('HSBC')) return 'HSBC';
      if (s.contains('PNB')) return 'PNB';
      if (s.contains('ICICI')) return 'HDFC'; // fallback default
    }

    // 3. Fallback to default bank
    return 'HSBC';
  }

  /// Clean extracted merchant string
  static String _cleanMerchantName(String raw) {
    var m = raw.replaceAll(RegExp(r'^(VPA|TO|AT|FOR|VIA|UPI|INF)\s+', caseSensitive: false), '');
    m = m.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    m = m.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    if (m.length > 40) {
      m = m.substring(0, 40).trim();
    }
    return m.isEmpty ? 'Merchant' : m;
  }

  /// Generates a SHA-256 fingerprint for deduplication
  static String _generateFingerprint({
    required double amount,
    required String bank,
    required DateTime date,
    required String merchant,
    String? refId,
  }) {
    if (refId != null && refId.trim().isNotEmpty) {
      return sha256.convert(utf8.encode('REF_${refId.trim().toUpperCase()}')).toString();
    }

    final timeWindow = '${date.year}-${date.month}-${date.day}_${date.hour}_${(date.minute ~/ 5)}';
    final normalizedMerchant = merchant.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final rawKey = '${amount.toStringAsFixed(2)}_${bank.toUpperCase()}_${normalizedMerchant}_$timeWindow';
    return sha256.convert(utf8.encode(rawKey)).toString();
  }
}
