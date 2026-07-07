import '../../core/constants/app_constants.dart';
import '../../core/utils/geo_utils.dart';
import '../../core/utils/result.dart';
import '../entities/bus_stop.dart';
import '../repositories/check_in_repository.dart';

/// Validates and performs a student check-in. Enforces client-side:
///  - rate limiting (one check-in action per [AppConstants.checkInCooldown])
///  - GPS verification (device must be inside the stop's geofence)
/// The server (rules + Cloud Functions) re-enforces rate limiting, single
/// active check-in and expiry, so a modified client cannot corrupt counts.
class CheckInAtStop {
  final CheckInRepository _checkIns;

  const CheckInAtStop(this._checkIns);

  Future<Result<void>> call({
    required String uid,
    required BusStop stop,
    required double latitude,
    required double longitude,
    DateTime? lastActionAt,
  }) async {
    if (lastActionAt != null &&
        DateTime.now().difference(lastActionAt) < AppConstants.checkInCooldown) {
      final wait = AppConstants.checkInCooldown -
          DateTime.now().difference(lastActionAt);
      return Result.failure(
        'Please wait ${wait.inSeconds + 1}s before checking in again.',
      );
    }

    final distance = GeoUtils.distanceMeters(
      latitude,
      longitude,
      stop.latitude,
      stop.longitude,
    );
    if (distance > stop.geofenceRadiusMeters) {
      return Result.failure(
        'You must be at ${stop.name} to check in '
        '(you are ~${distance.round()} m away).',
      );
    }

    try {
      await _checkIns.checkIn(uid: uid, stop: stop);
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Could not check in. Please try again. ($e)');
    }
  }
}
