import 'dart:convert';

class RatingRecord {
  RatingRecord({
    required this.fromId,
    required this.score,
    required this.when,
    this.fromName,
    this.comment,
    this.rideId,
  });

  final String fromId;
  final String? fromName;
  final int score;
  final String? comment;
  final DateTime when;
  final String? rideId;

  Map<String, dynamic> toJson() => {
        'fromId': fromId,
        'fromName': fromName,
        'score': score,
        'comment': comment,
        'when': when.toIso8601String(),
        'rideId': rideId,
      };

  static RatingRecord? tryFromJson(Map<String, dynamic> m) {
    try {
      return RatingRecord(
        fromId: m['fromId'] as String,
        fromName: m['fromName'] as String?,
        score: (m['score'] as num).toInt(),
        comment: m['comment'] as String?,
        when: DateTime.tryParse(m['when'] as String? ?? '') ?? DateTime.now(),
        rideId: m['rideId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

class RatingSummary {
  const RatingSummary({required this.average, required this.count});
  final double average;
  final int count;

  static const empty = RatingSummary(average: 0, count: 0);

  String? formatted() {
    if (count == 0) return null;
    return '${average.toStringAsFixed(1)} ★ ($count)';
  }
}

String encodeRatings(List<RatingRecord> records) =>
    jsonEncode(records.map((r) => r.toJson()).toList());

List<RatingRecord> decodeRatings(String raw) {
  if (raw.isEmpty) return [];
  final data = jsonDecode(raw);
  if (data is! List) return [];
  return data
      .whereType<Map<String, dynamic>>()
      .map(RatingRecord.tryFromJson)
      .whereType<RatingRecord>()
      .toList();
}
