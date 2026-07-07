import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/entities/app_user.dart';
import 'admin/admin_home_screen.dart';
import 'auth/auth_controller.dart';
import 'auth/login_screen.dart';
import 'driver/driver_dashboard_screen.dart';
import 'student/student_home_screen.dart';

/// Routes to the right experience for the signed-in role.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.initialising) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = auth.user;
    if (user == null) return const LoginScreen();
    return switch (user.role) {
      UserRole.driver => DriverDashboardScreen(driver: user),
      UserRole.admin => AdminHomeScreen(admin: user),
      UserRole.student => StudentHomeScreen(student: user),
    };
  }
}
