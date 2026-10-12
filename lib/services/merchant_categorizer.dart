import '../db/database_helper.dart';

/// Service responsible for automatically predicting and assigning categories
/// and sub-categories to merchants detected from SMS and push notifications.
class MerchantCategorizer {
  MerchantCategorizer._();

  /// Default seed dictionary mapping common Indian merchants to app categories & sub-categories.
  static final Map<String, (String category, String subCategory)> _seedKeywords = {
    // ── Food & Dining ──────────────────────────────────────────
    'ZOMATO': ('Food', 'Zomato / Swiggy'),
    'SWIGGY': ('Food', 'Zomato / Swiggy'),
    'MCDONALD': ('Food', 'Dining Out'),
    'DOMINOS': ('Food', 'Dining Out'),
    'KFC': ('Food', 'Dining Out'),
    'STARBUCKS': ('Food', 'Cafe & Snacks'),
    'CHAI POINT': ('Food', 'Cafe & Snacks'),
    'CHAIPOINT': ('Food', 'Cafe & Snacks'),
    'CHAI': ('Food', 'Cafe & Snacks'),
    'CHAIOS': ('Food', 'Cafe & Snacks'),
    'BURGER KING': ('Food', 'Dining Out'),
    'HALDIRAM': ('Food', 'Dining Out'),
    'RESTAURANT': ('Food', 'Dining Out'),
    'CAFE': ('Food', 'Cafe & Snacks'),
    'BAKERY': ('Food', 'Cafe & Snacks'),
    'GROCERY': ('Food', 'Groceries'),
    'SUPERMARKET': ('Food', 'Groceries'),
    'VEGETABLE': ('Food', 'Groceries'),

    // ── Quick Ecommerce ────────────────────────────────────────
    'BLINKIT': ('Quick Ecommerce', 'Blinkit'),
    'ZEPTO': ('Quick Ecommerce', 'Zepto'),
    'INSTAMART': ('Quick Ecommerce', 'Instamart'),
    'BBNOW': ('Quick Ecommerce', 'BB Now'),
    'BIGBASKET': ('Quick Ecommerce', 'BB Now'),
    'DUNZO': ('Quick Ecommerce', 'Other'),

    // ── Traveling & Fuel ───────────────────────────────────────
    'UBER': ('Traveling', 'Cab / Auto / Taxi'),
    'OLA': ('Traveling', 'Cab / Auto / Taxi'),
    'RAPIDO': ('Traveling', 'Cab / Auto / Taxi'),
    'HPCL': ('Traveling', 'Fuel / Petrol'),
    'BPCL': ('Traveling', 'Fuel / Petrol'),
    'IOCL': ('Traveling', 'Fuel / Petrol'),
    'INDIAN OIL': ('Traveling', 'Fuel / Petrol'),
    'SHELL': ('Traveling', 'Fuel / Petrol'),
    'PETROL': ('Traveling', 'Fuel / Petrol'),
    'FASTAG': ('Traveling', 'Vehicle Service / Fastag'),
    'IRCTC': ('Traveling', 'Flight / Train'),
    'MAKEMYTRIP': ('Traveling', 'Flight / Train'),
    'CLEARTRIP': ('Traveling', 'Flight / Train'),
    'METRO': ('Traveling', 'Metro / Bus'),

    // ── Shopping ───────────────────────────────────────────────
    'AMAZON': ('Shopping', 'Electronics & Gadgets'),
    'FLIPKART': ('Shopping', 'Electronics & Gadgets'),
    'MYNTRA': ('Shopping', 'Clothing & Footwear'),
    'AJIO': ('Shopping', 'Clothing & Footwear'),
    'ZARA': ('Shopping', 'Clothing & Footwear'),
    'H&M': ('Shopping', 'Clothing & Footwear'),
    'CROMA': ('Shopping', 'Electronics & Gadgets'),
    'RELIANCE DIGITAL': ('Shopping', 'Electronics & Gadgets'),
    'DECATHLON': ('Shopping', 'Clothing & Footwear'),
    'NYKAA': ('Shopping', 'Personal Care'),

    // ── SIP & Investments ──────────────────────────────────────
    'ZERODHA': ('SIP & Investments', 'Stocks / Shares'),
    'GROWW': ('SIP & Investments', 'Mutual Funds'),
    'CAMS': ('SIP & Investments', 'Mutual Funds (SIP)'),
    'KFINTECH': ('SIP & Investments', 'Mutual Funds (SIP)'),
    'KUVERA': ('SIP & Investments', 'Mutual Funds'),
    'UPSTOX': ('SIP & Investments', 'Stocks / Shares'),
    'ANGEL ONE': ('SIP & Investments', 'Stocks / Shares'),
    'PPFAS': ('SIP & Investments', 'Mutual Funds (SIP)'),
    'HDFC MUTUAL': ('SIP & Investments', 'Mutual Funds'),
    'SBI MUTUAL': ('SIP & Investments', 'Mutual Funds'),
    'NPS': ('SIP & Investments', 'PPF / NPS / FD'),

    // ── Bills & Utilities ──────────────────────────────────────
    'BESCOM': ('Bills & Utilities', 'Electricity Bill'),
    'TATA POWER': ('Bills & Utilities', 'Electricity Bill'),
    'ADANI ELECTRICITY': ('Bills & Utilities', 'Electricity Bill'),
    'MAHAVITARAN': ('Bills & Utilities', 'Electricity Bill'),
    'ELECTRICITY': ('Bills & Utilities', 'Electricity Bill'),
    'POWER': ('Bills & Utilities', 'Electricity Bill'),
    'WATER': ('Bills & Utilities', 'Water & Gas'),
    'GAS': ('Bills & Utilities', 'Water & Gas'),
    'JIO': ('Bills & Utilities', 'Mobile & Wifi'),
    'AIRTEL': ('Bills & Utilities', 'Mobile & Wifi'),
    'VI': ('Bills & Utilities', 'Mobile & Wifi'),
    'BILLDESK': ('Bills & Utilities', 'Miscellaneous'),
    'ACT BROADBAND': ('Bills & Utilities', 'Mobile & Wifi'),
    'BROADBAND': ('Bills & Utilities', 'Mobile & Wifi'),
    'INDANE': ('Bills & Utilities', 'Water & Gas'),
    'HP GAS': ('Bills & Utilities', 'Water & Gas'),
    'DTH': ('Bills & Utilities', 'DTH / OTT Subscriptions'),
    'NETFLIX': ('Bills & Utilities', 'DTH / OTT Subscriptions'),
    'SPOTIFY': ('Bills & Utilities', 'DTH / OTT Subscriptions'),
    'INSURANCE': ('Bills & Utilities', 'Insurance (Health / Term / Vehicle)'),

    // ── Credit Card Payment ────────────────────────────────────
    'CRED': ('Credit Card Payment', 'HDFC Card'),
    'HDFC CARD': ('Credit Card Payment', 'HDFC Card'),
    'SBI CARD': ('Credit Card Payment', 'HSBC Card'),
    'ONECARD': ('Credit Card Payment', 'HDFC Card'),

    // ── Health & Medical ───────────────────────────────────────
    'APOLLO': ('Health & Medical', 'Medicines / Pharmacy'),
    '1MG': ('Health & Medical', 'Medicines / Pharmacy'),
    'PHARMEASY': ('Health & Medical', 'Medicines / Pharmacy'),
    'MEDPLUS': ('Health & Medical', 'Medicines / Pharmacy'),
    'HOSPITAL': ('Health & Medical', 'Doctor & Hospital'),
    'CLINIC': ('Health & Medical', 'Doctor & Hospital'),
    'PHARMACY': ('Health & Medical', 'Medicines / Pharmacy'),
    'HEALTH': ('Health & Medical', 'Doctor & Hospital'),

    // ── Entertainment ──────────────────────────────────────────
    'BOOKMYSHOW': ('Entertainment', 'Movies & Outing'),
    'PVR': ('Entertainment', 'Movies & Outing'),
    'INOX': ('Entertainment', 'Movies & Outing'),
    'CINEPOLIS': ('Entertainment', 'Movies & Outing'),

    // ── Loan ───────────────────────────────────────────────────
    'BAJAJ FINANCE': ('Loan', 'Personal Loan'),
    'HOME LOAN': ('Loan', 'Home Loan'),
    'HDBFS': ('Loan', 'Personal Loan'),
    'EMI': ('Loan', 'Personal Loan'),
  };

  /// Predict category and sub-category for a given merchant string.
  /// 1. First consults persistent SQLite learned rules (`merchant_category_rules`).
  /// 2. If no rule found, scans against the built-in seed dictionary.
  /// 3. Fallbacks to ('Other', 'Other').
  static Future<(String category, String? subCategory)> categorize(String merchant) async {
    final clean = merchant.trim().toUpperCase();
    if (clean.isEmpty) {
      return ('Other', 'Other');
    }

    // 1. Check local SQLite learned rules
    try {
      final learned = await DatabaseHelper.instance.getMerchantRule(clean);
      if (learned != null) {
        return (learned.category, learned.subCategory);
      }
    } catch (_) {}

    // 2. Partial check against seed keywords
    for (final entry in _seedKeywords.entries) {
      if (clean.contains(entry.key)) {
        return (entry.value.$1, entry.value.$2);
      }
    }

    // 3. Fallback
    return ('Other', 'Other');
  }
}
