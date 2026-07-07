import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/utils/geo_utils.dart';
import '../../domain/entities/bus_stop.dart';

/// List of all campus stops, nearest first when a position is known.
/// GPS verification still applies — picking a far-away stop will be
/// rejected by the check-in use case.
Future<BusStop?> showStopPicker(
  BuildContext context, {
  required List<BusStop> stops,
  Position? position,
}) {
  final sorted = [...stops];
  if (position != null) {
    sorted.sort((a, b) {
      double d(BusStop s) => GeoUtils.distanceMeters(
          position.latitude, position.longitude, s.latitude, s.longitude);
      return d(a).compareTo(d(b));
    });
  } else {
    sorted.sort((a, b) => a.name.compareTo(b.name));
  }

  return showModalBottomSheet<BusStop>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView.builder(
        itemCount: sorted.length,
        itemBuilder: (ctx, i) {
          final stop = sorted[i];
          final distance = position == null
              ? null
              : GeoUtils.distanceMeters(position.latitude, position.longitude,
                  stop.latitude, stop.longitude);
          return ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(stop.name),
            subtitle: Text(
              distance == null
                  ? '${stop.waitingCount} waiting'
                  : '${stop.waitingCount} waiting · ${_formatDistance(distance)}',
            ),
            onTap: () => Navigator.of(ctx).pop(stop),
          );
        },
      ),
    ),
  );
}

String _formatDistance(double meters) => meters < 950
    ? '${meters.round()} m away'
    : '${(meters / 1000).toStringAsFixed(1)} km away';
