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
          email: fbUser.email ?? fbUser.phoneNumber ?? '',
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
  Future<void> startPhoneSignIn(
    String e164PhoneNumber, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onFailed,
    required void Function() onAutoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: e164PhoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Android auto-retrieved the SMS — no code entry needed.
        await _auth.signInWithCredential(credential);
        await _ensureStudentProfile();
        onAutoVerified();
      },
      verificationFailed: (e) => onFailed(switch (e.code) {
        'invalid-phone-number' => 'That phone number looks invalid.',
        'too-many-requests' =>
          'Too many attempts from this device. Try again later.',
        _ => 'Could not send the code (${e.code}). Try again.',
      }),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  @override
  Future<void> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = fb.PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _auth.signInWithCredential(credential);
    await _ensureStudentProfile();
  }

  /// Phone sign-ins have no signup step, so create the student profile doc
  /// on first sign-in (rules allow self-creation with role == student only).
  Future<void> _ensureStudentProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _db.collection('users').doc(user.uid);
    final snapshot = await ref.get();
    if (snapshot.exists) return;
    await ref.set(<String, dynamic>{
      'email': user.email ?? '',
      'phone': user.phoneNumber,
      'role': 'student',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
