import 'package:shared_preferences/shared_preferences.dart';

import '../models/ratings.dart';

class RatingStore {
  static const _kKey = 'skutla.ratings_received';

  final _cache = <RatingRecord>[];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey) ?? '';
    _cache
      ..clear()
      ..addAll(decodeRatings(raw));
    _loaded = true;
  }

  Future<List<RatingRecord>> all() async {
    await _ensureLoaded();
    return List.unmodifiable(_cache);
  }

  Future<RatingSummary> summary() async {
    await _ensureLoaded();
    if (_cache.isEmpty) return RatingSummary.empty;
    final sum = _cache.fold<int>(0, (s, r) => s + r.score);
    return RatingSummary(
      average: sum / _cache.length,
      count: _cache.length,
    );
  }

  Future<bool> add(RatingRecord record) async {
    await _ensureLoaded();
    if (record.rideId != null) {
      final exists = _cache.any((r) =>
          r.rideId == record.rideId && r.fromId == record.fromId);
      if (exists) return false;
    }
    _cache.add(record);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, encodeRatings(_cache));
    return true;
  }
}
