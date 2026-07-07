import 'dart:math' as math;

/// Small pure-Dart geo helpers so the geofence maths is unit-testable
/// without any platform plugin.
class GeoUtils {
  GeoUtils._();

  static const double _earthRadiusMeters = 6371000;

  /// Great-circle (haversine) distance in metres between two coordinates.
  static double distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  static bool isWithinRadius({
    required double lat,
    required double lon,
    required double centerLat,
    required double centerLon,
    required double radiusMeters,
  }) =>
      distanceMeters(lat, lon, centerLat, centerLon) <= radiusMeters;

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}
