/// Central knobs for the count-accuracy logic. Server-side equivalents live
/// in `functions/src/index.ts` and `firestore.rules` — keep them in sync.
class AppConstants {
  AppConstants._();

  /// A check-in expires this long after it is created (server sweep enforces
  /// it too, so a killed app cannot leave a stale count behind).
  static const Duration checkInTtl = Duration(minutes: 25);

  /// Minimum time between check-in actions from one account (rate limiting).
  static const Duration checkInCooldown = Duration(seconds: 60);

  /// Default geofence radius when a stop does not specify one.
  static const double defaultGeofenceRadiusMeters = 75;

  /// Extra slack before geofence-exit removal kicks in, so GPS jitter at the
  /// edge of the radius doesn't bounce students out of the queue.
  static const double geofenceExitBufferMeters = 50;

  /// Movement (metres) before the location stream reports a new position
  /// while a check-in is active — battery-friendly vs continuous polling.
  static const int studentDistanceFilterMeters = 30;

  /// Movement (metres) between location writes for on-duty drivers.
  static const int driverDistanceFilterMeters = 25;

  /// Email domains accepted for student self-signup.
  static const List<String> allowedStudentDomains = <String>[
    'st.knust.edu.gh',
    'knust.edu.gh',
  ];

  /// Driver dashboard colour thresholds.
  static const int busyThreshold = 15; // red at 15+
  static const int moderateThreshold = 5; // amber at 5–14, green below

  /// FCM topic for a stop; students at the stop subscribe to it.
  static String stopTopic(String stopId) => 'stop_$stopId';

  /// Initial map camera: KNUST campus centre.
  static const double campusCenterLat = 6.6745;
  static const double campusCenterLng = -1.5716;
  static const double campusDefaultZoom = 15;
}
