import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/bus_stop.dart';

/// Firestore <-> entity mapping for `stops/{stopId}`.
class BusStopModel {
  BusStopModel._();

  static BusStop fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return BusStop(
      id: doc.id,
      name: (data['name'] as String?) ?? doc.id,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      geofenceRadiusMeters: (data['geofenceRadiusMeters'] as num?)?.toDouble() ??
          AppConstants.defaultGeofenceRadiusMeters,
      waitingCount: (data['waitingCount'] as num?)?.toInt() ?? 0,
      active: (data['active'] as bool?) ?? true,
      enRouteBy: data['enRouteBy'] as String?,
      enRouteAt: (data['enRouteAt'] as Timestamp?)?.toDate(),
      arrivedAt: (data['arrivedAt'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic> toMap(BusStop stop) => <String, dynamic>{
        'name': stop.name,
        'latitude': stop.latitude,
        'longitude': stop.longitude,
        'geofenceRadiusMeters': stop.geofenceRadiusMeters,
        'active': stop.active,
        // waitingCount is intentionally omitted: only Cloud Functions
        // maintain it, so admin edits can never clobber a live count.
      };

  /// Local JSON cache (SharedPreferences) — counts are not cached because a
  /// stale count is worse than no count.
  static Map<String, dynamic> toCacheJson(BusStop stop) => <String, dynamic>{
        'id': stop.id,
        'name': stop.name,
        'latitude': stop.latitude,
        'longitude': stop.longitude,
        'geofenceRadiusMeters': stop.geofenceRadiusMeters,
      };

  static BusStop fromCacheJson(Map<String, dynamic> json) => BusStop(
        id: json['id'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        geofenceRadiusMeters: (json['geofenceRadiusMeters'] as num?)
                ?.toDouble() ??
            AppConstants.defaultGeofenceRadiusMeters,
      );
}
