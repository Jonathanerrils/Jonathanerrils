import '../entities/bus_stop.dart';

abstract class StopRepository {
  /// Live list of active stops. With Firestore offline persistence the stream
  /// keeps emitting cached data when the network drops.
  Stream<List<BusStop>> watchStops();

  /// Stops cached on-device by [cacheStops]; used for instant, data-free
  /// startup before the first Firestore snapshot arrives.
  Future<List<BusStop>> getCachedStops();
  Future<void> cacheStops(List<BusStop> stops);
  Future<DateTime?> lastCacheTime();

  // Driver actions (rules restrict drivers to the en-route fields only).
  Future<void> markEnRoute(String stopId, String driverUid);
  Future<void> markArrived(String stopId, String driverUid);
  Future<void> clearEnRoute(String stopId);

  // Admin actions.
  Future<void> upsertStop(BusStop stop);
  Future<void> deactivateStop(String stopId);
}
