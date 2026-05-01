import 'dart:convert';

import 'package:http/http.dart' as http;

class Geocoding {
  static const _userAgent = 'is.skutla.app/1.0';

  static Future<String?> reverseCountryCode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&zoom=3&lat=$lat&lon=$lng',
      );
      final res = await http.get(
        url,
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data is! Map) return null;
      final address = data['address'];
      if (address is! Map) return null;
      final code = address['country_code'];
      return code is String ? code.toUpperCase() : null;
    } catch (_) {
      return null;
    }
  }
}
