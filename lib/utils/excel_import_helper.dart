import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';

class ImportResult {
  final int expensesCount;
  final int incomeCount;
  final int transferCount;
  final String? error;

  ImportResult({
    this.expensesCount = 0,
    this.incomeCount = 0,
    this.transferCount = 0,
    this.error,
  });

  bool get isSuccess => error == null;
}

class ExcelImportHelper {
  ExcelImportHelper._();

  static Sheet? _findSheet(Excel excel, String name) {
    final clean = name.trim().toLowerCase();
    for (final entry in excel.tables.entries) {
      if (entry.key.trim().toLowerCase() == clean) {
        return entry.value;
      }
    }
    return null;
  }

  /// Parses bytes from an uploaded Excel (.xlsx) file matching the user's Excel schema
  static Future<ImportResult> importExcelFile(Uint8List bytes) async {
    try {
      final excel = Excel.decodeBytes(bytes);

      // Track known banks to automatically create new banks found in sheet
      final existingBanks = await DatabaseHelper.instance.getAllBanks();
      final bankNames = existingBanks.map((b) => b['name'] as String).toSet();
      final Set<String> newBanksToInsert = {};

      void registerBank(String bank) {
        final trimmed = bank.trim();
        if (trimmed.isNotEmpty && !bankNames.contains(trimmed)) {
          newBanksToInsert.add(trimmed);
          bankNames.add(trimmed);
        }
      }

      final List<Map<String, dynamic>> expensesToInsert = [];
      final List<Map<String, dynamic>> incomesToInsert = [];
      final List<Map<String, dynamic>> transfersToInsert = [];

      // ── 1. IMPORT EXPENSES ─────────────────────────────────────────
      final expenseSheet = _findSheet(excel, 'Expenses');
      if (expenseSheet != null && expenseSheet.rows.length > 1) {
        // Headers: Date, Category, Sub-Category, Description, Amount, Bank
        for (int i = 1; i < expenseSheet.rows.length; i++) {
          final row = expenseSheet.rows[i];
          if (row.isEmpty || row[0] == null) continue;

          final dateVal = _cellString(row[0]);
          if (dateVal.isEmpty) continue;

          final category = row.length > 1 ? _cellString(row[1]) : 'Other';
          final subCategory = row.length > 2 ? _cellString(row[2]) : null;
          final description = row.length > 3 ? _cellString(row[3]) : null;
          final amount = row.length > 4 ? _cellDouble(row[4]) : 0.0;
          final bank = row.length > 5 ? _cellString(row[5]) : 'HSBC';

          if (amount > 0) {
            final formattedDate = _standardizeDate(dateVal);
            registerBank(bank);

            expensesToInsert.add({
              'date': formattedDate,
              'category': category.isEmpty ? 'Other' : category,
              'sub_category': subCategory?.isEmpty == true ? null : subCategory,
              'description': description?.isEmpty == true ? null : description,
              'amount': amount,
              'bank': bank.isEmpty ? 'HSBC' : bank,
            });
          }
        }
      }

      // ── 2. IMPORT EXTRA CREDIT (INCOME) ─────────────────────────────
      final incomeSheet = _findSheet(excel, 'Extra Credit');
      if (incomeSheet != null && incomeSheet.rows.length > 1) {
        // Headers: Date, User Name, Amount, Mode, Bank
        for (int i = 1; i < incomeSheet.rows.length; i++) {
          final row = incomeSheet.rows[i];
          if (row.isEmpty || row[0] == null) continue;

          final dateVal = _cellString(row[0]);
          if (dateVal.isEmpty) continue;

          final userName = row.length > 1 ? _cellString(row[1]) : null;
          final amount = row.length > 2 ? _cellDouble(row[2]) : 0.0;
          final mode = row.length > 3 ? _cellString(row[3]) : 'Other';
          final bank = row.length > 4 ? _cellString(row[4]) : 'HSBC';

          if (amount > 0) {
            final formattedDate = _standardizeDate(dateVal);
            registerBank(bank);

            incomesToInsert.add({
              'date': formattedDate,
              'user_name': userName?.isEmpty == true ? null : userName,
              'amount': amount,
              'mode': mode.isEmpty ? 'Other' : mode,
              'bank': bank.isEmpty ? 'HSBC' : bank,
            });
          }
        }
      }

      // ── 3. IMPORT TRANSFERS ─────────────────────────────────────────
      final transferSheet = _findSheet(excel, 'Transfers');
      if (transferSheet != null && transferSheet.rows.length > 1) {
        // Headers: Date, From Bank, To Bank, Amount, Description
        for (int i = 1; i < transferSheet.rows.length; i++) {
          final row = transferSheet.rows[i];
          if (row.isEmpty || row[0] == null) continue;

          final dateVal = _cellString(row[0]);
          if (dateVal.isEmpty) continue;

          final fromBank = row.length > 1 ? _cellString(row[1]) : '';
          final toBank = row.length > 2 ? _cellString(row[2]) : '';
          final amount = row.length > 3 ? _cellDouble(row[3]) : 0.0;
          final desc = row.length > 4 ? _cellString(row[4]) : null;

          if (amount > 0 && fromBank.isNotEmpty && toBank.isNotEmpty && fromBank != toBank) {
            final formattedDate = _standardizeDate(dateVal);
            registerBank(fromBank);
            registerBank(toBank);

            transfersToInsert.add({
              'date': formattedDate,
              'from_bank': fromBank,
              'to_bank': toBank,
              'amount': amount,
              'description': desc?.isEmpty == true ? null : desc,
            });
          }
        }
      }

      // Execute high performance atomic batch transaction
      await DatabaseHelper.instance.batchInsertRecords(
        expenses: expensesToInsert,
        incomes: incomesToInsert,
        transfers: transfersToInsert,
        newBanks: newBanksToInsert.toList(),
      );

      return ImportResult(
        expensesCount: expensesToInsert.length,
        incomeCount: incomesToInsert.length,
        transferCount: transfersToInsert.length,
      );
    } catch (e) {
      return ImportResult(error: e.toString());
    }
  }

  static String _cellString(Data? cell) {
    if (cell == null || cell.value == null) return '';
    return cell.value.toString().trim();
  }

  static double _cellDouble(Data? cell) {
    if (cell == null || cell.value == null) return 0.0;
    final val = cell.value;
    if (val is IntCellValue) return val.value.toDouble();
    if (val is DoubleCellValue) return val.value;
    final str = val.toString().replaceAll(',', '').trim();
    return double.tryParse(str) ?? 0.0;
  }

  static String _standardizeDate(String raw) {
    String cleaned = raw.trim();

    // 1. If date is Excel serial number (e.g. 45678)
    final serial = double.tryParse(cleaned);
    if (serial != null && serial > 20000 && serial < 80000) {
      final baseDate = DateTime(1899, 12, 30);
      final date = baseDate.add(Duration(days: serial.toInt()));
      return DateFormat('yyyy-MM-dd').format(date);
    }

    // 2. If date has time attached (e.g. '2026-09-01 00:00:00')
    if (cleaned.contains(' ')) {
      cleaned = cleaned.split(' ').first;
    }

    // 3. Try standard formats
    final formats = [
      'yyyy-MM-dd',
      'dd-MM-yyyy',
      'dd/MM/yyyy',
      'yyyy/MM/dd',
      'd-M-yyyy',
      'd/M/yyyy',
    ];

    for (final fmt in formats) {
      try {
        final parsed = DateFormat(fmt).parseStrict(cleaned);
        return DateFormat('yyyy-MM-dd').format(parsed);
      } catch (_) {}
    }

    return cleaned;
  }
}
