import 'dart:convert';

import 'messages.dart';

class RideRecord {
  RideRecord({
    required this.rideId,
    required this.role,
    required this.counterpartyId,
    required this.startedAt,
    required this.endedAt,
    this.counterpartyName,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
    this.price,
    this.currency,
  });

  final String rideId;
  final Role role;
  final String counterpartyId;
  final String? counterpartyName;
  final DateTime startedAt;
  final DateTime endedAt;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  final double? price;
  final String? currency;

  Duration get duration => endedAt.difference(startedAt);

  Map<String, dynamic> toJson() => {
        'rideId': rideId,
        'role': role.name,
        'counterpartyId': counterpartyId,
        'counterpartyName': counterpartyName,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'destLat': destLat,
        'destLng': destLng,
        'price': price,
        'currency': currency,
      };

  static RideRecord? tryFromJson(Map<String, dynamic> m) {
    try {
      return RideRecord(
        rideId: m['rideId'] as String,
        role: Role.values.firstWhere(
          (r) => r.name == (m['role'] as String? ?? ''),
          orElse: () => Role.passenger,
        ),
        counterpartyId: m['counterpartyId'] as String,
        counterpartyName: m['counterpartyName'] as String?,
        startedAt: DateTime.tryParse(m['startedAt'] as String? ?? '') ??
            DateTime.now(),
        endedAt: DateTime.tryParse(m['endedAt'] as String? ?? '') ??
            DateTime.now(),
        pickupLat: (m['pickupLat'] as num?)?.toDouble(),
        pickupLng: (m['pickupLng'] as num?)?.toDouble(),
        destLat: (m['destLat'] as num?)?.toDouble(),
        destLng: (m['destLng'] as num?)?.toDouble(),
        price: (m['price'] as num?)?.toDouble(),
        currency: m['currency'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

String encodeRides(List<RideRecord> records) =>
    jsonEncode(records.map((r) => r.toJson()).toList());

List<RideRecord> decodeRides(String raw) {
  if (raw.isEmpty) return [];
  final data = jsonDecode(raw);
  if (data is! List) return [];
  return data
      .whereType<Map<String, dynamic>>()
      .map(RideRecord.tryFromJson)
      .whereType<RideRecord>()
      .toList();
}
