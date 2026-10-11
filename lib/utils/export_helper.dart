import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';
import 'formatters.dart';

class ExportHelper {
  ExportHelper._();

  /// Neutralizes Formula / DDE injection (CWE-1236)
  static String _sanitizeFormula(String value) {
    if (value.isNotEmpty &&
        (value.startsWith('=') ||
         value.startsWith('+') ||
         value.startsWith('-') ||
         value.startsWith('@') ||
         value.startsWith('\t') ||
         value.startsWith('\r'))) {
      return "'$value";
    }
    return value;
  }

  /// Sanitizes and escapes fields for RFC 4180 CSV output
  static String _sanitizeCsvField(String value) {
    var str = _sanitizeFormula(value);
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      str = '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  /// Exports all tables to an offline Excel (.xlsx) file and triggers share/save
  static Future<String> exportToExcel() async {
    final excel = Excel.createExcel();

    // 1. Sheet: Expenses
    final Sheet expenseSheet = excel['Expenses'];
    excel.setDefaultSheet('Expenses');
    expenseSheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Date'),
      TextCellValue('Category'),
      TextCellValue('Sub-Category'),
      TextCellValue('Description'),
      TextCellValue('Amount'),
      TextCellValue('Bank'),
    ]);

    final expenses = await DatabaseHelper.instance.getAllExpenses();
    for (final e in expenses) {
      expenseSheet.appendRow([
        IntCellValue(e['id'] as int),
        TextCellValue(e['date'] as String),
        TextCellValue(e['category'] as String),
        TextCellValue(_sanitizeFormula((e['sub_category'] as String?) ?? '')),
        TextCellValue(_sanitizeFormula((e['description'] as String?) ?? '')),
        DoubleCellValue((e['amount'] as num).toDouble()),
        TextCellValue(e['bank'] as String),
      ]);
    }

    // 2. Sheet: Income / Extra Credit
    final Sheet incomeSheet = excel['Extra Credit'];
    incomeSheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Date'),
      TextCellValue('Source'),
      TextCellValue('Amount'),
      TextCellValue('Mode'),
      TextCellValue('Bank'),
    ]);

    final incomes = await DatabaseHelper.instance.getAllIncome();
    for (final inc in incomes) {
      incomeSheet.appendRow([
        IntCellValue(inc['id'] as int),
        TextCellValue(inc['date'] as String),
        TextCellValue(_sanitizeFormula((inc['user_name'] as String?) ?? '')),
        DoubleCellValue((inc['amount'] as num).toDouble()),
        TextCellValue(inc['mode'] as String),
        TextCellValue(inc['bank'] as String),
      ]);
    }

    // 3. Sheet: Transfers
    final Sheet transferSheet = excel['Transfers'];
    transferSheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Date'),
      TextCellValue('From Bank'),
      TextCellValue('To Bank'),
      TextCellValue('Amount'),
      TextCellValue('Description'),
    ]);

    final transfers = await DatabaseHelper.instance.getAllTransfers();
    for (final t in transfers) {
      transferSheet.appendRow([
        IntCellValue(t['id'] as int),
        TextCellValue(t['date'] as String),
        TextCellValue(t['from_bank'] as String),
        TextCellValue(t['to_bank'] as String),
        DoubleCellValue((t['amount'] as num).toDouble()),
        TextCellValue(_sanitizeFormula((t['description'] as String?) ?? '')),
      ]);
    }

    // 4. Sheet: Live Bank Balances
    final Sheet bankSheet = excel['Bank Balances'];
    bankSheet.appendRow([
      TextCellValue('Bank Name'),
      TextCellValue('Starting Balance'),
      TextCellValue('Live Current Balance'),
    ]);

    final banks = await DatabaseHelper.instance.getAllBanks();
    for (final b in banks) {
      final name = b['name'] as String;
      final start = (b['starting_balance'] as num).toDouble();
      final live = await DatabaseHelper.instance.getLiveBalance(name);
      bankSheet.appendRow([
        TextCellValue(name),
        DoubleCellValue(start),
        DoubleCellValue(live),
      ]);
    }

    // Save File to temporary cache storage (CWE-312 prevention)
    final dir = await getTemporaryDirectory();
    final fileName = 'Finance_Manager_Backup_${AppFormatters.dbDate(DateTime.now())}.xlsx';
    final file = File('${dir.path}/$fileName');

    final bytes = excel.save();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Finance Manager Offline Backup');
      return file.path;
    } else {
      throw Exception('Failed to generate Excel file bytes');
    }
  }

  /// Exports expenses to a CSV file with formula neutralization & RFC 4180 escaping
  static Future<String> exportExpensesCSV() async {
    final expenses = await DatabaseHelper.instance.getAllExpenses();
    final buffer = StringBuffer();
    buffer.writeln('Date,Category,Sub-Category,Description,Amount,Bank');

    for (final e in expenses) {
      final date = _sanitizeCsvField(e['date'] as String);
      final category = _sanitizeCsvField(e['category'] as String);
      final subCategory = _sanitizeCsvField((e['sub_category'] as String?) ?? '');
      final desc = _sanitizeCsvField((e['description'] as String?) ?? '');
      final amount = e['amount'].toString();
      final bank = _sanitizeCsvField(e['bank'] as String);

      buffer.writeln('$date,$category,$subCategory,$desc,$amount,$bank');
    }

    // Save File to temporary cache storage (CWE-312 prevention)
    final dir = await getTemporaryDirectory();
    final fileName = 'Expenses_${AppFormatters.dbDate(DateTime.now())}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles([XFile(file.path)], text: 'Expenses CSV Export');
    return file.path;
  }
}
