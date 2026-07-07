import '../entities/stop_daily_stats.dart';

abstract class AnalyticsRepository {
  /// Demand stats for every stop on the given day (empty stops omitted).
  Future<List<StopDailyStats>> statsForDate(DateTime date);
}
