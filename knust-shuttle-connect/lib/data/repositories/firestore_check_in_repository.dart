import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/bus_stop.dart';
import '../../domain/entities/check_in.dart';
import '../../domain/repositories/check_in_repository.dart';
import '../models/check_in_model.dart';

class FirestoreCheckInRepository implements CheckInRepository {
  final FirebaseFirestore _db;

  FirestoreCheckInRepository(this._db);

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('checkins').doc(uid);

  @override
  Stream<CheckIn?> watchMyCheckIn(String uid) => _doc(uid).snapshots().map(
        (doc) {
          final checkIn = CheckInModel.fromDoc(doc);
          // Treat an expired check-in as gone even before the server sweep
          // deletes it, so the student UI never shows a dead check-in.
          if (checkIn == null || checkIn.isExpired) return null;
          return checkIn;
        },
      );

  @override
  Future<void> checkIn({required String uid, required BusStop stop}) {
    // set() (not add) — the doc id is the uid, so checking in at a new stop
    // replaces the old check-in atomically: one active check-in per student.
    return _doc(uid).set(<String, dynamic>{
      'stopId': stop.id,
      'stopName': stop.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(AppConstants.checkInTtl),
      ),
    });
  }

  @override
  Future<void> cancel(String uid) => _doc(uid).delete();
}
