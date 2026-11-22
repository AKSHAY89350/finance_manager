class ExtraCredit {
  final int? id;
  final String date;
  final String? userName;
  final double amount;
  final String mode;
  final String bank;
  final String? subCategory;
  final double? buyAmount;
  final double? profitAmount;
  final bool isInvestmentRedemption;

  ExtraCredit({
    this.id,
    required this.date,
    this.userName,
    required this.amount,
    required this.mode,
    required this.bank,
    this.subCategory,
    this.buyAmount,
    this.profitAmount,
    this.isInvestmentRedemption = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'user_name': userName,
      'amount': amount,
      'mode': mode,
      'bank': bank,
      if (subCategory != null) 'sub_category': subCategory,
      if (buyAmount != null) 'buy_amount': buyAmount,
      if (profitAmount != null) 'profit_amount': profitAmount,
      'is_investment_redemption': isInvestmentRedemption ? 1 : 0,
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
      subCategory: map['sub_category'] as String?,
      buyAmount: (map['buy_amount'] as num?)?.toDouble(),
      profitAmount: (map['profit_amount'] as num?)?.toDouble(),
      isInvestmentRedemption: (map['is_investment_redemption'] as int? ?? 0) == 1,
    );
  }

  ExtraCredit copyWith({
    int? id,
    String? date,
    String? userName,
    double? amount,
    String? mode,
    String? bank,
    String? subCategory,
    double? buyAmount,
    double? profitAmount,
    bool? isInvestmentRedemption,
  }) {
    return ExtraCredit(
      id: id ?? this.id,
      date: date ?? this.date,
      userName: userName ?? this.userName,
      amount: amount ?? this.amount,
      mode: mode ?? this.mode,
      bank: bank ?? this.bank,
      subCategory: subCategory ?? this.subCategory,
      buyAmount: buyAmount ?? this.buyAmount,
      profitAmount: profitAmount ?? this.profitAmount,
      isInvestmentRedemption: isInvestmentRedemption ?? this.isInvestmentRedemption,
    );
  }
}
