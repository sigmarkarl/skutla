import 'dart:convert';

enum Role { driver, passenger }

class ContactInfo {
  const ContactInfo({this.phone, this.whatsapp, this.messenger});
  final String? phone;
  final String? whatsapp;
  final String? messenger;

  bool get hasAny =>
      (phone?.isNotEmpty ?? false) ||
      (whatsapp?.isNotEmpty ?? false) ||
      (messenger?.isNotEmpty ?? false);

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'whatsapp': whatsapp,
        'messenger': messenger,
      };

  static ContactInfo? tryFromJson(Map<String, dynamic>? m) {
    if (m == null) return null;
    final c = ContactInfo(
      phone: m['phone'] as String?,
      whatsapp: m['whatsapp'] as String?,
      messenger: m['messenger'] as String?,
    );
    return c.hasAny ? c : null;
  }
}

class PaymentInfo {
  const PaymentInfo({
    this.aur,
    this.paypal,
    this.venmo,
    this.wechat,
    this.cash,
  });
  final String? aur;
  final String? paypal;
  final String? venmo;
  final String? wechat;
  final bool? cash;

  bool get hasAny =>
      (aur?.isNotEmpty ?? false) ||
      (paypal?.isNotEmpty ?? false) ||
      (venmo?.isNotEmpty ?? false) ||
      (wechat?.isNotEmpty ?? false) ||
      (cash ?? false);

  Map<String, dynamic> toJson() => {
        'aur': aur,
        'paypal': paypal,
        'venmo': venmo,
        'wechat': wechat,
        'cash': cash,
      };

  static PaymentInfo? tryFromJson(Map<String, dynamic>? m) {
    if (m == null) return null;
    final p = PaymentInfo(
      aur: m['aur'] as String?,
      paypal: m['paypal'] as String?,
      venmo: m['venmo'] as String?,
      wechat: m['wechat'] as String?,
      cash: m['cash'] as bool?,
    );
    return p.hasAny ? p : null;
  }
}

class CarInfo {
  const CarInfo({
    required this.makeModel,
    required this.color,
    required this.plate,
  });

  final String makeModel;
  final String color;
  final String plate;

  bool get isComplete =>
      makeModel.isNotEmpty && color.isNotEmpty && plate.isNotEmpty;

  String get summary => '$color $makeModel · $plate';

  Map<String, dynamic> toJson() => {
        'makeModel': makeModel,
        'color': color,
        'plate': plate,
      };

  static CarInfo? tryFromJson(Map<String, dynamic>? m) {
    if (m == null) return null;
    final make = m['makeModel'] as String? ?? '';
    final color = m['color'] as String? ?? '';
    final plate = m['plate'] as String? ?? '';
    if (make.isEmpty && color.isEmpty && plate.isEmpty) return null;
    return CarInfo(makeModel: make, color: color, plate: plate);
  }
}

class DriverPresence {
  DriverPresence({
    required this.driverId,
    required this.lat,
    required this.lng,
    required this.available,
    required this.updatedAt,
    this.displayName,
    this.avgRating,
    this.ratingCount,
    this.car,
  });

  final String driverId;
  final double lat;
  final double lng;
  final bool available;
  final DateTime updatedAt;
  final String? displayName;
  final double? avgRating;
  final int? ratingCount;
  final CarInfo? car;

  Map<String, dynamic> toJson() => {
    'driverId': driverId,
    'lat': lat,
    'lng': lng,
    'available': available,
    'updatedAt': updatedAt.toIso8601String(),
    'displayName': displayName,
    'avgRating': avgRating,
    'ratingCount': ratingCount,
    'car': car?.toJson(),
  };

  String encode() => jsonEncode(toJson());

  static DriverPresence? tryDecode(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return DriverPresence(
        driverId: m['driverId'] as String,
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        available: m['available'] as bool? ?? false,
        updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? DateTime.now(),
        displayName: m['displayName'] as String?,
        avgRating: (m['avgRating'] as num?)?.toDouble(),
        ratingCount: (m['ratingCount'] as num?)?.toInt(),
        car: CarInfo.tryFromJson(m['car'] as Map<String, dynamic>?),
      );
    } catch (_) {
      return null;
    }
  }
}

enum InboxKind {
  rideRequest,
  rideOffer,
  rideResponse,
  locationUpdate,
  cancel,
  rating,
}

class InboxMessage {
  InboxMessage({
    required this.kind,
    required this.fromId,
    required this.toId,
    this.fromName,
    this.rideId,
    this.lat,
    this.lng,
    this.destLat,
    this.destLng,
    this.accepted,
    this.note,
    this.score,
    this.fromAvgRating,
    this.fromRatingCount,
    this.price,
    this.currency,
    this.fromCar,
    this.fromContact,
    this.fromPayment,
  });

  final InboxKind kind;
  final String fromId;
  final String toId;
  final String? fromName;
  final String? rideId;
  final double? lat;
  final double? lng;
  final double? destLat;
  final double? destLng;
  final bool? accepted;
  final String? note;
  final int? score;
  final double? fromAvgRating;
  final int? fromRatingCount;
  final double? price;
  final String? currency;
  final CarInfo? fromCar;
  final ContactInfo? fromContact;
  final PaymentInfo? fromPayment;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'fromId': fromId,
    'toId': toId,
    'fromName': fromName,
    'rideId': rideId,
    'lat': lat,
    'lng': lng,
    'destLat': destLat,
    'destLng': destLng,
    'accepted': accepted,
    'note': note,
    'score': score,
    'fromAvgRating': fromAvgRating,
    'fromRatingCount': fromRatingCount,
    'price': price,
    'currency': currency,
    'fromCar': fromCar?.toJson(),
    'fromContact': fromContact?.toJson(),
    'fromPayment': fromPayment?.toJson(),
  };

  String encode() => jsonEncode(toJson());

  static InboxMessage? tryDecode(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final kindName = m['kind'] as String?;
      final kind = InboxKind.values.firstWhere(
        (k) => k.name == kindName,
        orElse: () => InboxKind.locationUpdate,
      );
      return InboxMessage(
        kind: kind,
        fromId: m['fromId'] as String,
        toId: m['toId'] as String,
        fromName: m['fromName'] as String?,
        rideId: m['rideId'] as String?,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        destLat: (m['destLat'] as num?)?.toDouble(),
        destLng: (m['destLng'] as num?)?.toDouble(),
        accepted: m['accepted'] as bool?,
        note: m['note'] as String?,
        score: (m['score'] as num?)?.toInt(),
        fromAvgRating: (m['fromAvgRating'] as num?)?.toDouble(),
        fromRatingCount: (m['fromRatingCount'] as num?)?.toInt(),
        price: (m['price'] as num?)?.toDouble(),
        currency: m['currency'] as String?,
        fromCar: CarInfo.tryFromJson(m['fromCar'] as Map<String, dynamic>?),
        fromContact: ContactInfo.tryFromJson(
            m['fromContact'] as Map<String, dynamic>?),
        fromPayment: PaymentInfo.tryFromJson(
            m['fromPayment'] as Map<String, dynamic>?),
      );
    } catch (_) {
      return null;
    }
  }
}
