/// Represents a learned or configured rule mapping a merchant keyword
/// to an app category and sub-category.
class MerchantRule {
  final String merchantKeyword;
  final String category;
  final String? subCategory;
  final int usageCount;
  final String lastUsed;

  MerchantRule({
    required this.merchantKeyword,
    required this.category,
    this.subCategory,
    this.usageCount = 1,
    required this.lastUsed,
  });

  Map<String, dynamic> toMap() {
    return {
      'merchant_keyword': merchantKeyword,
      'category': category,
      'sub_category': subCategory,
      'usage_count': usageCount,
      'last_used': lastUsed,
    };
  }

  factory MerchantRule.fromMap(Map<String, dynamic> map) {
    return MerchantRule(
      merchantKeyword: map['merchant_keyword'] as String,
      category: map['category'] as String,
      subCategory: map['sub_category'] as String?,
      usageCount: (map['usage_count'] as int?) ?? 1,
      lastUsed: map['last_used'] as String,
    );
  }

  MerchantRule copyWith({
    String? merchantKeyword,
    String? category,
    String? subCategory,
    int? usageCount,
    String? lastUsed,
  }) {
    return MerchantRule(
      merchantKeyword: merchantKeyword ?? this.merchantKeyword,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      usageCount: usageCount ?? this.usageCount,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }
}
