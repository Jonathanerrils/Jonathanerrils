import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/bus_stop.dart';
import '../../domain/repositories/stop_repository.dart';

/// Drives the driver dashboard: live counts sorted by demand, en-route
/// marking, and opt-in on-duty location sharing.
class DriverController extends ChangeNotifier {
  final AppUser driver;
  final StopRepository _stops;
  final FirebaseFirestore _db;

  StreamSubscription<List<BusStop>>? _stopsSub;
  StreamSubscription<Position>? _dutySub;

  List<BusStop> stops = const [];
  bool sharingLocation = false;
  DateTime lastUpdate = DateTime.now();

  DriverController({
    required this.driver,
    required StopRepository stopRepository,
    FirebaseFirestore? db,
  })  : _stops = stopRepository,
        _db = db ?? FirebaseFirestore.instance {
    _stopsSub = _stops.watchStops().listen((live) {
      // Highest demand first — that's the routing decision the driver makes.
      stops = [...live]..sort((a, b) => b.waitingCount.compareTo(a.waitingCount));
      lastUpdate = DateTime.now();
      notifyListeners();
    });
  }

  bool isMine(BusStop stop) => stop.enRouteBy == driver.uid;

  Future<void> markEnRoute(BusStop stop) =>
      _stops.markEnRoute(stop.id, driver.uid);

  Future<void> markArrived(BusStop stop) =>
      _stops.markArrived(stop.id, driver.uid);

  Future<void> clearEnRoute(BusStop stop) => _stops.clearEnRoute(stop.id);

  /// Opt-in continuous tracking, drivers on duty only (students never get
  /// continuous tracking). Writes go to `shuttles/{driverUid}`.
  Future<void> setSharingLocation(bool enabled) async {
    if (enabled == sharingLocation) return;
    if (!enabled) {
      await _dutySub?.cancel();
      _dutySub = null;
      sharingLocation = false;
      notifyListeners();
      await _shuttleDoc.set(<String, dynamic>{
        'onDuty': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    sharingLocation = true;
    notifyListeners();
    _dutySub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: AppConstants.driverDistanceFilterMeters,
      ),
    ).listen((pos) {
      unawaited(_shuttleDoc.set(<String, dynamic>{
        'onDuty': true,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'heading': pos.heading,
        'speed': pos.speed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)));
    });
  }

  DocumentReference<Map<String, dynamic>> get _shuttleDoc =>
      _db.collection('shuttles').doc(driver.uid);

  @override
  void dispose() {
    _stopsSub?.cancel();
    _dutySub?.cancel();
    super.dispose();
  }
}
