import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Renders the numbered demand badges used as map markers (a coloured
/// circle with the waiting count). Icons are cached by (count, colour) so
/// live count updates don't re-rasterise unchanged badges.
class MapMarkers {
  MapMarkers._();

  static final Map<String, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor> countBadge(int count, Color color) async {
    final key = '$count-${color.toARGB32()}';
    final cached = _cache[key];
    if (cached != null) return cached;

    // Drawn at 3x and displayed at 44 logical px for crisp badges on
    // high-density screens without shipping image assets.
    const size = 132.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);
    canvas.drawCircle(center, size / 2, Paint()..color = color);
    canvas.drawCircle(
      center,
      size / 2 - 6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9,
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$count',
        style: TextStyle(
          fontSize: count >= 100 ? 44 : 56,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final image =
        await recorder.endRecording().toImage(size.round(), size.round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: 44,
      height: 44,
    );
    _cache[key] = descriptor;
    return descriptor;
  }
}
