/// Represents an auto-detected incoming SMS or push notification transaction
/// staged in the review inbox before committing to the official ledger.
class PendingTransaction {
  final int? id;
  final String fingerprint;
  final String date; // YYYY-MM-DD
  final String type; // 'EXPENSE' or 'INCOME'
  final double amount;
  final String bank;
  final String? accountDigits;
  final String merchant;
  final String suggestedCategory;
  final String? suggestedSubCategory;
  final String rawMessage;
  final String? refId;
  final String status; // 'PENDING', 'CONFIRMED', 'DISCARDED'
  final String createdAt;

  PendingTransaction({
    this.id,
    required this.fingerprint,
    required this.date,
    required this.type,
    required this.amount,
    required this.bank,
    this.accountDigits,
    required this.merchant,
    required this.suggestedCategory,
    this.suggestedSubCategory,
    required this.rawMessage,
    this.refId,
    this.status = 'PENDING',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'fingerprint': fingerprint,
      'date': date,
      'type': type,
      'amount': amount,
      'bank': bank,
      'account_digits': accountDigits,
      'merchant': merchant,
      'suggested_category': suggestedCategory,
      'suggested_sub_category': suggestedSubCategory,
      'raw_message': rawMessage,
      'ref_id': refId,
      'status': status,
      'created_at': createdAt,
    };
  }

  factory PendingTransaction.fromMap(Map<String, dynamic> map) {
    return PendingTransaction(
      id: map['id'] as int?,
      fingerprint: map['fingerprint'] as String,
      date: map['date'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      bank: map['bank'] as String,
      accountDigits: map['account_digits'] as String?,
      merchant: map['merchant'] as String,
      suggestedCategory: map['suggested_category'] as String,
      suggestedSubCategory: map['suggested_sub_category'] as String?,
      rawMessage: map['raw_message'] as String,
      refId: map['ref_id'] as String?,
      status: (map['status'] as String?) ?? 'PENDING',
      createdAt: map['created_at'] as String,
    );
  }

  PendingTransaction copyWith({
    int? id,
    String? fingerprint,
    String? date,
    String? type,
    double? amount,
    String? bank,
    String? accountDigits,
    String? merchant,
    String? suggestedCategory,
    String? suggestedSubCategory,
    String? rawMessage,
    String? refId,
    String? status,
    String? createdAt,
  }) {
    return PendingTransaction(
      id: id ?? this.id,
      fingerprint: fingerprint ?? this.fingerprint,
      date: date ?? this.date,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      bank: bank ?? this.bank,
      accountDigits: accountDigits ?? this.accountDigits,
      merchant: merchant ?? this.merchant,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      suggestedSubCategory: suggestedSubCategory ?? this.suggestedSubCategory,
      rawMessage: rawMessage ?? this.rawMessage,
      refId: refId ?? this.refId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
