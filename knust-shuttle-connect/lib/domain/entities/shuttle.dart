import '../../core/utils/geo_utils.dart';

/// Live position of an on-duty shuttle (driver opted in to sharing).
/// Students only ever see "a shuttle" — never which driver it is.
class Shuttle {
  final String id;
  final double latitude;
  final double longitude;
  final double? headingDegrees;
  final double? speedMetersPerSecond;
  final DateTime? updatedAt;

  const Shuttle({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.headingDegrees,
    this.speedMetersPerSecond,
    this.updatedAt,
  });

  /// Position updates stop when the driver goes off duty; hide anything
  /// that hasn't moved/reported recently instead of showing a ghost bus.
  bool get isFresh =>
      updatedAt != null &&
      DateTime.now().difference(updatedAt!) < const Duration(minutes: 5);

  /// Rough straight-line ETA in minutes. Falls back to ~20 km/h when the
  /// shuttle is stationary or speed is unreliable — this is a "roughly how
  /// soon" hint for students, not turn-by-turn navigation.
  double etaMinutesTo(double lat, double lng) {
    final meters = GeoUtils.distanceMeters(latitude, longitude, lat, lng);
    final mps = (speedMetersPerSecond != null && speedMetersPerSecond! > 2)
        ? speedMetersPerSecond!
        : 5.5;
    return meters / mps / 60;
  }
}
