import '../entities/app_user.dart';

abstract class AuthRepository {
  /// Emits the signed-in user's profile (including role) or null.
  Stream<AppUser?> watchUser();

  Future<void> signInWithEmail(String email, String password);

  /// Self-signup is student-only; drivers are provisioned by an admin.
  Future<void> registerStudent(String email, String password);

  Future<void> signOut();
}
