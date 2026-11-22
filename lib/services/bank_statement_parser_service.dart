import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/statement_transaction.dart';
import 'statement_categorizer_service.dart';

class StatementPasswordException implements Exception {
  final String message;
  const StatementPasswordException([this.message = 'Password required or incorrect password for PDF.']);

  @override
  String toString() => message;
}

/// On-Device Bank Statement PDF Parser Service.
/// Completely offline, privacy-first, zero server transmissions.
class BankStatementParserService {
  /// Extract transactions from raw PDF bytes with optional password decryption.
  static Future<List<StatementTransaction>> extractTransactions({
    required Uint8List pdfBytes,
    String? password,
    String bankName = 'Auto-Detect',
  }) async {
    PdfDocument? document;
    try {
      if (password != null && password.trim().isNotEmpty) {
        document = PdfDocument(inputBytes: pdfBytes, password: password.trim());
      } else {
        document = PdfDocument(inputBytes: pdfBytes);
      }
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('password') || err.contains('encrypted') || err.contains('security')) {
        throw const StatementPasswordException('This bank statement is password-protected. Please enter the password to decrypt.');
      }
      rethrow;
    }

    try {
      final extractor = PdfTextExtractor(document);
      final fullText = extractor.extractText();

      if (fullText.trim().isEmpty) {
        return [];
      }

      // Auto-detect bank if not explicitly chosen
      String detectedBank = bankName;
      if (detectedBank == 'Auto-Detect' || detectedBank.isEmpty) {
        detectedBank = _detectBankName(fullText);
      }

      return _parseTextToTransactions(fullText, detectedBank);
    } finally {
      document.dispose();
    }
  }

  /// Detects the financial institution from header text
  static String _detectBankName(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('hdfc')) return 'HDFC Bank';
    if (lower.contains('state bank') || lower.contains('sbi')) return 'SBI Bank';
    if (lower.contains('icici')) return 'ICICI Bank';
    if (lower.contains('axis')) return 'Axis Bank';
    if (lower.contains('kotak')) return 'Kotak Bank';
    if (lower.contains('punjab national') || lower.contains('pnb')) return 'PNB';
    if (lower.contains('hsbc')) return 'HSBC';
    if (lower.contains('visa') || lower.contains('mastercard')) return 'Credit Card';
    return 'Bank Statement';
  }

  /// Detects whether a line is a header, disclaimer, or pagination artifact
  static bool _isHeaderLine(String lower) {
    return lower.contains('transaction date') ||
        lower.contains('narration') ||
        lower.contains('withdrawal amt') ||
        lower.contains('deposit amt') ||
        lower.contains('account number') ||
        lower.contains('page ') ||
        lower.contains('statement summary') ||
        lower.contains('opening balance') ||
        lower.contains('closing balance');
  }

  /// Parses extracted raw text into structured statement transactions
  static List<StatementTransaction> _parseTextToTransactions(String text, String bankName) {
    final lines = text.split(RegExp(r'\r?\n'));
    final List<StatementTransaction> results = [];

    // Date regex patterns
    // 1. DD/MM/YYYY or DD-MM-YYYY or DD/MM/YY
    final dateNumRegex = RegExp(r'^\s*(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})');
    // 2. DD MMM YYYY or DD-MMM-YY (e.g. 15 Oct 2026 or 15-OCT-26)
    final dateAlphaRegex = RegExp(r'^\s*(\d{1,2}[\s\/\-][A-Za-z]{3}[\s\/\-]\d{2,4})');

    int i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        i++;
        continue;
      }

      // Security Guard: Discard abnormally oversized lines (>2000 chars) to prevent ReDoS / CPU spike
      if (line.length > 2000) {
        i++;
        continue;
      }

      final lower = line.toLowerCase();
      if (_isHeaderLine(lower)) {
        i++;
        continue;
      }

      // Check if line starts with a date
      String? dateStr;
      String remaining = line;

      final matchAlpha = dateAlphaRegex.firstMatch(line);
      final matchNum = dateNumRegex.firstMatch(line);

      if (matchAlpha != null) {
        dateStr = matchAlpha.group(1);
        remaining = line.substring(matchAlpha.end).trim();
      } else if (matchNum != null) {
        dateStr = matchNum.group(1);
        remaining = line.substring(matchNum.end).trim();
      }

      if (dateStr == null) {
        i++;
        continue;
      }

      final parsedDate = _parseStatementDate(dateStr);
      if (parsedDate == null) {
        i++;
        continue;
      }

      // Lookahead: buffer multi-line transaction rows where narration or amounts wrap
      String aggregatedLine = remaining;
      int nextIdx = i + 1;
      while (nextIdx < lines.length) {
        final nextTrimmed = lines[nextIdx].trim();
        if (nextTrimmed.isEmpty) {
          nextIdx++;
          continue;
        }
        if (_isHeaderLine(nextTrimmed.toLowerCase())) {
          nextIdx++;
          continue;
        }
        // If next line starts with a date, it marks the start of a subsequent transaction
        if (dateAlphaRegex.hasMatch(nextTrimmed) || dateNumRegex.hasMatch(nextTrimmed)) {
          break;
        }
        aggregatedLine += ' $nextTrimmed';
        i = nextIdx;
        nextIdx++;
      }

      // Parse amounts from the line
      final txn = _parseLineToTransaction(parsedDate, aggregatedLine, bankName);
      if (txn != null) {
        results.add(txn);
      }

      i++;
    }

    return results;
  }

  /// Parses amounts, narration, and type (Credit/Debit) from line
  static StatementTransaction? _parseLineToTransaction(DateTime date, String line, String bankName) {
    if (line.trim().isEmpty) return null;

    // Currency amount regex with comma separators and optional currency symbols
    // e.g. 1,250.00 or 5,000 or 500.50 or 75000.00
    final amtRegex = RegExp(r'(?:₹|Rs\.?\s*)?(\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})|\d{1,3}(?:,\d{2,3})+|\d+\.\d{2})');
    final matches = amtRegex.allMatches(line).toList();

    if (matches.isEmpty) return null;

    double? balance;
    bool isCredit = false;
    double finalAmt = 0;

    // Check for explicit Dr / Cr flags in line
    final isExplicitCr = RegExp(r'\b(?:CR|CREDIT|DEP|DEPOSIT)\b', caseSensitive: false).hasMatch(line);
    final isExplicitDr = RegExp(r'\b(?:DR|DEBIT|WDL|WITHDRAWAL)\b', caseSensitive: false).hasMatch(line);

    if (matches.length >= 2) {
      // Typically: [Amount, Balance] or [Debit, Credit, Balance]
      if (matches.length >= 3) {
        // [Debit, Credit, Balance]
        final val1 = _parseAmt(matches[matches.length - 3].group(0));
        final val2 = _parseAmt(matches[matches.length - 2].group(0));
        balance = _parseAmt(matches[matches.length - 1].group(0));

        if (val1 > 0 && val2 == 0) {
          isCredit = false;
          finalAmt = val1;
        } else if (val2 > 0 && val1 == 0) {
          isCredit = true;
          finalAmt = val2;
        } else {
          // Fallback based on flags
          if (isExplicitCr) {
            isCredit = true;
            finalAmt = val2 > 0 ? val2 : val1;
          } else {
            isCredit = false;
            finalAmt = val1 > 0 ? val1 : val2;
          }
        }
      } else {
        // [Amount, Balance]
        final val1 = _parseAmt(matches[0].group(0));
        balance = _parseAmt(matches[1].group(0));

        if (isExplicitCr) {
          isCredit = true;
          finalAmt = val1;
        } else if (isExplicitDr) {
          isCredit = false;
          finalAmt = val1;
        } else {
          // If narration suggests credit
          if (RegExp(r'\b(?:salary|neft\s+cr|refund|dividend|interest|int\.pd)\b', caseSensitive: false).hasMatch(line)) {
            isCredit = true;
            finalAmt = val1;
          } else {
            isCredit = false;
            finalAmt = val1;
          }
        }
      }
    } else {
      // Single amount found
      final val = _parseAmt(matches[0].group(0));
      if (val <= 0) return null;

      finalAmt = val;
      if (isExplicitCr || RegExp(r'\b(?:salary|neft\s+cr|refund|dividend|interest)\b', caseSensitive: false).hasMatch(line)) {
        isCredit = true;
      } else {
        isCredit = false;
      }
    }

    if (finalAmt <= 0) return null;

    // Narration is the text preceding the first matched amount
    final firstAmtIndex = matches.first.start;
    String narration = line.substring(0, firstAmtIndex).trim();

    // If narration is too short, look for text after amount or use whole line
    if (narration.length < 3) {
      narration = line.replaceAll(amtRegex, '').replaceAll(RegExp(r'\b(?:CR|DR)\b', caseSensitive: false), '').trim();
    }
    if (narration.isEmpty) {
      narration = 'Bank Transaction';
    }

    // Extract reference or cheque number if present
    final refMatch = RegExp(r'\b(?:REF|CHQ|UPI|TXN)[\/:#\s]*([A-Za-z0-9]+)\b', caseSensitive: false).firstMatch(line);
    final refNo = refMatch?.group(1);

    final cleanDesc = StatementCategorizerService.extractCleanDescription(narration);
    final suggestion = StatementCategorizerService.suggest(narration, isCredit);

    return StatementTransaction(
      date: date,
      narration: narration,
      cleanDescription: cleanDesc,
      amount: finalAmt,
      isCredit: isCredit,
      balance: balance,
      referenceNo: refNo,
      bankName: bankName,
      selectedCategory: suggestion.category,
      selectedSubCategory: suggestion.subCategory,
      selectedBucket: suggestion.bucket,
      targetAccount: bankName,
    );
  }

  static double _parseAmt(String? raw) {
    if (raw == null) return 0.0;
    final cleaned = raw.replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  static DateTime? _parseStatementDate(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return null;

    // Normalize casing for months (e.g. OCT -> Oct, oct -> Oct)
    String normalized = cleaned;
    final alphaMonthMatch = RegExp(r'[a-zA-Z]{3}').firstMatch(cleaned);
    if (alphaMonthMatch != null) {
      final m = alphaMonthMatch.group(0)!;
      final formattedM = m[0].toUpperCase() + m.substring(1).toLowerCase();
      normalized = normalized.replaceRange(alphaMonthMatch.start, alphaMonthMatch.end, formattedM);
    }

    final formats = [
      'dd/MM/yyyy',
      'dd-MM-yyyy',
      'dd.MM.yyyy',
      'dd/MM/yy',
      'dd-MM-yy',
      'dd MMM yyyy',
      'dd-MMM-yyyy',
      'dd-MMM-yy',
      'd MMM yyyy',
      'd-MMM-yy',
      'yyyy-MM-dd',
    ];

    for (final f in formats) {
      try {
        return DateFormat(f).parseStrict(normalized);
      } catch (_) {}
    }

    return null;
  }
}
