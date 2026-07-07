import '../entities/shuttle.dart';

abstract class ShuttleRepository {
  /// Live positions of on-duty shuttles (already filtered to fresh ones).
  Stream<List<Shuttle>> watchOnDutyShuttles();
}
