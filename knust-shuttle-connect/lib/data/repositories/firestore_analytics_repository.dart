import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/stop_daily_stats.dart';
import '../../domain/repositories/analytics_repository.dart';

class FirestoreAnalyticsRepository implements AnalyticsRepository {
  final FirebaseFirestore _db;

  FirestoreAnalyticsRepository(this._db);

  static String dateKey(DateTime date) {
    final utc = date.toUtc();
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$month-$day';
  }

  @override
  Future<List<StopDailyStats>> statsForDate(DateTime date) async {
    final snap = await _db
        .collection('analytics_daily')
        .where('date', isEqualTo: dateKey(date))
        .get();
    return snap.docs.map((doc) {
      final data = doc.data();
      final hourlyMap =
          (data['hourly'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      final hourly = List<int>.generate(
          24, (h) => (hourlyMap['h$h'] as num?)?.toInt() ?? 0);
      return StopDailyStats(
        stopId: (data['stopId'] as String?) ?? doc.id,
        date: (data['date'] as String?) ?? '',
        total: (data['total'] as num?)?.toInt() ?? 0,
        hourly: hourly,
      );
    }).toList();
  }
}
