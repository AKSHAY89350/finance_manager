import '../utils/formatters.dart';

class RecurringRule {
  final int? id;
  final String title;
  final String type; // For DEBIT: 'SIP', 'Loan EMI', 'Rent', 'Bill', 'Other' | For CREDIT: 'Salary', 'Rental Income', 'Pension', etc.
  final String category;
  final String? subCategory;
  final double amount;
  final String bank;
  final int dayOfMonth; // 1 to 31
  final String startDate; // YYYY-MM-DD
  final String nextDueDate; // YYYY-MM-DD
  final String? lastProcessedDate; // YYYY-MM-DD
  final bool isActive;
  final String? notes;
  final String lastStatus; // 'PENDING', 'SUCCESS', 'INSUFFICIENT_BALANCE', 'FAILED'
  final String? lastStatusMessage;
  final String direction; // 'DEBIT' (Expense Outflow) or 'CREDIT' (Income Inflow)

  RecurringRule({
    this.id,
    required this.title,
    required this.type,
    required this.category,
    this.subCategory,
    required this.amount,
    required this.bank,
    required this.dayOfMonth,
    required this.startDate,
    required this.nextDueDate,
    this.lastProcessedDate,
    this.isActive = true,
    this.notes,
    this.lastStatus = 'PENDING',
    this.lastStatusMessage,
    this.direction = 'DEBIT',
  });

  bool get isDebit => direction == 'DEBIT';
  bool get isCredit => direction == 'CREDIT';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'type': type,
      'category': category,
      'sub_category': subCategory,
      'amount': amount,
      'bank': bank,
      'day_of_month': dayOfMonth,
      'start_date': startDate,
      'next_due_date': nextDueDate,
      'last_processed_date': lastProcessedDate,
      'is_active': isActive ? 1 : 0,
      'notes': notes,
      'last_status': lastStatus,
      'last_status_message': lastStatusMessage,
      'direction': direction,
    };
  }

  factory RecurringRule.fromMap(Map<String, dynamic> map) {
    return RecurringRule(
      id: map['id'] as int?,
      title: map['title'] as String,
      type: (map['type'] as String?) ?? 'Other',
      category: map['category'] as String,
      subCategory: map['sub_category'] as String?,
      amount: (map['amount'] as num).toDouble(),
      bank: map['bank'] as String,
      dayOfMonth: (map['day_of_month'] as int?) ?? 1,
      startDate: map['start_date'] as String,
      nextDueDate: map['next_due_date'] as String,
      lastProcessedDate: map['last_processed_date'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      notes: map['notes'] as String?,
      lastStatus: (map['last_status'] as String?) ?? 'PENDING',
      lastStatusMessage: map['last_status_message'] as String?,
      direction: (map['direction'] as String?) ?? 'DEBIT',
    );
  }

  RecurringRule copyWith({
    int? id,
    String? title,
    String? type,
    String? category,
    String? subCategory,
    double? amount,
    String? bank,
    int? dayOfMonth,
    String? startDate,
    String? nextDueDate,
    String? lastProcessedDate,
    bool? isActive,
    String? notes,
    String? lastStatus,
    String? lastStatusMessage,
    String? direction,
  }) {
    return RecurringRule(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      amount: amount ?? this.amount,
      bank: bank ?? this.bank,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      startDate: startDate ?? this.startDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      lastProcessedDate: lastProcessedDate ?? this.lastProcessedDate,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      lastStatus: lastStatus ?? this.lastStatus,
      lastStatusMessage: lastStatusMessage ?? this.lastStatusMessage,
      direction: direction ?? this.direction,
    );
  }

  /// Calculates days until the next scheduled due date.
  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = AppFormatters.parseDbDate(nextDueDate);
    final dueDateOnly = DateTime(due.year, due.month, due.day);
    return dueDateOnly.difference(today).inDays;
  }

  /// True if the rule is due today or in the past (and should be evaluated).
  bool get isDue {
    return daysUntilDue <= 0;
  }

  /// Human-friendly display string for recurrence schedule.
  String get scheduleDescription {
    String suffix = 'th';
    if (dayOfMonth == 1 || dayOfMonth == 21 || dayOfMonth == 31) {
      suffix = 'st';
    } else if (dayOfMonth == 2 || dayOfMonth == 22) {
      suffix = 'nd';
    } else if (dayOfMonth == 3 || dayOfMonth == 23) {
      suffix = 'rd';
    }
    return '$dayOfMonth$suffix of every month';
  }
}
