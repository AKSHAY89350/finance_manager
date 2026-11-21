import 'package:uuid/uuid.dart';

/// Represents a parsed transaction from a bank statement (PDF).
/// Holds both the extracted raw financial data, duplicate detection status,
/// and user-reviewed categorization decisions.
class StatementTransaction {
  final String id;
  final DateTime date;
  final String narration;
  final String cleanDescription;
  final double amount;
  final bool isCredit;
  final double? balance;
  final String? referenceNo;
  final String bankName;

  // Deduplication & Review state
  bool isDuplicate;
  String? duplicateReason;
  bool isApproved;

  // Categorization decisions
  String selectedCategory;
  String? selectedSubCategory;
  String selectedBucket; // 'Needs' | 'Wants' | 'Savings' | 'Income'
  String targetAccount;

  StatementTransaction({
    String? id,
    required this.date,
    required this.narration,
    required this.cleanDescription,
    required this.amount,
    required this.isCredit,
    this.balance,
    this.referenceNo,
    required this.bankName,
    this.isDuplicate = false,
    this.duplicateReason,
    bool? isApproved,
    this.selectedCategory = 'Other',
    this.selectedSubCategory,
    String? selectedBucket,
    String? targetAccount,
  })  : id = id ?? const Uuid().v4(),
        isApproved = isApproved ?? (!isDuplicate),
        selectedBucket = selectedBucket ?? (isCredit ? 'Income' : 'Needs'),
        targetAccount = targetAccount ?? bankName;

  /// Human-readable date formatted as DD/MM/YYYY
  String get formattedDate {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  /// ISO date formatted as YYYY-MM-DD for database consistency
  String get isoDate {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$y-$m-$d';
  }

  StatementTransaction copyWith({
    String? id,
    DateTime? date,
    String? narration,
    String? cleanDescription,
    double? amount,
    bool? isCredit,
    double? balance,
    String? referenceNo,
    String? bankName,
    bool? isDuplicate,
    String? duplicateReason,
    bool? isApproved,
    String? selectedCategory,
    String? selectedSubCategory,
    String? selectedBucket,
    String? targetAccount,
  }) {
    return StatementTransaction(
      id: id ?? this.id,
      date: date ?? this.date,
      narration: narration ?? this.narration,
      cleanDescription: cleanDescription ?? this.cleanDescription,
      amount: amount ?? this.amount,
      isCredit: isCredit ?? this.isCredit,
      balance: balance ?? this.balance,
      referenceNo: referenceNo ?? this.referenceNo,
      bankName: bankName ?? this.bankName,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      duplicateReason: duplicateReason ?? this.duplicateReason,
      isApproved: isApproved ?? this.isApproved,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedSubCategory: selectedSubCategory ?? this.selectedSubCategory,
      selectedBucket: selectedBucket ?? this.selectedBucket,
      targetAccount: targetAccount ?? this.targetAccount,
    );
  }
}
