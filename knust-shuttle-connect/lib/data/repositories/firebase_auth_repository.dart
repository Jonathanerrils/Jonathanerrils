import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../core/constants/app_constants.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;

  FirebaseAuthRepository(this._auth, this._db);

  @override
  Stream<AppUser?> watchUser() {
    return _auth.authStateChanges().asyncExpand((fbUser) {
      if (fbUser == null) return Stream<AppUser?>.value(null);
      return _db.collection('users').doc(fbUser.uid).snapshots().map((doc) {
        final data = doc.data();
        return AppUser(
          uid: fbUser.uid,
          email: fbUser.email ?? '',
          displayName: data?['displayName'] as String?,
          // Missing profile doc (e.g. first snapshot right after signup)
          // defaults to student; drivers/admins always have a doc.
          role: userRoleFromString(data?['role'] as String?),
        );
      });
    });
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> registerStudent(String email, String password) async {
    final domain = email.split('@').last.toLowerCase();
    if (!AppConstants.allowedStudentDomains.contains(domain)) {
      throw ArgumentError(
        'Please use your KNUST student email '
        '(${AppConstants.allowedStudentDomains.map((d) => '@$d').join(' or ')}).',
      );
    }
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Security rules only allow self-created profiles with role == student.
    await _db.collection('users').doc(cred.user!.uid).set(<String, dynamic>{
      'email': email,
      'role': 'student',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await cred.user!.sendEmailVerification();
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
