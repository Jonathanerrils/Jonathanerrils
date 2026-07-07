class BusStop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double geofenceRadiusMeters;
  final int waitingCount;
  final bool active;

  /// UID of the driver currently heading to this stop, if any.
  final String? enRouteBy;
  final DateTime? enRouteAt;
  final DateTime? arrivedAt;

  const BusStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.geofenceRadiusMeters,
    this.waitingCount = 0,
    this.active = true,
    this.enRouteBy,
    this.enRouteAt,
    this.arrivedAt,
  });

  bool get hasShuttleEnRoute => enRouteBy != null && arrivedAt == null;
}
