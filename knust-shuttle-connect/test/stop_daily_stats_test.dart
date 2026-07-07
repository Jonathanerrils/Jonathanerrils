import 'package:flutter_test/flutter_test.dart';
import 'package:knust_shuttle_connect/domain/entities/stop_daily_stats.dart';

void main() {
  List<int> hours(Map<int, int> values) =>
      List<int>.generate(24, (h) => values[h] ?? 0);

  test('peakHour finds the busiest hour', () {
    final stats = StopDailyStats(
      stopId: 'brunei',
      date: '2026-07-07',
      total: 40,
      hourly: hours({7: 12, 8: 20, 17: 8}),
    );
    expect(stats.peakHour, 8);
    expect(stats.peakCount, 20);
  });

  test('empty day has no peak', () {
    final stats = StopDailyStats(
      stopId: 'brunei',
      date: '2026-07-07',
      total: 0,
      hourly: hours({}),
    );
    expect(stats.peakHour, isNull);
    expect(stats.peakCount, 0);
  });
}
