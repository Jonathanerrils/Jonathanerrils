import '../../core/utils/result.dart';
import '../repositories/check_in_repository.dart';

/// Removes the student's active check-in — used by the "Board / Cancel"
/// button and by geofence-exit removal.
class CancelCheckIn {
  final CheckInRepository _checkIns;

  const CancelCheckIn(this._checkIns);

  Future<Result<void>> call(String uid) async {
    try {
      await _checkIns.cancel(uid);
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Could not update your check-in. ($e)');
    }
  }
}
