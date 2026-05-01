import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BackupService {
  static const _allKeys = <String>[
    'skutla.peer_id',
    'skutla.role',
    'skutla.display_name',
    'skutla.car_info',
    'skutla.contact_info',
    'skutla.share_contact',
    'skutla.payment_info',
    'skutla.currency',
    'skutla.ratings_received',
    'skutla.ride_history',
  ];

  Future<String> export() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final key in _allKeys) {
      final value = prefs.get(key);
      if (value != null) {
        data[key] = value;
      }
    }
    return jsonEncode({
      'v': 1,
      'data': data,
    });
  }

  /// Returns true on successful restore.
  Future<bool> import(String raw) async {
    try {
      final m = jsonDecode(raw.trim()) as Map<String, dynamic>;
      final data = m['data'];
      if (data is! Map<String, dynamic>) return false;
      if (data['skutla.peer_id'] is! String) return false;

      final prefs = await SharedPreferences.getInstance();
      for (final key in _allKeys) {
        final v = data[key];
        if (v == null) {
          await prefs.remove(key);
        } else if (v is String) {
          await prefs.setString(key, v);
        } else if (v is bool) {
          await prefs.setBool(key, v);
        } else if (v is int) {
          await prefs.setInt(key, v);
        } else if (v is double) {
          await prefs.setDouble(key, v);
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
