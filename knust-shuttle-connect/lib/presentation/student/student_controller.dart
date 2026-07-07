import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/geo_utils.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/bus_stop.dart';
import '../../domain/entities/check_in.dart';
import '../../domain/repositories/check_in_repository.dart';
import '../../domain/repositories/stop_repository.dart';
import '../../domain/usecases/cancel_check_in.dart';
import '../../domain/usecases/check_in_at_stop.dart';

/// Drives the student home screen:
///  - loads stops (cache-first, then live Firestore)
///  - finds the nearest stop from a single GPS fix (no continuous polling)
///  - performs check-in / board / cancel with all accuracy rules
///  - watches for geofence exit ONLY while a check-in is active
class StudentController extends ChangeNotifier {
  static const _lastActionKey = 'last_checkin_action_at';

  final AppUser student;
  final StopRepository _stops;
  final CheckInRepository _checkIns;
  final CheckInAtStop _checkInAtStop;
  final CancelCheckIn _cancelCheckIn;

  StreamSubscription<List<BusStop>>? _stopsSub;
  StreamSubscription<CheckIn?>? _checkInSub;
  StreamSubscription<Position>? _exitWatchSub;

  List<BusStop> stops = const [];
  bool stopsFromCacheOnly = true;
  DateTime? stopsUpdatedAt;
  Position? position;
  CheckIn? myCheckIn;
  String? locationError;
  bool workingOnCheckIn = false;

  StudentController({
    required this.student,
    required StopRepository stopRepository,
    required CheckInRepository checkInRepository,
  })  : _stops = stopRepository,
        _checkIns = checkInRepository,
        _checkInAtStop = CheckInAtStop(checkInRepository),
        _cancelCheckIn = CancelCheckIn(checkInRepository) {
    _init();
  }

  BusStop? get nearestStop {
    final pos = position;
    if (pos == null || stops.isEmpty) return null;
    BusStop? best;
    double bestDistance = double.infinity;
    for (final stop in stops) {
      final d = GeoUtils.distanceMeters(
          pos.latitude, pos.longitude, stop.latitude, stop.longitude);
      if (d < bestDistance) {
        bestDistance = d;
        best = stop;
      }
    }
    return best;
  }

  /// Live view of the stop the student is checked in at (for the count).
  BusStop? get checkedInStop {
    final c = myCheckIn;
    if (c == null) return null;
    for (final stop in stops) {
      if (stop.id == c.stopId) return stop;
    }
    return null;
  }

  Future<void> _init() async {
    // 1. Cached stops render instantly with zero data use.
    stops = await _stops.getCachedStops();
    stopsUpdatedAt = await _stops.lastCacheTime();
    notifyListeners();

    // 2. Live stops (Firestore keeps emitting cached snapshots offline).
    _stopsSub = _stops.watchStops().listen((live) {
      stops = live;
      stopsFromCacheOnly = false;
      stopsUpdatedAt = DateTime.now();
      notifyListeners();
      unawaited(_stops.cacheStops(live));
    });

    // 3. My active check-in.
    _checkInSub = _checkIns.watchMyCheckIn(student.uid).listen((checkIn) {
      final hadCheckIn = myCheckIn != null;
      myCheckIn = checkIn;
      notifyListeners();
      if (checkIn != null) {
        _startGeofenceExitWatch(checkIn);
      } else if (hadCheckIn) {
        _stopGeofenceExitWatch();
      }
    });

    // 4. One GPS fix for "nearest stop". Notification permission is asked
    //    here too so the whole flow stays inside the 5-second budget.
    unawaited(refreshLocation());
    unawaited(FirebaseMessaging.instance.requestPermission());
  }

  Future<void> refreshLocation() async {
    locationError = null;
    notifyListeners();
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        locationError =
            'Location permission is needed to verify you are at a stop. '
            'You can still browse stops.';
        notifyListeners();
        return;
      }
      position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (_) {
      locationError = 'Could not get your location. Turn on GPS and retry.';
    }
    notifyListeners();
  }

  /// Returns an error message, or null on success.
  Future<String?> checkInAt(BusStop stop) async {
    final pos = position;
    if (pos == null) {
      await refreshLocation();
      if (position == null) {
        return locationError ?? 'Waiting for your location — try again.';
      }
    }
    workingOnCheckIn = true;
    notifyListeners();
    try {
      final result = await _checkInAtStop(
        uid: student.uid,
        stop: stop,
        latitude: position!.latitude,
        longitude: position!.longitude,
        lastActionAt: await _lastActionAt(),
      );
      if (result.isFailure) return result.error;
      await _recordAction();
      // Notifications for "shuttle heading to your stop" are per-stop topics.
      unawaited(FirebaseMessaging.instance
          .subscribeToTopic(AppConstants.stopTopic(stop.id)));
      return null;
    } finally {
      workingOnCheckIn = false;
      notifyListeners();
    }
  }

  /// Board or cancel — both simply remove the check-in.
  Future<String?> boardOrCancel() async {
    final current = myCheckIn;
    workingOnCheckIn = true;
    notifyListeners();
    try {
      final result = await _cancelCheckIn(student.uid);
      if (result.isFailure) return result.error;
      if (current != null) {
        unawaited(FirebaseMessaging.instance
            .unsubscribeFromTopic(AppConstants.stopTopic(current.stopId)));
      }
      return null;
    } finally {
      workingOnCheckIn = false;
      notifyListeners();
    }
  }

  /// Rule 4 (geofence exit removal). Runs only while checked in, with a
  /// coarse distance filter — not continuous GPS polling.
  void _startGeofenceExitWatch(CheckIn checkIn) {
    _exitWatchSub?.cancel();
    final stop = stops.where((s) => s.id == checkIn.stopId).firstOrNull;
    if (stop == null) return;
    _exitWatchSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: AppConstants.studentDistanceFilterMeters,
      ),
    ).listen((pos) {
      position = pos;
      notifyListeners();
      final distance = GeoUtils.distanceMeters(
          pos.latitude, pos.longitude, stop.latitude, stop.longitude);
      final exitThreshold =
          stop.geofenceRadiusMeters + AppConstants.geofenceExitBufferMeters;
      if (distance > exitThreshold) {
        unawaited(boardOrCancel());
      }
    });
  }

  void _stopGeofenceExitWatch() {
    _exitWatchSub?.cancel();
    _exitWatchSub = null;
  }

  Future<DateTime?> _lastActionAt() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_lastActionKey);
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> _recordAction() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _lastActionKey, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  void dispose() {
    _stopsSub?.cancel();
    _checkInSub?.cancel();
    _exitWatchSub?.cancel();
    super.dispose();
  }
}
