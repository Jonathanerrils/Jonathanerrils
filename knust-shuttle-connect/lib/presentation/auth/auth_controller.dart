import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/foundation.dart';

import '../../core/utils/phone_utils.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository _auth;
  StreamSubscription<AppUser?>? _sub;

  AppUser? user;
  bool initialising = true;
  bool busy = false;
  String? error;

  AuthController(this._auth) {
    _sub = _auth.watchUser().listen((u) {
      user = u;
      initialising = false;
      notifyListeners();
    });
  }

  Future<void> signIn(String email, String password) =>
      _run(() => _auth.signInWithEmail(email.trim(), password));

  Future<void> register(String email, String password) =>
      _run(() => _auth.registerStudent(email.trim(), password));

  Future<void> signOut() => _run(_auth.signOut);

  // --- Phone-OTP fallback -------------------------------------------------

  /// Non-null while we're waiting for the user to type the SMS code.
  String? pendingVerificationId;
  String? pendingPhoneNumber;

  bool get awaitingSmsCode => pendingVerificationId != null;

  Future<void> startPhoneSignIn(String rawPhone) async {
    final phone = normalizeGhanaPhone(rawPhone);
    if (phone == null) {
      error = 'Enter a valid Ghana phone number, e.g. 055 123 4567.';
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      // busy stays true until one of the callbacks fires — the SMS send
      // itself is asynchronous on Firebase's side.
      await _auth.startPhoneSignIn(
        phone,
        onCodeSent: (verificationId) {
          pendingVerificationId = verificationId;
          pendingPhoneNumber = phone;
          busy = false;
          notifyListeners();
        },
        onFailed: (message) {
          error = message;
          busy = false;
          notifyListeners();
        },
        onAutoVerified: () {
          // Signed in without typing a code; RootGate reroutes via the
          // auth stream.
          pendingVerificationId = null;
          busy = false;
          notifyListeners();
        },
      );
    } catch (_) {
      error = 'Could not send the code. Check your connection and try again.';
      busy = false;
      notifyListeners();
    }
  }

  Future<void> confirmSmsCode(String smsCode) async {
    final verificationId = pendingVerificationId;
    if (verificationId == null) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _auth.confirmSmsCode(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      pendingVerificationId = null;
      pendingPhoneNumber = null;
    } on FirebaseAuthException catch (e) {
      error = switch (e.code) {
        'invalid-verification-code' =>
          'That code is incorrect. Check the SMS and try again.',
        'session-expired' =>
          'The code expired. Request a new one.',
        _ => 'Verification failed (${e.code}).',
      };
    } catch (_) {
      error = 'Something went wrong. Try again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Back out of the OTP entry step (wrong number, no SMS arrived, …).
  void cancelPhoneSignIn() {
    pendingVerificationId = null;
    pendingPhoneNumber = null;
    error = null;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      error = _friendly(e);
    } on ArgumentError catch (e) {
      error = e.message as String?;
    } catch (e) {
      error = 'Something went wrong. Check your connection and try again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String _friendly(FirebaseAuthException e) => switch (e.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          'Email or password is incorrect.',
        'email-already-in-use' => 'An account already exists for that email.',
        'weak-password' => 'Password must be at least 6 characters.',
        'network-request-failed' =>
          'No connection. Check your data and try again.',
        _ => 'Sign-in failed (${e.code}).',
      };

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
