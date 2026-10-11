import 'package:intl/intl.dart';

/// Number and date formatting utilities for the Finance Manager app.
/// Uses Indian number system (lakhs) and ₹ currency symbol.
class AppFormatters {
  AppFormatters._();

  // ── Currency Formatters ────────────────────────────────────────

  /// Indian currency format: ₹1,00,000.00
  static final NumberFormat _indianCurrency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// Compact Indian currency: ₹1.0L, ₹50K
  static final NumberFormat _indianCurrencyCompact = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  /// No-decimal currency for large amounts: ₹1,00,000
  static final NumberFormat _indianCurrencyNoDecimal = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// Format amount as Indian currency: ₹1,50,000.00
  static String currency(double amount) {
    if (amount.isNaN || amount.isInfinite) return '₹0.00';
    return _indianCurrency.format(amount);
  }

  /// Format as compact: ₹1.5L, ₹50K
  static String currencyCompact(double amount) {
    if (amount.isNaN || amount.isInfinite) return '₹0';
    return _indianCurrencyCompact.format(amount);
  }

  /// Format without decimals: ₹1,50,000
  static String currencyRounded(double amount) {
    if (amount.isNaN || amount.isInfinite) return '₹0';
    return _indianCurrencyNoDecimal.format(amount);
  }

  /// Format with sign: +₹5,000 or -₹3,000
  static String currencyWithSign(double amount) {
    final sign = amount >= 0 ? '+' : '';
    return '$sign${currency(amount)}';
  }

  // ── Date Formatters ────────────────────────────────────────────

  /// Display format: 01 Sep 2026
  static String displayDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  /// Short display: 01 Sep
  static String shortDate(DateTime date) {
    return DateFormat('dd MMM').format(date);
  }

  /// Month + Year: September 2026
  static String monthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  /// Short month: Sep 2026
  static String shortMonthYear(DateTime date) {
    return DateFormat('MMM yyyy').format(date);
  }

  /// Just month name: September
  static String monthName(DateTime date) {
    return DateFormat('MMMM').format(date);
  }

  /// Short month name: Sep
  static String shortMonthName(DateTime date) {
    return DateFormat('MMM').format(date);
  }

  /// Database format: 2026-09-01 (for SQLite storage)
  static String dbDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Parse database date string to DateTime
  static DateTime parseDbDate(String dateStr) {
    try {
      final cleaned = dateStr.trim();
      if (cleaned.contains(' ')) {
        return DateFormat('yyyy-MM-dd').parse(cleaned.split(' ').first);
      }
      return DateFormat('yyyy-MM-dd').parse(cleaned);
    } catch (_) {
      try {
        return DateTime.parse(dateStr);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  /// Today in display format
  static String today() => displayDate(DateTime.now());

  /// Time: 10:30 AM
  static String time(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  /// Date + time: 01 Sep 2026, 10:30 AM
  static String dateTime(DateTime date) {
    return '${displayDate(date)}, ${time(date)}';
  }

  // ── Number Formatters ──────────────────────────────────────────

  /// Percentage: 45.6%
  static String percentage(double value, {int decimals = 1}) {
    return '${value.toStringAsFixed(decimals)}%';
  }

  /// Integer count with comma: 1,234
  static String count(int value) {
    return NumberFormat('#,##,##0', 'en_IN').format(value);
  }

  // ── Date Range Helpers for SQL ─────────────────────────────────

  /// Start of month string for SQLite WHERE clause
  static String monthStart(int year, int month) {
    return dbDate(DateTime(year, month, 1));
  }

  /// Start of next month string (exclusive upper bound for SQLite)
  static String monthEnd(int year, int month) {
    return dbDate(DateTime(year, month + 1, 1));
  }

  /// Start of year
  static String yearStart(int year) => dbDate(DateTime(year, 1, 1));

  /// Start of next year (exclusive upper bound)
  static String yearEnd(int year) => dbDate(DateTime(year + 1, 1, 1));
}
