import 'package:flutter/material.dart';

/// Tiny single-series bar chart: check-ins per hour for one stop, one day.
/// One hue only (magnitude job): the peak hour is full-strength with a
/// direct label, other bars are a lighter step of the same hue. Long-press
/// any bar for the exact hour and count.
class HourlyBarChart extends StatelessWidget {
  final List<int> hourly;

  const HourlyBarChart({super.key, required this.hourly});

  static String hourLabel(int hour) {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12${hour < 12 ? 'am' : 'pm'}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final peak = hourly.fold<int>(0, (max, v) => v > max ? v : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 72,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var hour = 0; hour < 24; hour++) ...[
                Expanded(
                  child: Tooltip(
                    message:
                        '${hourLabel(hour)}–${hourLabel((hour + 1) % 24)}: '
                        '${hourly[hour]} check-in${hourly[hour] == 1 ? '' : 's'}',
                    triggerMode: TooltipTriggerMode.longPress,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (peak > 0 && hourly[hour] == peak)
                          Text(
                            '$peak',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        Container(
                          height: peak == 0
                              ? 2
                              : 2 + 54 * (hourly[hour] / peak),
                          decoration: BoxDecoration(
                            color: hourly[hour] == peak && peak > 0
                                ? scheme.primary
                                : scheme.primary.withValues(
                                    alpha: hourly[hour] == 0 ? 0.15 : 0.45),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (hour < 23) const SizedBox(width: 2),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Recessive time axis: four anchors across the day.
        Row(
          children: [
            for (final anchor in const [0, 6, 12, 18])
              Expanded(
                child: Text(
                  hourLabel(anchor),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.outline),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
