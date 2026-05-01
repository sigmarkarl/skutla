const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

String encodeGeohash(double lat, double lng, {int precision = 5}) {
  double minLat = -90, maxLat = 90;
  double minLng = -180, maxLng = 180;
  final hash = StringBuffer();
  bool isLng = true;
  int bit = 0;
  int ch = 0;
  while (hash.length < precision) {
    if (isLng) {
      final mid = (minLng + maxLng) / 2;
      if (lng >= mid) {
        ch = (ch << 1) | 1;
        minLng = mid;
      } else {
        ch = ch << 1;
        maxLng = mid;
      }
    } else {
      final mid = (minLat + maxLat) / 2;
      if (lat >= mid) {
        ch = (ch << 1) | 1;
        minLat = mid;
      } else {
        ch = ch << 1;
        maxLat = mid;
      }
    }
    isLng = !isLng;
    bit++;
    if (bit == 5) {
      hash.write(_base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return hash.toString();
}

class GeohashBounds {
  const GeohashBounds(this.minLat, this.minLng, this.maxLat, this.maxLng);
  final double minLat, minLng, maxLat, maxLng;
  double get centerLat => (minLat + maxLat) / 2;
  double get centerLng => (minLng + maxLng) / 2;
  double get latStep => maxLat - minLat;
  double get lngStep => maxLng - minLng;
}

GeohashBounds decodeGeohashBounds(String hash) {
  double minLat = -90, maxLat = 90;
  double minLng = -180, maxLng = 180;
  bool isLng = true;
  for (final c in hash.split('')) {
    final idx = _base32.indexOf(c);
    if (idx < 0) continue;
    for (int b = 4; b >= 0; b--) {
      final bit = (idx >> b) & 1;
      if (isLng) {
        final mid = (minLng + maxLng) / 2;
        if (bit == 1) {
          minLng = mid;
        } else {
          maxLng = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (bit == 1) {
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }
      isLng = !isLng;
    }
  }
  return GeohashBounds(minLat, minLng, maxLat, maxLng);
}

List<String> geohashNeighbors(String hash) {
  final b = decodeGeohashBounds(hash);
  final p = hash.length;
  final cLat = b.centerLat, cLng = b.centerLng;
  final dLat = b.latStep, dLng = b.lngStep;
  return [
    encodeGeohash(cLat + dLat, cLng - dLng, precision: p),
    encodeGeohash(cLat + dLat, cLng, precision: p),
    encodeGeohash(cLat + dLat, cLng + dLng, precision: p),
    encodeGeohash(cLat, cLng - dLng, precision: p),
    encodeGeohash(cLat, cLng + dLng, precision: p),
    encodeGeohash(cLat - dLat, cLng - dLng, precision: p),
    encodeGeohash(cLat - dLat, cLng, precision: p),
    encodeGeohash(cLat - dLat, cLng + dLng, precision: p),
  ];
}

Set<String> geohashSearchCells(double lat, double lng, {int precision = 5}) {
  final center = encodeGeohash(lat, lng, precision: precision);
  return {center, ...geohashNeighbors(center)};
}
