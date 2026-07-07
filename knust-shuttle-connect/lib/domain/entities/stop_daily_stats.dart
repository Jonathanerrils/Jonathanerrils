/// One stop's check-in demand for one day (from `analytics_daily`).
class StopDailyStats {
  final String stopId;

  /// `yyyy-MM-dd` (Ghana is UTC year-round, so this is local time too).
  final String date;
  final int total;

  /// Check-ins per hour of day; always 24 entries (index 0 = midnight).
  final List<int> hourly;

  const StopDailyStats({
    required this.stopId,
    required this.date,
    required this.total,
    required this.hourly,
  });

  /// Hour with the most check-ins, or null on an empty day.
  int? get peakHour {
    if (total == 0) return null;
    var best = 0;
    for (var h = 1; h < hourly.length; h++) {
      if (hourly[h] > hourly[best]) best = h;
    }
    return best;
  }

  int get peakCount => peakHour == null ? 0 : hourly[peakHour!];
}
