class InitialInvestment {
  final int? id;
  final String assetName;
  final double startingBalance;
  final String category;
  final String? notes;

  const InitialInvestment({
    this.id,
    required this.assetName,
    required this.startingBalance,
    this.category = 'SIP & Investments',
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'asset_name': assetName,
      'starting_balance': startingBalance,
      'category': category,
      if (notes != null) 'notes': notes,
    };
  }

  factory InitialInvestment.fromMap(Map<String, dynamic> map) {
    return InitialInvestment(
      id: map['id'] as int?,
      assetName: map['asset_name'] as String,
      startingBalance: (map['starting_balance'] as num?)?.toDouble() ?? 0.0,
      category: (map['category'] as String?) ?? 'SIP & Investments',
      notes: map['notes'] as String?,
    );
  }

  InitialInvestment copyWith({
    int? id,
    String? assetName,
    double? startingBalance,
    String? category,
    String? notes,
  }) {
    return InitialInvestment(
      id: id ?? this.id,
      assetName: assetName ?? this.assetName,
      startingBalance: startingBalance ?? this.startingBalance,
      category: category ?? this.category,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InitialInvestment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          assetName == other.assetName &&
          startingBalance == other.startingBalance;

  @override
  int get hashCode => id.hashCode ^ assetName.hashCode ^ startingBalance.hashCode;
}
