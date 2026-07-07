enum UserRole { student, driver, admin }

UserRole userRoleFromString(String? value) => switch (value) {
      'driver' => UserRole.driver,
      'admin' => UserRole.admin,
      _ => UserRole.student,
    };

class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final UserRole role;

  const AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.displayName,
  });
}
