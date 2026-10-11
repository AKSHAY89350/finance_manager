class Transfer {
  final int? id;
  final String date;
  final String fromBank;
  final String toBank;
  final double amount;
  final String? description;

  Transfer({
    this.id,
    required this.date,
    required this.fromBank,
    required this.toBank,
    required this.amount,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'from_bank': fromBank,
      'to_bank': toBank,
      'amount': amount,
      'description': description,
    };
  }

  factory Transfer.fromMap(Map<String, dynamic> map) {
    return Transfer(
      id: map['id'] as int?,
      date: map['date'] as String,
      fromBank: map['from_bank'] as String,
      toBank: map['to_bank'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
    );
  }

  Transfer copyWith({
    int? id,
    String? date,
    String? fromBank,
    String? toBank,
    double? amount,
    String? description,
  }) {
    return Transfer(
      id: id ?? this.id,
      date: date ?? this.date,
      fromBank: fromBank ?? this.fromBank,
      toBank: toBank ?? this.toBank,
      amount: amount ?? this.amount,
      description: description ?? this.description,
    );
  }
}
