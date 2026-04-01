class TripCurrency {
  final String code;
  final String symbol;
  final String name;
  final bool isPrimary;
  final double rateToBase;

  const TripCurrency({
    required this.code,
    required this.symbol,
    required this.name,
    this.isPrimary = false,
    this.rateToBase = 1.0,
  });

  static const Map<String, String> currencySymbols = {
    'INR': '\u20B9',
    'USD': '\$',
    'EUR': '\u20AC',
    'GBP': '\u00A3',
    'THB': '\u0E3F',
    'SGD': 'S\$',
    'MYR': 'RM',
    'AED': 'AED',
    'LKR': 'Rs',
    'NPR': 'Rs',
    'JPY': '\u00A5',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'CHF': 'CHF',
    'CNY': '\u00A5',
    'NZD': 'NZ\$',
    'BDT': '\u09F3',
    'PKR': 'Rs',
    'IDR': 'Rp',
    'PHP': '\u20B1',
    'VND': '\u20AB',
    'KRW': '\u20A9',
  };

  static const Map<String, String> currencyNames = {
    'INR': 'Indian Rupee',
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'GBP': 'British Pound',
    'THB': 'Thai Baht',
    'SGD': 'Singapore Dollar',
    'MYR': 'Malaysian Ringgit',
    'AED': 'UAE Dirham',
    'LKR': 'Sri Lankan Rupee',
    'NPR': 'Nepalese Rupee',
    'JPY': 'Japanese Yen',
    'AUD': 'Australian Dollar',
    'CAD': 'Canadian Dollar',
    'CHF': 'Swiss Franc',
    'CNY': 'Chinese Yuan',
    'NZD': 'New Zealand Dollar',
    'BDT': 'Bangladeshi Taka',
    'PKR': 'Pakistani Rupee',
    'IDR': 'Indonesian Rupiah',
    'PHP': 'Philippine Peso',
    'VND': 'Vietnamese Dong',
    'KRW': 'South Korean Won',
  };

  static String getSymbol(String code) {
    return currencySymbols[code] ?? code;
  }

  static String getName(String code) {
    return currencyNames[code] ?? code;
  }

  static List<String> get availableCurrencies => currencySymbols.keys.toList();

  TripCurrency copyWith({
    String? code,
    String? symbol,
    String? name,
    bool? isPrimary,
    double? rateToBase,
  }) {
    return TripCurrency(
      code: code ?? this.code,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      isPrimary: isPrimary ?? this.isPrimary,
      rateToBase: rateToBase ?? this.rateToBase,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'symbol': symbol,
      'name': name,
      'isPrimary': isPrimary,
      'rateToBase': rateToBase,
    };
  }

  factory TripCurrency.fromJson(Map<String, dynamic> json) {
    return TripCurrency(
      code: json['code'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      isPrimary: json['isPrimary'] as bool? ?? false,
      rateToBase: (json['rateToBase'] as num?)?.toDouble() ?? 1.0,
    );
  }

  factory TripCurrency.fromCode(String code, {bool isPrimary = false, double rateToBase = 1.0}) {
    return TripCurrency(
      code: code,
      symbol: getSymbol(code),
      name: getName(code),
      isPrimary: isPrimary,
      rateToBase: rateToBase,
    );
  }
}

class TripCurrencySettings {
  final String primaryCurrencyCode;
  final Map<String, double> exchangeRates;
  final DateTime lastRatesUpdate;

  const TripCurrencySettings({
    required this.primaryCurrencyCode,
    required this.exchangeRates,
    required this.lastRatesUpdate,
  });

  factory TripCurrencySettings.defaults() {
    return TripCurrencySettings(
      primaryCurrencyCode: 'INR',
      exchangeRates: {'INR': 1.0},
      lastRatesUpdate: DateTime.now(),
    );
  }

  double convert(double amount, String fromCurrency, String toCurrency) {
    if (fromCurrency == toCurrency) return amount;

    final fromRate = exchangeRates[fromCurrency] ?? 1.0;
    final toRate = exchangeRates[toCurrency] ?? 1.0;

    // Convert to base (primary), then to target
    final inBase = amount / fromRate;
    return inBase * toRate;
  }

  double toBase(double amount, String fromCurrency) {
    return convert(amount, fromCurrency, primaryCurrencyCode);
  }

  TripCurrencySettings copyWith({
    String? primaryCurrencyCode,
    Map<String, double>? exchangeRates,
    DateTime? lastRatesUpdate,
  }) {
    return TripCurrencySettings(
      primaryCurrencyCode: primaryCurrencyCode ?? this.primaryCurrencyCode,
      exchangeRates: exchangeRates ?? this.exchangeRates,
      lastRatesUpdate: lastRatesUpdate ?? this.lastRatesUpdate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primaryCurrencyCode': primaryCurrencyCode,
      'exchangeRates': exchangeRates,
      'lastRatesUpdate': lastRatesUpdate.toIso8601String(),
    };
  }

  factory TripCurrencySettings.fromJson(Map<String, dynamic> json) {
    return TripCurrencySettings(
      primaryCurrencyCode: json['primaryCurrencyCode'] as String,
      exchangeRates: Map<String, double>.from(
        (json['exchangeRates'] as Map).map(
          (key, value) => MapEntry(key as String, (value as num).toDouble()),
        ),
      ),
      lastRatesUpdate: DateTime.parse(json['lastRatesUpdate'] as String),
    );
  }
}
