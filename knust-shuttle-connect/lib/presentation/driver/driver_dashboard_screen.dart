import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/bus_stop.dart';
import '../../domain/repositories/stop_repository.dart';
import '../auth/auth_controller.dart';
import 'driver_controller.dart';
import 'driver_map_screen.dart';

/// Glanceable list of stops sorted by waiting students, highest first.
/// Large touch targets; meant to be read while STOPPED, never while driving.
class DriverDashboardScreen extends StatelessWidget {
  final AppUser driver;

  const DriverDashboardScreen({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => DriverController(
        driver: driver,
        stopRepository: ctx.read<StopRepository>(),
      ),
      child: const _DriverDashboardView(),
    );
  }
}

class _DriverDashboardView extends StatefulWidget {
  const _DriverDashboardView();

  @override
  State<_DriverDashboardView> createState() => _DriverDashboardViewState();
}

class _DriverDashboardViewState extends State<_DriverDashboardView> {
  static const _safetyNoticeKey = 'driver_safety_notice_shown';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowSafetyNotice());
  }

  Future<void> _maybeShowSafetyNotice() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_safetyNoticeKey) ?? false) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber, size: 40),
        title: const Text('Safety first'),
        content: const Text(
          'Only check this app while your shuttle is safely stopped. '
          'Never look at the screen while driving.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('I understand'),
          ),
        ],
      ),
    );
    await prefs.setBool(_safetyNoticeKey, true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DriverController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting students'),
        actions: [
          IconButton(
            tooltip: 'Demand map',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              // Re-share this screen's controller with the pushed route.
              builder: (_) => ChangeNotifierProvider.value(
                value: controller,
                child: const DriverMapScreen(),
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
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Share my live location'),
            subtitle: const Text('Only while on duty — students see the shuttle, not you'),
            secondary: const Icon(Icons.share_location),
            value: controller.sharingLocation,
            onChanged: (v) => controller.setSharingLocation(v),
          ),
          const Divider(height: 1),
          Expanded(
            child: controller.stops.isEmpty
                ? const Center(child: Text('No stops yet — ask an admin to add them.'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: controller.stops.length,
                    itemBuilder: (ctx, i) =>
                        _StopTile(stop: controller.stops[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  final BusStop stop;

  const _StopTile({required this.stop});

  Color get _demandColor => AppColors.demandColor(stop.waitingCount);

  @override
  Widget build(BuildContext context) {
    final controller = context.read<DriverController>();
    final mine = controller.isMine(stop);
    final servedByOther = stop.enRouteBy != null && !mine;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Big count badge — readable at a glance.
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _demandColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${stop.waitingCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (servedByOther)
                    const Text('Another shuttle is en route',
                        style: TextStyle(fontStyle: FontStyle.italic)),
                  if (mine && stop.arrivedAt == null)
                    const Text('You are en route',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  if (mine && stop.arrivedAt != null)
                    const Text('Arrived — students asked "Did you board?"',
                        style: TextStyle(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ActionButton(stop: stop, mine: mine, servedByOther: servedByOther),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final BusStop stop;
  final bool mine;
  final bool servedByOther;

  const _ActionButton(
      {required this.stop, required this.mine, required this.servedByOther});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<DriverController>();
    if (mine && stop.arrivedAt == null) {
      return FilledButton(
        style: FilledButton.styleFrom(
            minimumSize: const Size(110, 56),
            backgroundColor: AppColors.knustGreen),
        onPressed: () => controller.markArrived(stop),
        child: const Text('Arrived'),
      );
    }
    if (mine && stop.arrivedAt != null) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(110, 56)),
        onPressed: () => controller.clearEnRoute(stop),
        child: const Text('Done'),
      );
    }
    return FilledButton(
      style: FilledButton.styleFrom(minimumSize: const Size(110, 56)),
      // Allowed even if another shuttle is en route (two shuttles can serve
      // a very busy stop) — the tile just tells the driver it's covered.
      onPressed: () => controller.markEnRoute(stop),
      child: Text(servedByOther ? 'Also go' : 'En route'),
    );
  }
}
