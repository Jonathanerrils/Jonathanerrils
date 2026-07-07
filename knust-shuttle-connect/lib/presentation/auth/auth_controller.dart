import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/foundation.dart';

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
