import 'package:shared_preferences/shared_preferences.dart';

import '../models/ride_record.dart';

class RideHistoryStore {
  static const _kKey = 'skutla.ride_history';
  static const _maxEntries = 200;

  Future<List<RideRecord>> all() async {
    final prefs = await SharedPreferences.getInstance();
    return decodeRides(prefs.getString(_kKey) ?? '');
  }

  Future<void> add(RideRecord r) async {
    final list = await all();
    if (list.any((e) => e.rideId == r.rideId)) return;
    list.insert(0, r);
    if (list.length > _maxEntries) {
      list.removeRange(_maxEntries, list.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, encodeRides(list));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
