class ExtraCredit {
  final int? id;
  final String date;
  final String? userName;
  final double amount;
  final String mode;
  final String bank;

  ExtraCredit({
    this.id,
    required this.date,
    this.userName,
    required this.amount,
    required this.mode,
    required this.bank,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'user_name': userName,
      'amount': amount,
      'mode': mode,
      'bank': bank,
    };
  }

  factory ExtraCredit.fromMap(Map<String, dynamic> map) {
    return ExtraCredit(
      id: map['id'] as int?,
      date: map['date'] as String,
      userName: map['user_name'] as String?,
      amount: (map['amount'] as num).toDouble(),
      mode: map['mode'] as String,
      bank: map['bank'] as String,
    );
  }

  ExtraCredit copyWith({
    int? id,
    String? date,
    String? userName,
    double? amount,
    String? mode,
    String? bank,
  }) {
    return ExtraCredit(
      id: id ?? this.id,
      date: date ?? this.date,
      userName: userName ?? this.userName,
      amount: amount ?? this.amount,
      mode: mode ?? this.mode,
      bank: bank ?? this.bank,
    );
  }
}
