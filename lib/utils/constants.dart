/// App-wide constants derived from the Excel Lookups sheet.
/// This is the single source of truth for all default data.
class AppConstants {
  AppConstants._();

  // ── App Info ───────────────────────────────────────────────────
  static const String appName    = 'Finance Manager';
  static const String appVersion = '1.0.0';
  static const String currency   = '₹';
  static const String locale     = 'en_IN';

  // ── Default Banks (from Excel Banks sheet) ─────────────────────
  static const List<String> defaultBanks = ['HSBC', 'HDFC', 'PNB', 'SBI'];

  // ── Income Modes (from Extra Credit sheet) ─────────────────────
  static const List<String> incomeModes = [
    'Salary',
    'Bonus',
    'Loan Received',
    'Interest',
    'Freelance',
    'Gift',
    'Other',
  ];

  // ── All Categories & Sub-Categories (from Lookups sheet) ───────
  /// Map of category → list of sub-categories
  static const Map<String, List<String>> categorySubMap = {
    'Food': [
      'Groceries',
      'Dining Out',
      'Zomato / Swiggy',
      'Cafe & Snacks',
      'Pani Puri',
      'Other',
    ],
    'Shopping': [
      'Clothing & Footwear',
      'Electronics & Gadgets',
      'Home & Kitchen',
      'Personal Care',
    ],
    'Traveling': [
      'Fuel / Petrol',
      'Cab / Auto / Taxi',
      'Metro / Bus',
      'Flight / Train',
      'Vehicle Service / Fastag',
    ],
    'Home Send': [
      'Didi',
      'Papa',
      'Mummy',
      'House Rent',
      'Home Maintenance',
    ],
    'SIP & Investments': [
      'SIP',
      'FD',
      'RD',
      'Mutual Funds',
      'Mutual Funds (SIP)',
      'Stocks / Shares',
      'PPF',
      'NPS',
      'Gold / SGB',
      'Other Investment',
    ],
    'Loan': [
      'Personal Loan',
      'Education Loan',
      'Home Loan',
      'Other Loan',
    ],
    'Credit Card Payment': [
      'HDFC Card',
      'HSBC Card',
    ],
    'Bills & Utilities': [
      'Electricity Bill',
      'Mobile & Wifi',
      'Water & Gas',
      'DTH / OTT Subscriptions',
      'Miscellaneous',
    ],
    'Health & Medical': [
      'Medicines / Pharmacy',
      'Doctor & Hospital',
      'Health Insurance',
    ],
    'Entertainment': [
      'Movies & Outing',
      'Vacation & Trips',
    ],
    'Quick Ecommerce': [
      'Blinkit',
      'Zepto',
      'Instamart',
      'BB Now',
      'Other',
    ],
    'Other': [
      'Cash Withdrawal',
      'Miscellaneous',
      'Other',
    ],
  };

  /// Ordered list of category names (preserves display order)
  static List<String> get categories => categorySubMap.keys.toList();

  /// Emoji icons per category
  static const Map<String, String> categoryIcons = {
    'Food':                  '🍔',
    'Shopping':              '🛍️',
    'Traveling':             '✈️',
    'Home Send':             '🏠',
    'SIP & Investments':     '📈',
    'Loan':                  '💳',
    'Credit Card Payment':   '💳',
    'Bills & Utilities':     '⚡',
    'Health & Medical':      '🏥',
    'Entertainment':         '🎭',
    'Quick Ecommerce':       '📦',
    'Other':                 '🔹',
  };

  /// Hex color per category (without #)
  static const Map<String, String> categoryColors = {
    'Food':                  'F97316',
    'Shopping':              'EC4899',
    'Traveling':             '06B6D4',
    'Home Send':             '10B981',
    'SIP & Investments':     '7C3AED',
    'Loan':                  'EF4444',
    'Credit Card Payment':   'F43F5E',
    'Bills & Utilities':     '3B82F6',
    'Health & Medical':      '14B8A6',
    'Entertainment':         'A855F7',
    'Quick Ecommerce':       'F59E0B',
    'Other':                 '94A3B8',
  };

  // ── Month Names ────────────────────────────────────────────────
  static const List<String> monthNames = [
    'January', 'February', 'March',     'April',
    'May',     'June',     'July',      'August',
    'September','October', 'November',  'December',
  ];

  static const List<String> shortMonthNames = [
    'Jan', 'Feb', 'Mar', 'Apr',
    'May', 'Jun', 'Jul', 'Aug',
    'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // ── Investment Sub-Categories (for portfolio grouping) ─────────
  static const List<String> investmentTypes = [
    'SIP',
    'FD',
    'RD',
    'Mutual Funds',
    'Stocks / Shares',
    'PPF',
    'NPS',
    'Gold / SGB',
    'Other Investment',
  ];

  // ── SQLite DB Settings ─────────────────────────────────────────
  static const String dbName    = 'finance_manager.db';
  static const int    dbVersion = 1;

  // ── Table Names ────────────────────────────────────────────────
  static const String tableExpenses      = 'expenses';
  static const String tableBanks         = 'banks';
  static const String tableExtraCredit   = 'extra_credit';
  static const String tableTransfers     = 'transfers';
  static const String tableCategories    = 'categories';
  static const String tableSubCategories = 'sub_categories';
}
