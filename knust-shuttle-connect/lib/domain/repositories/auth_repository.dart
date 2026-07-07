import '../entities/app_user.dart';

abstract class AuthRepository {
  /// Emits the signed-in user's profile (including role) or null.
  Stream<AppUser?> watchUser();

  Future<void> signInWithEmail(String email, String password);

  /// Self-signup is student-only; drivers are provisioned by an admin.
  Future<void> registerStudent(String email, String password);

  /// Phone-OTP fallback (students without access to their KNUST email).
  /// Sends the SMS; exactly one of the callbacks fires afterwards.
  /// [onAutoVerified] covers Android's automatic SMS retrieval, where
  /// sign-in completes without the user typing the code.
  Future<void> startPhoneSignIn(
    String e164PhoneNumber, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onFailed,
    required void Function() onAutoVerified,
  });

  Future<void> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  });

  Future<void> signOut();
}
