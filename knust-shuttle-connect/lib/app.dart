import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/firebase_auth_repository.dart';
import 'data/repositories/firestore_check_in_repository.dart';
import 'data/repositories/firestore_stop_repository.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/check_in_repository.dart';
import 'domain/repositories/stop_repository.dart';
import 'presentation/auth/auth_controller.dart';
import 'presentation/root_gate.dart';

class KnustShuttleApp extends StatelessWidget {
  const KnustShuttleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    // Offline persistence is on by default on Android/iOS; state it
    // explicitly because "works on flaky campus data" is a requirement.
    db.settings = const Settings(persistenceEnabled: true);

    return MultiProvider(
      providers: [
        Provider<AuthRepository>(
          create: (_) => FirebaseAuthRepository(FirebaseAuth.instance, db),
        ),
        Provider<StopRepository>(create: (_) => FirestoreStopRepository(db)),
        Provider<CheckInRepository>(
          create: (_) => FirestoreCheckInRepository(db),
        ),
        ChangeNotifierProvider<AuthController>(
          create: (ctx) => AuthController(ctx.read<AuthRepository>()),
        ),
      ],
      child: MaterialApp(
        title: 'KNUST Shuttle Connect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const RootGate(),
      ),
    );
  }
}
