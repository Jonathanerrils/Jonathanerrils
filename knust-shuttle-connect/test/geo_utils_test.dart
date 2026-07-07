import 'package:flutter_test/flutter_test.dart';
import 'package:knust_shuttle_connect/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils.distanceMeters', () {
    test('zero distance for identical points', () {
      expect(GeoUtils.distanceMeters(6.6745, -1.5716, 6.6745, -1.5716), 0);
    });

    test('roughly 111 km per degree of latitude', () {
      final d = GeoUtils.distanceMeters(6.0, -1.5716, 7.0, -1.5716);
      expect(d, closeTo(111000, 500));
    });

    test('short campus-scale distances are sane', () {
      // ~100 m apart near KNUST campus latitude.
      final d = GeoUtils.distanceMeters(6.6745, -1.5716, 6.6754, -1.5716);
      expect(d, closeTo(100, 5));
    });
  });

  group('GeoUtils.isWithinRadius (geofence check)', () {
    test('inside a 75 m geofence passes', () {
      expect(
        GeoUtils.isWithinRadius(
          lat: 6.67455,
          lon: -1.57160,
          centerLat: 6.6745,
          centerLon: -1.5716,
          radiusMeters: 75,
        ),
        isTrue,
      );
    });

    test('outside a 75 m geofence fails', () {
      expect(
        GeoUtils.isWithinRadius(
          lat: 6.6760, // ~166 m north
          lon: -1.5716,
          centerLat: 6.6745,
          centerLon: -1.5716,
          radiusMeters: 75,
        ),
        isFalse,
      );
    });
  });
}
