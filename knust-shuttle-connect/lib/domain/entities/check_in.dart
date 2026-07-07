class CheckIn {
  /// One active check-in per student is enforced structurally: the Firestore
  /// document id IS the student uid, so a second check-in overwrites the first.
  final String studentUid;
  final String stopId;
  final String stopName;
  final DateTime createdAt;
  final DateTime expiresAt;

  const CheckIn({
    required this.studentUid,
    required this.stopId,
    required this.stopName,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
