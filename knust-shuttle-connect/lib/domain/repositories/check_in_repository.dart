import '../entities/bus_stop.dart';
import '../entities/check_in.dart';

abstract class CheckInRepository {
  /// The student's single active check-in (doc id == uid), or null.
  Stream<CheckIn?> watchMyCheckIn(String uid);

  /// Creates or replaces the student's check-in. Replacing the document when
  /// the student checks in elsewhere is what removes the previous check-in.
  Future<void> checkIn({required String uid, required BusStop stop});

  Future<void> cancel(String uid);
}
