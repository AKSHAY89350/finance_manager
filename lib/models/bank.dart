class Bank {
  final int? id;
  final String name;
  final double startingBalance;

  Bank({
    this.id,
    required this.name,
    this.startingBalance = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'starting_balance': startingBalance,
    };
  }

  factory Bank.fromMap(Map<String, dynamic> map) {
    return Bank(
      id: map['id'] as int?,
      name: map['name'] as String,
      startingBalance: (map['starting_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Bank copyWith({
    int? id,
    String? name,
    double? startingBalance,
  }) {
    return Bank(
      id: id ?? this.id,
      name: name ?? this.name,
      startingBalance: startingBalance ?? this.startingBalance,
    );
  }
}
