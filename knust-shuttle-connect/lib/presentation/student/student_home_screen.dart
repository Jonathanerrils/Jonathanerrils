import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/bus_stop.dart';
import '../../domain/repositories/check_in_repository.dart';
import '../../domain/repositories/stop_repository.dart';
import '../auth/auth_controller.dart';
import '../common/last_updated_banner.dart';
import 'stop_picker_sheet.dart';
import 'student_controller.dart';
import 'student_map_screen.dart';

/// Target flow: open app -> one big button -> done, in under 5 seconds.
class StudentHomeScreen extends StatelessWidget {
  final AppUser student;

  const StudentHomeScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => StudentController(
        student: student,
        stopRepository: ctx.read<StopRepository>(),
        checkInRepository: ctx.read<CheckInRepository>(),
      ),
      child: const _StudentHomeView(),
    );
  }
}

class _StudentHomeView extends StatelessWidget {
  const _StudentHomeView();

  Future<void> _showError(BuildContext context, String? error) async {
    if (error == null || !context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StudentController>();
    final checkIn = controller.myCheckIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KNUST Shuttle Connect'),
        actions: [
          IconButton(
            tooltip: 'Campus map',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              // Re-share this screen's controller with the pushed route.
              builder: (_) => ChangeNotifierProvider.value(
                value: controller,
                child: const StudentMapScreen(),
              ),
            )),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthController>().signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LastUpdatedBanner(
              fromCacheOnly: controller.stopsFromCacheOnly,
              updatedAt: controller.stopsUpdatedAt,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: checkIn == null
                    ? _NotCheckedIn(controller: controller, onError: _showError)
                    : _CheckedIn(controller: controller, onError: _showError),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotCheckedIn extends StatelessWidget {
  final StudentController controller;
  final Future<void> Function(BuildContext, String?) onError;

  const _NotCheckedIn({required this.controller, required this.onError});

  @override
  Widget build(BuildContext context) {
    final nearest = controller.nearestStop;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.locationError != null) ...[
          Text(
            controller.locationError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: controller.refreshLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Retry location'),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          nearest == null ? 'Finding your nearest stop…' : 'Nearest stop',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (nearest != null) ...[
          const SizedBox(height: 4),
          Text(
            nearest.name,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '${nearest.waitingCount} waiting now',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 96,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.knustRed,
              foregroundColor: Colors.white,
              textStyle:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            onPressed: nearest == null || controller.workingOnCheckIn
                ? null
                : () async {
                    final error = await controller.checkInAt(nearest);
                    if (error != null && context.mounted) {
                      await onError(context, error);
                    }
                  },
            icon: controller.workingOnCheckIn
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.front_hand, size: 32),
            label: const Text("I'm Waiting Here"),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: controller.stops.isEmpty
              ? null
              : () async {
                  final stop = await showStopPicker(
                    context,
                    stops: controller.stops,
                    position: controller.position,
                  );
                  if (stop != null && context.mounted) {
                    final error = await controller.checkInAt(stop);
                    if (error != null && context.mounted) {
                      await onError(context, error);
                    }
                  }
                },
          child: const Text('Choose a different stop'),
        ),
      ],
    );
  }
}

class _CheckedIn extends StatelessWidget {
  final StudentController controller;
  final Future<void> Function(BuildContext, String?) onError;

  const _CheckedIn({required this.controller, required this.onError});

  @override
  Widget build(BuildContext context) {
    final checkIn = controller.myCheckIn!;
    final liveStop = controller.checkedInStop;
    final count = liveStop?.waitingCount;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, size: 72, color: AppColors.knustGreen),
        const SizedBox(height: 16),
        Text(
          "You've been counted at\n${checkIn.stopName}",
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (count != null)
          Text(
            '$count waiting here now',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        if (liveStop != null && liveStop.hasShuttleEnRoute) ...[
          const SizedBox(height: 8),
          Chip(
            avatar: const Icon(Icons.directions_bus, size: 18),
            label: const Text('A shuttle is on its way to this stop'),
            backgroundColor:
                AppColors.knustGold.withValues(alpha: 0.25),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Expires ${DateFormat.jm().format(checkIn.expiresAt)} if you '
          'don’t board. Leaving the stop removes you automatically.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 72,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.knustGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: controller.workingOnCheckIn
                ? null
                : () async {
                    final error = await controller.boardOrCancel();
                    if (error != null && context.mounted) {
                      await onError(context, error);
                    }
                  },
            icon: const Icon(Icons.directions_bus_filled),
            label: const Text('I boarded / Cancel'),
          ),
        ),
      ],
    );
  }
}
