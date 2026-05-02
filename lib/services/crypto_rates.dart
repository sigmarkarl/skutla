import 'dart:convert';

import 'package:http/http.dart' as http;

class CryptoRates {
  static final _cache = <String, double>{};
  static DateTime? _cacheAt;

  /// Returns the price of `coinId` ('bitcoin' or 'ethereum') in `currency`
  /// (lowercase ISO code, e.g. 'usd', 'isk', 'eur'). Returns null on failure.
  /// Results are cached for 60 seconds to avoid hammering the API.
  static Future<double?> price({
    required String coinId,
    required String currency,
  }) async {
    final key = '$coinId/$currency';
    final fresh = _cacheAt != null &&
        DateTime.now().difference(_cacheAt!).inSeconds < 60;
    if (fresh && _cache.containsKey(key)) return _cache[key];
    try {
      final url = Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=$currency',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data is! Map) return null;
      _cacheAt = DateTime.now();
      for (final coin in ['bitcoin', 'ethereum']) {
        final entry = data[coin];
        if (entry is Map) {
          final v = entry[currency];
          if (v is num) _cache['$coin/$currency'] = v.toDouble();
        }
      }
      return _cache[key];
    } catch (_) {
      return null;
    }
  }

  /// Convert `fiatAmount` in `currency` to the coin's native unit
  /// (BTC or ETH). Returns null if rate lookup fails.
  static Future<double?> convert({
    required String coinId,
    required String currency,
    required double fiatAmount,
  }) async {
    final p = await price(coinId: coinId, currency: currency.toLowerCase());
    if (p == null || p <= 0) return null;
    return fiatAmount / p;
  }
}
