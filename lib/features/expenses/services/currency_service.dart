import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/storage_service.dart';
import '../models/currency.dart';

class CurrencyService {
  static const String _apiUrl = 'https://api.frankfurter.app';
  static const String _ratesCacheKey = 'exchange_rates';
  static const String _ratesTimeKey = 'exchange_rates_time';

  final Dio _dio;

  CurrencyService({Dio? dio}) : _dio = dio ?? Dio();

  /// Fetch latest exchange rates from API
  Future<Map<String, double>> fetchExchangeRates(String baseCurrency) async {
    try {
      final response = await _dio.get(
        '$_apiUrl/latest',
        queryParameters: {'from': baseCurrency},
      );

      if (response.statusCode == 200) {
        final rates = <String, double>{};
        final ratesData = response.data['rates'] as Map<String, dynamic>;

        for (final entry in ratesData.entries) {
          rates[entry.key] = (entry.value as num).toDouble();
        }

        // Add base currency with rate 1.0
        rates[baseCurrency] = 1.0;

        // Cache the rates
        await _cacheRates(baseCurrency, rates);

        return rates;
      }

      return _getCachedRates(baseCurrency);
    } catch (e) {
      debugPrint('Failed to fetch exchange rates: $e');
      return _getCachedRates(baseCurrency);
    }
  }

  /// Get cached exchange rates
  Future<Map<String, double>> _getCachedRates(String baseCurrency) async {
    try {
      final cached = StorageService.getSetting<Map<dynamic, dynamic>>(
        '${_ratesCacheKey}_$baseCurrency',
      );

      if (cached != null) {
        return cached.map((key, value) =>
            MapEntry(key.toString(), (value as num).toDouble()));
      }
    } catch (e) {
      debugPrint('Failed to get cached rates: $e');
    }

    // Return default rates if no cache
    return _getDefaultRates(baseCurrency);
  }

  /// Cache exchange rates
  Future<void> _cacheRates(String baseCurrency, Map<String, double> rates) async {
    try {
      await StorageService.setSetting('${_ratesCacheKey}_$baseCurrency', rates);
      await StorageService.setSetting(
        '${_ratesTimeKey}_$baseCurrency',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Failed to cache rates: $e');
    }
  }

  /// Get cached rates timestamp
  Future<DateTime?> getCachedRatesTime(String baseCurrency) async {
    try {
      final timeStr = StorageService.getSetting<String>(
        '${_ratesTimeKey}_$baseCurrency',
      );
      if (timeStr != null) {
        return DateTime.parse(timeStr);
      }
    } catch (e) {
      debugPrint('Failed to get rates time: $e');
    }
    return null;
  }

  /// Check if cached rates are stale (older than 24 hours)
  Future<bool> areCachedRatesStale(String baseCurrency) async {
    final lastUpdate = await getCachedRatesTime(baseCurrency);
    if (lastUpdate == null) return true;

    final age = DateTime.now().difference(lastUpdate);
    return age.inHours > 24;
  }

  /// Get rates, fetching fresh if stale
  Future<Map<String, double>> getRates(String baseCurrency, {bool forceRefresh = false}) async {
    if (forceRefresh || await areCachedRatesStale(baseCurrency)) {
      return fetchExchangeRates(baseCurrency);
    }
    return _getCachedRates(baseCurrency);
  }

  /// Default fallback rates (approximate, for offline use)
  Map<String, double> _getDefaultRates(String baseCurrency) {
    // Approximate rates relative to INR
    const inrRates = {
      'INR': 1.0,
      'USD': 0.012,
      'EUR': 0.011,
      'GBP': 0.0095,
      'THB': 0.42,
      'SGD': 0.016,
      'MYR': 0.055,
      'AED': 0.044,
      'LKR': 3.6,
      'NPR': 1.6,
      'JPY': 1.8,
      'AUD': 0.018,
      'CAD': 0.016,
      'CHF': 0.011,
      'CNY': 0.086,
    };

    if (baseCurrency == 'INR') {
      return inrRates;
    }

    // Convert to requested base currency
    final baseToInr = 1 / (inrRates[baseCurrency] ?? 1.0);
    return inrRates.map((key, value) => MapEntry(key, value * baseToInr));
  }

  /// Create currency settings for a trip
  Future<TripCurrencySettings> createTripCurrencySettings(
    String primaryCurrencyCode,
  ) async {
    final rates = await getRates(primaryCurrencyCode);
    return TripCurrencySettings(
      primaryCurrencyCode: primaryCurrencyCode,
      exchangeRates: rates,
      lastRatesUpdate: DateTime.now(),
    );
  }

  /// Update currency settings with fresh rates
  Future<TripCurrencySettings> refreshCurrencySettings(
    TripCurrencySettings current,
  ) async {
    final rates = await fetchExchangeRates(current.primaryCurrencyCode);
    return current.copyWith(
      exchangeRates: rates,
      lastRatesUpdate: DateTime.now(),
    );
  }
}
