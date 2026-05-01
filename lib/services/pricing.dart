import 'dart:ui' show PlatformDispatcher;

import 'package:intl/intl.dart';

class Pricing {
  static const _baseByCurrency = <String, num>{
    'ISK': 800,
    'USD': 5,
    'EUR': 5,
    'GBP': 4,
    'JPY': 600,
    'CAD': 7,
    'AUD': 8,
    'CHF': 5,
    'NOK': 60,
    'SEK': 60,
    'DKK': 40,
  };
  static const _perKmByCurrency = <String, num>{
    'ISK': 250,
    'USD': 2,
    'EUR': 2,
    'GBP': 1.5,
    'JPY': 200,
    'CAD': 2.5,
    'AUD': 3,
    'CHF': 2,
    'NOK': 20,
    'SEK': 20,
    'DKK': 15,
  };

  static String detectCurrency() {
    try {
      final locale = PlatformDispatcher.instance.locale.toString();
      final fmt = NumberFormat.simpleCurrency(locale: locale);
      return fmt.currencyName ?? 'USD';
    } catch (_) {
      return 'USD';
    }
  }

  static const _countryToCurrency = {
    'IS': 'ISK',
    'US': 'USD', 'PR': 'USD', 'EC': 'USD', 'SV': 'USD', 'PA': 'USD',
    'GB': 'GBP', 'JE': 'GBP', 'GG': 'GBP', 'IM': 'GBP',
    'CA': 'CAD',
    'AU': 'AUD',
    'NZ': 'NZD',
    'JP': 'JPY',
    'CH': 'CHF', 'LI': 'CHF',
    'NO': 'NOK',
    'SE': 'SEK',
    'DK': 'DKK',
    'AT': 'EUR', 'BE': 'EUR', 'CY': 'EUR', 'EE': 'EUR', 'FI': 'EUR',
    'FR': 'EUR', 'DE': 'EUR', 'GR': 'EUR', 'IE': 'EUR', 'IT': 'EUR',
    'LV': 'EUR', 'LT': 'EUR', 'LU': 'EUR', 'MT': 'EUR', 'NL': 'EUR',
    'PT': 'EUR', 'SK': 'EUR', 'SI': 'EUR', 'ES': 'EUR', 'HR': 'EUR',
    'AD': 'EUR', 'MC': 'EUR', 'SM': 'EUR', 'VA': 'EUR', 'ME': 'EUR',
    'XK': 'EUR',
    'IN': 'INR',
    'CN': 'CNY',
    'BR': 'BRL',
    'MX': 'MXN',
    'AR': 'ARS',
    'PL': 'PLN',
    'CZ': 'CZK',
    'HU': 'HUF',
    'RO': 'RON',
    'BG': 'BGN',
    'TR': 'TRY',
    'RU': 'RUB',
    'UA': 'UAH',
    'KR': 'KRW',
    'TW': 'TWD',
    'HK': 'HKD',
    'SG': 'SGD',
    'TH': 'THB',
    'VN': 'VND',
    'ID': 'IDR',
    'MY': 'MYR',
    'PH': 'PHP',
    'ZA': 'ZAR',
    'EG': 'EGP',
    'NG': 'NGN',
    'KE': 'KES',
    'IL': 'ILS',
    'AE': 'AED',
    'SA': 'SAR',
    'QA': 'QAR',
  };

  static String currencyForCountry(String countryCode) {
    return _countryToCurrency[countryCode.toUpperCase()] ?? 'USD';
  }

  static double estimate({
    required String currency,
    required double distanceMeters,
  }) {
    final base = (_baseByCurrency[currency] ?? 5).toDouble();
    final perKm = (_perKmByCurrency[currency] ?? 2).toDouble();
    return base + (distanceMeters / 1000.0) * perKm;
  }

  static String format(double amount, String currency) {
    try {
      final fmt = NumberFormat.simpleCurrency(name: currency);
      return fmt.format(amount);
    } catch (_) {
      return '${amount.toStringAsFixed(2)} $currency';
    }
  }

  static String round(double amount, String currency) {
    final whole = amount.round().toDouble();
    return format(whole, currency);
  }
}
