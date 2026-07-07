import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/check_in.dart';

/// Firestore <-> entity mapping for `checkins/{studentUid}`.
class CheckInModel {
  CheckInModel._();

  static CheckIn? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    return CheckIn(
      studentUid: doc.id,
      stopId: data['stopId'] as String,
      stopName: (data['stopName'] as String?) ?? '',
      // serverTimestamp is briefly null in latency-compensated local
      // snapshots — fall back to "now" so the UI never crashes offline.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
