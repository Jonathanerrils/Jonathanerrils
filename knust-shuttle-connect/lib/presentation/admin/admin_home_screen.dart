import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/bus_stop.dart';
import '../../domain/repositories/stop_repository.dart';
import '../auth/auth_controller.dart';

/// Minimal in-app admin: add/edit/deactivate stops. Driver-account creation
/// and analytics live in the Firebase console / Phase 3 web dashboard —
/// see README "Provisioning drivers".
class AdminHomeScreen extends StatelessWidget {
  final AppUser admin;

  const AdminHomeScreen({super.key, required this.admin});

  @override
  Widget build(BuildContext context) {
    final stopsRepo = context.read<StopRepository>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage stops'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthController>().signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editStop(context, stopsRepo, null),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add stop'),
      ),
      body: StreamBuilder<List<BusStop>>(
        stream: stopsRepo.watchStops(),
        builder: (context, snapshot) {
          final stops = [...(snapshot.data ?? const <BusStop>[])]
            ..sort((a, b) => a.name.compareTo(b.name));
          if (stops.isEmpty) {
            return const Center(
              child: Text('No stops yet. Add the campus stops, or run the '
                  'seed script (see README).'),
            );
          }
          return ListView.builder(
            itemCount: stops.length,
            itemBuilder: (ctx, i) {
              final stop = stops[i];
              return ListTile(
                leading: const Icon(Icons.place),
                title: Text(stop.name),
                subtitle: Text(
                  '${stop.latitude.toStringAsFixed(5)}, '
                  '${stop.longitude.toStringAsFixed(5)} · '
                  'geofence ${stop.geofenceRadiusMeters.round()} m · '
                  '${stop.waitingCount} waiting',
                ),
                trailing: IconButton(
                  tooltip: 'Deactivate',
                  icon: const Icon(Icons.visibility_off_outlined),
                  onPressed: () => stopsRepo.deactivateStop(stop.id),
                ),
                onTap: () => _editStop(context, stopsRepo, stop),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editStop(
      BuildContext context, StopRepository repo, BusStop? existing) async {
    final name = TextEditingController(text: existing?.name);
    final lat = TextEditingController(text: existing?.latitude.toString());
    final lng = TextEditingController(text: existing?.longitude.toString());
    final radius = TextEditingController(
        text: (existing?.geofenceRadiusMeters ??
                AppConstants.defaultGeofenceRadiusMeters)
            .toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add stop' : 'Edit ${existing.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: lat,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Latitude')),
            TextField(
                controller: lng,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Longitude')),
            TextField(
                controller: radius,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Geofence radius (metres)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );

    if (saved != true) return;
    final latitude = double.tryParse(lat.text.trim());
    final longitude = double.tryParse(lng.text.trim());
    final radiusMeters = double.tryParse(radius.text.trim());
    if (name.text.trim().isEmpty || latitude == null || longitude == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Name, latitude and longitude are required.')));
      }
      return;
    }
    final id = existing?.id ??
        name.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    await repo.upsertStop(BusStop(
      id: id,
      name: name.text.trim(),
      latitude: latitude,
      longitude: longitude,
      geofenceRadiusMeters:
          radiusMeters ?? AppConstants.defaultGeofenceRadiusMeters,
    ));
  }
}
