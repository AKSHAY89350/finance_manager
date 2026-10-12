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
  // ── Debit Alert Patterns (Expenses) ─────────────────────────
  // Matches: "Rs. 450 debited from A/c XX4589 to ZOMATO on 12-Oct-26"
  // or "Paid INR 1,299 via UPI to BLINKIT ref 429817291827"
  // or "₹ 450.00 debited from card ending 4589 to ZOMATO"
  static final RegExp _debitRegex = RegExp(
    r'(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]{2})?)\s*(?:debited|spent|paid|withdrawn|transferred)\s*(?:from|using|via|on|with)?(?:\s*(?:A/c|card|acct)\s*(?:ending|no\.?)?\s*([xX\d*]+))?.*?(?:to|at|for|vpa|towards)\s+([^.\n]+?)(?:\.|\s+on|\s+avl|\s+ref|\s+UPI\s*ref|\s*$)',
    caseSensitive: false,
  );

  // Account-first debit pattern (SBI, PNB, BoB, Axis):
  // Matches: "A/c *1234 debited by Rs.999.00 on 12-10-26 towards SWIGGY. Avl Bal Rs.25000"
  // or "Card XX4589 debited for INR 450.00 to Zomato"
  static final RegExp _accountFirstDebitRegex = RegExp(
    r'(?:A/c|card|acct)\s*(?:ending\s*)?([xX\d*]+).*?(?:debited|spent|charged|withdrawn)\s*(?:by|for|with)?\s*(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]{2})?).*?(?:to|at|for|vpa|towards)\s+([^.\n]+?)(?:\.|\s+on|\s+avl|\s+ref|\s+UPI\s*ref|\s*$)',
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
    r'(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]{2})?)\s*(?:credited|deposited|received)\s*(?:to|in)?(?:\s*(?:A/c|account|card)\s*(?:ending|no\.?)?\s*([xX\d*]+))?.*?(?:by|from)\s+([^.\n]+?)(?:\.|\s+on|\s+avl|\s*$)',
    caseSensitive: false,
  );

  // Account-first credit pattern (SBI, PNB, BoB, Axis):
  // Matches: "A/c *1234 credited by Rs.85,000.00 on 01-Oct-26 by NEOSOFT SALARY"
  static final RegExp _accountFirstCreditRegex = RegExp(
    r'(?:A/c|card|acct)\s*(?:ending\s*)?([xX\d*]+).*?(?:credited|deposited|received)\s*(?:by|with)?\s*(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]{2})?).*?(?:by|from)\s+([^.\n]+?)(?:\.|\s+on|\s+avl|\s*$)',
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

    // ── 1. Check Standard Debit (Expense) ─────────────────────
    final debitMatch = _debitRegex.firstMatch(cleanText);
    if (debitMatch != null) {
      final rawAmount = debitMatch.group(1)?.replaceAll(',', '');
      final amount = double.tryParse(rawAmount ?? '') ?? 0.0;
      if (amount <= 0) return null;

      final accountDigits = debitMatch.group(2)?.replaceAll(RegExp(r'[^0-9]'), '');
      var merchant = debitMatch.group(3)?.trim() ?? 'Unknown Merchant';
      merchant = _cleanMerchantName(merchant);

      // Determine Bank
      final bank = await _resolveBank(
        sender: sender,
        accountDigits: accountDigits,
        bodyText: cleanText,
      );

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

    // ── 1b. Check Account-First Debit (SBI / PNB / BoB) ────────
    final accountFirstMatch = _accountFirstDebitRegex.firstMatch(cleanText);
    if (accountFirstMatch != null) {
      final accountDigits = accountFirstMatch.group(1)?.replaceAll(RegExp(r'[^0-9]'), '');
      final rawAmount = accountFirstMatch.group(2)?.replaceAll(',', '');
      final amount = double.tryParse(rawAmount ?? '') ?? 0.0;
      if (amount <= 0) return null;

      var merchant = accountFirstMatch.group(3)?.trim() ?? 'Unknown Merchant';
      merchant = _cleanMerchantName(merchant);

      final bank = await _resolveBank(
        sender: sender,
        accountDigits: accountDigits,
        bodyText: cleanText,
      );

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
        accountDigits: accountDigits,
        merchant: merchant,
        suggestedCategory: category,
        suggestedSubCategory: subCategory,
        rawMessage: cleanText,
        refId: refId,
        createdAt: DateTime.now().toIso8601String(),
      );
    }

    // ── 1c. Check UPI App Debit Notification ──────────────────
    final upiMatch = _upiDebitRegex.firstMatch(cleanText);
    if (upiMatch != null) {
      final rawAmount = upiMatch.group(1)?.replaceAll(',', '');
      final amount = double.tryParse(rawAmount ?? '') ?? 0.0;
      if (amount <= 0) return null;

      var merchant = upiMatch.group(2)?.trim() ?? 'Unknown Merchant';
      merchant = _cleanMerchantName(merchant);

      final bank = await _resolveBank(
        sender: sender,
        accountDigits: null,
        bodyText: cleanText,
      );
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

    // ── 2. Check Standard Credit (Income / Salary) ─────────────
    final creditMatch = _creditRegex.firstMatch(cleanText);
    if (creditMatch != null) {
      final rawAmount = creditMatch.group(1)?.replaceAll(',', '');
      final amount = double.tryParse(rawAmount ?? '') ?? 0.0;
      if (amount <= 0) return null;

      final accountDigits = creditMatch.group(2)?.replaceAll(RegExp(r'[^0-9]'), '');
      var source = creditMatch.group(3)?.trim() ?? 'Direct Deposit';
      source = _cleanMerchantName(source);

      final bank = await _resolveBank(
        sender: sender,
        accountDigits: accountDigits,
        bodyText: cleanText,
      );

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

    // ── 2b. Check Account-First Credit ────────────────────────
    final accountFirstCreditMatch = _accountFirstCreditRegex.firstMatch(cleanText);
    if (accountFirstCreditMatch != null) {
      final accountDigits = accountFirstCreditMatch.group(1)?.replaceAll(RegExp(r'[^0-9]'), '');
      final rawAmount = accountFirstCreditMatch.group(2)?.replaceAll(',', '');
      final amount = double.tryParse(rawAmount ?? '') ?? 0.0;
      if (amount <= 0) return null;

      var source = accountFirstCreditMatch.group(3)?.trim() ?? 'Direct Deposit';
      source = _cleanMerchantName(source);

      final bank = await _resolveBank(
        sender: sender,
        accountDigits: accountDigits,
        bodyText: cleanText,
      );

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

  /// Resolve bank by account last 4 digits, sender mask, or in-body bank name
  static Future<String> _resolveBank({
    String? sender,
    String? accountDigits,
    String? bodyText,
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
      if (s.contains('ICICI')) return 'ICICI';
      if (s.contains('AXIS')) return 'AXIS';
      if (s.contains('KOTAK')) return 'KOTAK';
      if (s.contains('BOB') || s.contains('BARODA')) return 'BANK OF BARODA';
    }

    // 3. Check in-body bank name detection
    if (bodyText != null) {
      final b = bodyText.toUpperCase();
      if (b.contains('HDFC')) return 'HDFC';
      if (b.contains('STATE BANK') || b.contains('SBI')) return 'SBI';
      if (b.contains('ICICI')) return 'ICICI';
      if (b.contains('AXIS')) return 'AXIS';
      if (b.contains('KOTAK')) return 'KOTAK';
      if (b.contains('PUNJAB NATIONAL') || b.contains('PNB')) return 'PNB';
      if (b.contains('HSBC')) return 'HSBC';
      if (b.contains('BANK OF BARODA') || b.contains('BOB')) return 'BANK OF BARODA';
    }

    // 4. Fallback to default bank
    return 'HSBC';
  }

  /// Clean extracted merchant string
  static String _cleanMerchantName(String raw) {
    var m = raw.trim();
    // Strip intermediate date phrases if leaked into merchant, e.g. "on 12-Oct-26 to ZOMATO" -> "ZOMATO"
    m = m.replaceAll(RegExp(r'^on\s+[\w/-]+\s+(?:to|towards|at|for|vpa|via)?\s*', caseSensitive: false), '');
    // Strip leading prepositions/prefixes
    m = m.replaceAll(RegExp(r'^(VPA|TO|TOWARDS|AT|FOR|VIA|UPI|INF|INFO)[:\s]+', caseSensitive: false), '');
    // Strip trailing reference or balance info that might leak
    m = m.replaceAll(RegExp(r'\s+(avl\s+bal|bal|ref|rrn|utr|upi|on\s+\d|txn).*$', caseSensitive: false), '');
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
