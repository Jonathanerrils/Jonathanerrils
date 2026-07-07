import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/bus_stop.dart';
import '../../domain/entities/shuttle.dart';
import '../../domain/repositories/shuttle_repository.dart';
import '../common/map_markers.dart';
import 'student_controller.dart';

/// Simple campus map: numbered demand badges on every stop, live shuttle
/// positions (anonymous), and a rough ETA to the student's stop.
/// Opt-in screen — map tiles cost data, so the home flow stays list-based.
class StudentMapScreen extends StatefulWidget {
  const StudentMapScreen({super.key});

  @override
  State<StudentMapScreen> createState() => _StudentMapScreenState();
}

class _StudentMapScreenState extends State<StudentMapScreen> {
  late final Stream<List<Shuttle>> _shuttles;

  @override
  void initState() {
    super.initState();
    _shuttles = context.read<ShuttleRepository>().watchOnDutyShuttles();
  }

  Future<Set<Marker>> _buildMarkers(
      List<BusStop> stops, List<Shuttle> shuttles) async {
    final markers = <Marker>{};
    for (final stop in stops) {
      markers.add(Marker(
        markerId: MarkerId('stop-${stop.id}'),
        position: LatLng(stop.latitude, stop.longitude),
        icon: await MapMarkers.countBadge(
            stop.waitingCount, AppColors.demandColor(stop.waitingCount)),
        infoWindow: InfoWindow(
          title: stop.name,
          snippet: '${stop.waitingCount} waiting'
              '${stop.hasShuttleEnRoute ? ' · shuttle on the way' : ''}',
        ),
        anchor: const Offset(0.5, 0.5),
      ));
    }
    for (final shuttle in shuttles) {
      markers.add(Marker(
        markerId: MarkerId('shuttle-${shuttle.id}'),
        position: LatLng(shuttle.latitude, shuttle.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Shuttle'),
        rotation: shuttle.headingDegrees ?? 0,
      ));
    }
    return markers;
  }

  /// Best (lowest) ETA from any live shuttle to the stop the student cares
  /// about — their checked-in stop, or the nearest one otherwise.
  String? _etaText(StudentController controller, List<Shuttle> shuttles) {
    final stop = controller.checkedInStop ?? controller.nearestStop;
    if (stop == null || shuttles.isEmpty) return null;
    double best = double.infinity;
    for (final shuttle in shuttles) {
      final eta = shuttle.etaMinutesTo(stop.latitude, stop.longitude);
      if (eta < best) best = eta;
    }
    final minutes = best.ceil();
    return minutes <= 1
        ? 'A shuttle is about a minute from ${stop.name}'
        : 'Nearest shuttle is ~$minutes min from ${stop.name}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StudentController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Campus map')),
      body: StreamBuilder<List<Shuttle>>(
        stream: _shuttles,
        builder: (context, snapshot) {
          final shuttles = snapshot.data ?? const <Shuttle>[];
          final eta = _etaText(controller, shuttles);
          return FutureBuilder<Set<Marker>>(
            future: _buildMarkers(controller.stops, shuttles),
            builder: (context, markerSnapshot) => Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(AppConstants.campusCenterLat,
                        AppConstants.campusCenterLng),
                    zoom: AppConstants.campusDefaultZoom,
                  ),
                  markers: markerSnapshot.data ?? const <Marker>{},
                  myLocationEnabled: controller.locationError == null,
                  myLocationButtonEnabled: true,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                ),
                if (eta != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.directions_bus,
                                color: AppColors.knustRed),
                            const SizedBox(width: 10),
                            Expanded(child: Text(eta)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
