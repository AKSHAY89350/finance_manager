class Expense {
  final int? id;
  final String date;
  final String category;
  final String? subCategory;
  final String? description;
  final double amount;
  final String bank;

  Expense({
    this.id,
    required this.date,
    required this.category,
    this.subCategory,
    this.description,
    required this.amount,
    required this.bank,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'category': category,
      'sub_category': subCategory,
      'description': description,
      'amount': amount,
      'bank': bank,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      date: map['date'] as String,
      category: map['category'] as String,
      subCategory: map['sub_category'] as String?,
      description: map['description'] as String?,
      amount: (map['amount'] as num).toDouble(),
      bank: map['bank'] as String,
    );
  }

  Expense copyWith({
    int? id,
    String? date,
    String? category,
    String? subCategory,
    String? description,
    double? amount,
    String? bank,
  }) {
    return Expense(
      id: id ?? this.id,
      date: date ?? this.date,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      bank: bank ?? this.bank,
    );
  }
}
