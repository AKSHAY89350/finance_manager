import 'package:flutter/material.dart';

/// Central color palette for the Finance Manager app.
/// All colors in one place — change here, reflects everywhere.
class AppColors {
  AppColors._(); // prevent instantiation

  // ── Primary Brand ──────────────────────────────────────────────
  static const Color primary      = Color(0xFF2563EB); // Royal Blue
  static const Color primaryLight = Color(0xFF3B82F6); // Lighter blue
  static const Color primaryDark  = Color(0xFF1D4ED8); // Darker blue
  static const Color secondary    = Color(0xFF0EA5E9); // Sky blue

  // ── Financial Semantic Colors ──────────────────────────────────
  static const Color income      = Color(0xFF16A34A); // Green  — income / positive
  static const Color expense     = Color(0xFFDC2626); // Red    — expense / negative
  static const Color investment  = Color(0xFF7C3AED); // Purple — investments
  static const Color transfer    = Color(0xFFF59E0B); // Amber  — transfers
  static const Color loan        = Color(0xFFEF4444); // Red    — loans
  static const Color savings     = Color(0xFF10B981); // Emerald — savings

  // ── Category Colors (matching Lookups sheet) ───────────────────
  static const Color catFood         = Color(0xFFF97316); // Orange
  static const Color catShopping     = Color(0xFFEC4899); // Pink
  static const Color catTravel       = Color(0xFF06B6D4); // Cyan
  static const Color catHomeSend     = Color(0xFF10B981); // Emerald
  static const Color catInvestment   = Color(0xFF7C3AED); // Purple
  static const Color catLoan         = Color(0xFFEF4444); // Red
  static const Color catCreditCard   = Color(0xFFF43F5E); // Rose
  static const Color catBills        = Color(0xFF3B82F6); // Blue
  static const Color catHealth       = Color(0xFF14B8A6); // Teal
  static const Color catEntertainment = Color(0xFFA855F7); // Violet
  static const Color catEcommerce    = Color(0xFFF59E0B); // Amber
  static const Color catOther        = Color(0xFF94A3B8); // Slate

  // ── Backgrounds ────────────────────────────────────────────────
  static const Color background  = Color(0xFFF8FAFC); // App background
  static const Color surface     = Color(0xFFFFFFFF); // Card background
  static const Color surfaceAlt  = Color(0xFFEFF6FF); // Light blue tint

  // ── Text ───────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF1E293B); // Dark slate
  static const Color textSecondary = Color(0xFF64748B); // Slate gray
  static const Color textHint      = Color(0xFF94A3B8); // Light slate

  // ── UI Elements ────────────────────────────────────────────────
  static const Color divider     = Color(0xFFE2E8F0); // Light border
  static const Color shadow      = Color(0x1A000000); // 10% black shadow

  // ── Bank Colors ────────────────────────────────────────────────
  static const Color bankHSBC = Color(0xFFDB0011); // HSBC Red
  static const Color bankHDFC = Color(0xFF004C8F); // HDFC Blue
  static const Color bankPNB  = Color(0xFF8B1A1A); // PNB Dark Red
  static const Color bankSBI  = Color(0xFF1E5DB3); // SBI Blue

  /// Returns a color for a given category name
  static Color forCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':               return catFood;
      case 'shopping':           return catShopping;
      case 'traveling':          return catTravel;
      case 'home send':          return catHomeSend;
      case 'sip & investments':  return catInvestment;
      case 'loan':               return catLoan;
      case 'credit card payment':return catCreditCard;
      case 'bills & utilities':  return catBills;
      case 'health & medical':   return catHealth;
      case 'entertainment':      return catEntertainment;
      case 'quick ecommerce':    return catEcommerce;
      default:                   return catOther;
    }
  }

  /// Returns a color for a given bank name
  static Color forBank(String bank) {
    switch (bank.toUpperCase()) {
      case 'HSBC': return bankHSBC;
      case 'HDFC': return bankHDFC;
      case 'PNB':  return bankPNB;
      case 'SBI':  return bankSBI;
      default:     return primary;
    }
  }
}
