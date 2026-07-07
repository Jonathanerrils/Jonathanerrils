import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/bus_stop.dart';
import '../../domain/entities/stop_daily_stats.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../../domain/repositories/stop_repository.dart';
import '../auth/auth_controller.dart';
import 'hourly_bar_chart.dart';

/// In-app admin: manage stops + demand analytics (peak hours per stop,
/// daily patterns). Driver-account creation stays in the Firebase console —
/// see README "Provisioning drivers".
class AdminHomeScreen extends StatelessWidget {
  final AppUser admin;

  const AdminHomeScreen({super.key, required this.admin});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => context.read<AuthController>().signOut(),
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.edit_location_alt), text: 'Stops'),
            Tab(icon: Icon(Icons.insights), text: 'Analytics'),
          ]),
        ),
        body: const TabBarView(children: [_StopsTab(), _AnalyticsTab()]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stops tab — add / edit / deactivate
// ---------------------------------------------------------------------------

class _StopsTab extends StatelessWidget {
  const _StopsTab();

  @override
  Widget build(BuildContext context) {
    final stopsRepo = context.read<StopRepository>();
    return Scaffold(
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
            padding: const EdgeInsets.only(bottom: 88),
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

// ---------------------------------------------------------------------------
// Analytics tab — daily demand per stop, peak hours
// ---------------------------------------------------------------------------

class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab();

  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  DateTime _date = DateTime.now();
  late Future<List<StopDailyStats>> _stats;

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _stats = context.read<AnalyticsRepository>().statsForDate(_date);
  }

  void _shiftDay(int days) {
    setState(() {
      _date = _date.add(Duration(days: days));
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stopsRepo = context.read<StopRepository>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous day',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shiftDay(-1),
              ),
              Expanded(
                child: Text(
                  _isToday
                      ? 'Today'
                      : DateFormat('EEE d MMM yyyy').format(_date),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Next day',
                icon: const Icon(Icons.chevron_right),
                onPressed: _isToday ? null : () => _shiftDay(1),
              ),
            ],
          ),
        ),
        Expanded(
          // Stop names come from the live stops stream; stats are a one-shot
          // read per selected day.
          child: StreamBuilder<List<BusStop>>(
            stream: stopsRepo.watchStops(),
            builder: (context, stopsSnap) {
              final names = <String, String>{
                for (final s in stopsSnap.data ?? const <BusStop>[])
                  s.id: s.name,
              };
              return FutureBuilder<List<StopDailyStats>>(
                future: _stats,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Could not load analytics.\n'
                            '${snapshot.error}'));
                  }
                  final stats = [...(snapshot.data ?? const [])]
                    ..sort((a, b) => b.total.compareTo(a.total));
                  if (stats.isEmpty) {
                    return const Center(
                        child: Text('No check-ins recorded on this day.'));
                  }
                  final dayTotal =
                      stats.fold<int>(0, (sum, s) => sum + s.total);
                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Text(
                        '$dayTotal check-ins across ${stats.length} stops',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final stat in stats)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        names[stat.stopId] ?? stat.stopId,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Text('${stat.total} check-ins'),
                                  ],
                                ),
                                if (stat.peakHour != null)
                                  Text(
                                    'Peak: '
                                    '${HourlyBarChart.hourLabel(stat.peakHour!)}'
                                    '–'
                                    '${HourlyBarChart.hourLabel((stat.peakHour! + 1) % 24)}'
                                    ' (${stat.peakCount})',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                const SizedBox(height: 8),
                                HourlyBarChart(hourly: stat.hourly),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
