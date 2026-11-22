/// Smart rule-based merchant categorizer and description cleaner
/// for Bank Statement transactions.
class StatementCategorizerService {
  StatementCategorizerService._();

  /// Clean raw banking narration into a concise merchant or transfer label
  static String extractCleanDescription(String narration) {
    if (narration.trim().isEmpty) return 'Bank Transaction';

    String s = narration.trim();

    // 1. UPI format: UPI/123456789/Payee/Bank/Ref or UPI-Payee-Ref
    final upiMatch = RegExp(r'^UPI[\/-](.*)$', caseSensitive: false).firstMatch(s);
    if (upiMatch != null) {
      final segments = upiMatch.group(1)!.split(RegExp(r'[\/-]')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      for (final seg in segments) {
        // Skip pure numeric reference IDs
        if (RegExp(r'^\d+$').hasMatch(seg)) continue;
        // Skip common bank IFSC, handle codes, or transfer types
        if (RegExp(r'^(?:HDFC|ICICI|SBI|SBIN|AXIS|UTIB|KKBK|YESB|PAYTM|OKAXIS|OKHDFC|OKICICI|OKSBI|IBL|CNRB|BARB|P2A|P2P|CR|DR)$', caseSensitive: false).hasMatch(seg)) continue;
        return _cleanMerchantName(seg);
      }
    }

    // 2. POS or Card Swipes: POS 123456 MERCHANT NAME CITY
    final posRegex = RegExp(r'(?:POS|ECOM|IPS|SWIPE)(?:\s+\d+)?\s+([A-Za-z0-9\s&.-]+)', caseSensitive: false);
    final posMatch = posRegex.firstMatch(s);
    if (posMatch != null && (posMatch.group(1)?.trim().isNotEmpty ?? false)) {
      return _cleanMerchantName(posMatch.group(1)!);
    }

    // 3. NEFT / IMPS / RTGS transfers: NEFT CR-BANK-SENDER or IMPS/P2A/SENDER
    final transferRegex = RegExp(r'(?:NEFT|IMPS|RTGS|ACH|NACH)(?:[\s\/-]+(?:CR|DR))?[\s\/-]+([A-Za-z0-9\s&.-]+)', caseSensitive: false);
    final transferMatch = transferRegex.firstMatch(s);
    if (transferMatch != null && (transferMatch.group(1)?.trim().isNotEmpty ?? false)) {
      return _cleanMerchantName(transferMatch.group(1)!);
    }

    // 4. ATM Cash withdrawal
    if (RegExp(r'(?:ATM|CASH\s+WDL|NFS|EAW)', caseSensitive: false).hasMatch(s)) {
      return 'ATM Cash Withdrawal';
    }

    // Fallback: take first 3-4 meaningful words
    return _cleanMerchantName(s);
  }

  static String _cleanMerchantName(String raw) {
    String name = raw
        .replaceAll(RegExp(r'[@\/\\#+()$~%":*?<>{}]'), ' ')
        .replaceAll(RegExp(r'\b(?:Pvt|Ltd|Limited|Private|LLP|Inc|Corp|India|Branch|Bangalore|Mumbai|Delhi|Hyd)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // If too long, truncate to 40 chars
    if (name.length > 40) {
      name = name.substring(0, 40).trim();
    }
    return name.isEmpty ? 'Bank Transaction' : name;
  }

  /// Suggests Category, Sub-Category, and 50-30-20 Bucket
  static CategorizationSuggestion suggest(String narration, bool isCredit) {
    final lower = narration.toLowerCase();

    // 0. Self / Internal Account Transfers (applies to both credits and debits)
    if (lower.contains('self transfer') ||
        lower.contains('trf to self') ||
        lower.contains('trf from self') ||
        lower.contains('own a/c') ||
        lower.contains('own account') ||
        lower.contains('internal transfer') ||
        lower.contains('self a/c') ||
        lower.contains('transfer to own') ||
        lower.contains('funds transfer to own')) {
      return const CategorizationSuggestion(
        category: 'Internal Transfer',
        subCategory: 'Self Transfer',
        bucket: 'Transfer',
        isTransfer: true,
      );
    }

    if (isCredit) {
      if (lower.contains('salary') ||
          lower.contains('payroll') ||
          lower.contains('infosys') ||
          lower.contains('tcs') ||
          lower.contains('wipro') ||
          lower.contains('hcl') ||
          lower.contains('accenture') ||
          lower.contains('employer')) {
        return const CategorizationSuggestion(
          category: 'Other',
          subCategory: 'Salary',
          bucket: 'Income',
        );
      }
      if (lower.contains('dividend') || lower.contains('interest') || lower.contains('int.pd')) {
        return const CategorizationSuggestion(
          category: 'Other',
          subCategory: 'Interest / Dividend',
          bucket: 'Income',
        );
      }
      if (lower.contains('refund') || lower.contains('cashback') || lower.contains('reversal')) {
        return const CategorizationSuggestion(
          category: 'Other',
          subCategory: 'Refund / Cashback',
          bucket: 'Income',
        );
      }
      return const CategorizationSuggestion(
        category: 'Other',
        subCategory: 'Income Credit',
        bucket: 'Income',
      );
    }

    // Quick Ecommerce
    if (lower.contains('blinkit') ||
        lower.contains('zepto') ||
        lower.contains('instamart') ||
        lower.contains('bb now') ||
        lower.contains('bigbasket')) {
      String sub = 'Other';
      if (lower.contains('blinkit')) sub = 'Blinkit';
      if (lower.contains('zepto')) sub = 'Zepto';
      if (lower.contains('instamart')) sub = 'Instamart';
      if (lower.contains('bb now') || lower.contains('bigbasket')) sub = 'BB Now';
      return CategorizationSuggestion(
        category: 'Quick Ecommerce',
        subCategory: sub,
        bucket: 'Needs',
      );
    }

    // Food & Dining
    if (lower.contains('swiggy') ||
        lower.contains('zomato') ||
        lower.contains('mcdonald') ||
        lower.contains('kfc') ||
        lower.contains('starbucks') ||
        lower.contains('domino') ||
        lower.contains('burger king') ||
        lower.contains('pizza') ||
        lower.contains('chai') ||
        lower.contains('cafe') ||
        lower.contains('restaurant') ||
        lower.contains('dhaba') ||
        lower.contains('bakery')) {
      final isDelivery = lower.contains('swiggy') || lower.contains('zomato');
      return CategorizationSuggestion(
        category: 'Food',
        subCategory: isDelivery ? 'Zomato / Swiggy' : 'Dining Out',
        bucket: 'Wants',
      );
    }

    // Shopping
    if (lower.contains('amazon') ||
        lower.contains('flipkart') ||
        lower.contains('myntra') ||
        lower.contains('ajio') ||
        lower.contains('zara') ||
        lower.contains('h&m') ||
        lower.contains('meesho') ||
        lower.contains('nykaa') ||
        lower.contains('croma') ||
        lower.contains('reliance digital')) {
      final isElec = lower.contains('croma') || lower.contains('digital') || lower.contains('apple');
      return CategorizationSuggestion(
        category: 'Shopping',
        subCategory: isElec ? 'Electronics & Gadgets' : 'Clothing & Footwear',
        bucket: 'Wants',
      );
    }

    // Traveling & Fuel
    if (lower.contains('petrol') ||
        lower.contains('hpcl') ||
        lower.contains('bpcl') ||
        lower.contains('iocl') ||
        lower.contains('shell') ||
        lower.contains('fuel') ||
        lower.contains('fastag') ||
        lower.contains('uber') ||
        lower.contains('ola') ||
        lower.contains('rapido') ||
        lower.contains('metro') ||
        lower.contains('irctc') ||
        lower.contains('flight') ||
        lower.contains('indigo')) {
      final isFuel = lower.contains('petrol') || lower.contains('hpcl') || lower.contains('bpcl') || lower.contains('fuel');
      return CategorizationSuggestion(
        category: 'Traveling',
        subCategory: isFuel ? 'Fuel / Petrol' : 'Cab / Auto / Taxi',
        bucket: 'Needs',
      );
    }

    // SIP & Investments
    if (lower.contains('zerodha') ||
        lower.contains('groww') ||
        lower.contains('upstox') ||
        lower.contains('kuvera') ||
        lower.contains('mutual fund') ||
        lower.contains('sip') ||
        lower.contains('cams') ||
        lower.contains('kfin') ||
        lower.contains('etmoney') ||
        lower.contains('nippon') ||
        lower.contains('uti') ||
        lower.contains('ppfas')) {
      return const CategorizationSuggestion(
        category: 'SIP & Investments',
        subCategory: 'Mutual Funds (SIP)',
        bucket: 'Savings',
      );
    }

    // Bills & Utilities
    if (lower.contains('bescom') ||
        lower.contains('electricity') ||
        lower.contains('airtel') ||
        lower.contains('jio') ||
        lower.contains('vodafone') ||
        lower.contains('vi') ||
        lower.contains('broadband') ||
        lower.contains('water') ||
        lower.contains('gas') ||
        lower.contains('bill desk') ||
        lower.contains('bbps')) {
      return const CategorizationSuggestion(
        category: 'Bills & Utilities',
        subCategory: 'Electricity Bill',
        bucket: 'Needs',
      );
    }

    // Entertainment
    if (lower.contains('netflix') ||
        lower.contains('spotify') ||
        lower.contains('hotstar') ||
        lower.contains('prime video') ||
        lower.contains('pvr') ||
        lower.contains('inox') ||
        lower.contains('bookmyshow') ||
        lower.contains('cinema') ||
        lower.contains('steam')) {
      return const CategorizationSuggestion(
        category: 'Entertainment',
        subCategory: 'Movies & Outing',
        bucket: 'Wants',
      );
    }

    // Health & Medical
    if (lower.contains('apollo') ||
        lower.contains('pharmeasy') ||
        lower.contains('1mg') ||
        lower.contains('medplus') ||
        lower.contains('hospital') ||
        lower.contains('clinic') ||
        lower.contains('pharmacy') ||
        lower.contains('doctor')) {
      return const CategorizationSuggestion(
        category: 'Health & Medical',
        subCategory: 'Medicines / Pharmacy',
        bucket: 'Needs',
      );
    }

    // Cash Withdrawal
    if (lower.contains('atm') || lower.contains('cash wdl') || lower.contains('nfs') || lower.contains('cash withdrawal')) {
      return const CategorizationSuggestion(
        category: 'Other',
        subCategory: 'Cash Withdrawal',
        bucket: 'Needs',
      );
    }

    // Default Fallback
    return const CategorizationSuggestion(
      category: 'Other',
      subCategory: 'Other',
      bucket: 'Needs',
    );
  }

  /// Maps a chosen category to its 50-30-20 budget bucket
  static String mapCategoryTo503020(String category) {
    if (category == 'Internal Transfer') return 'Transfer';
    if (category == 'SIP & Investments') return 'Savings';
    if (['Shopping', 'Entertainment'].contains(category)) return 'Wants';
    return 'Needs';
  }
}

class CategorizationSuggestion {
  final String category;
  final String subCategory;
  final String bucket; // 'Needs' | 'Wants' | 'Savings' | 'Income' | 'Transfer'
  final bool isTransfer;

  const CategorizationSuggestion({
    required this.category,
    required this.subCategory,
    required this.bucket,
    this.isTransfer = false,
  });
}
