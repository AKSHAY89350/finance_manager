class Bank {
  final int? id;
  final String name;
  final double startingBalance;
  final String? accountLast4;

  Bank({
    this.id,
    required this.name,
    this.startingBalance = 0.0,
    this.accountLast4,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'starting_balance': startingBalance,
      'account_last_4': accountLast4,
    };
  }

  factory Bank.fromMap(Map<String, dynamic> map) {
    return Bank(
      id: map['id'] as int?,
      name: map['name'] as String,
      startingBalance: (map['starting_balance'] as num?)?.toDouble() ?? 0.0,
      accountLast4: map['account_last_4'] as String?,
    );
  }

  Bank copyWith({
    int? id,
    String? name,
    double? startingBalance,
    String? accountLast4,
  }) {
    return Bank(
      id: id ?? this.id,
      name: name ?? this.name,
      startingBalance: startingBalance ?? this.startingBalance,
      accountLast4: accountLast4 ?? this.accountLast4,
    );
  }
}
