// packages/gantt_chart/lib/src/axis_painter.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

import 'models/legacy_gantt_theme.dart';

/// Controls the timeline "major" segmentation for axis labels and boundary lines.
enum TimelineViewMode {
  /// Uses adaptive tick steps based on visible duration.
  auto,
  day,
  week,
  month,
  year,
}

/// Controls where timeline labels are anchored.
enum TimelineLabelPlacement {
  /// Label is centered between two consecutive boundaries.
  betweenBoundaries,

  /// Label is anchored on the boundary line itself.
  onBoundary,
}

/// A [CustomPainter] that draws the time axis and vertical grid lines for the Gantt chart.
///
/// This painter is versatile and can be used to draw both the main background grid
/// and the timeline header at the top of the chart. It dynamically adjusts the
/// density of the grid lines and the format of the labels based on the visible
/// time duration, providing a clear and readable scale at any zoom level.
class AxisPainter extends CustomPainter {
  /// The starting x-coordinate for painting.
  final double x;

  /// The vertical position where the axis line is drawn. For the header, this is
  /// typically the vertical center. For the background grid, it's the top edge.
  final double y;

  /// The total width of the area to be painted.
  final double width;

  /// The total height of the area to be painted. This is used to draw the vertical
  /// grid lines across the entire height of the chart content area.
  final double height;

  /// A function that converts a [DateTime] to its corresponding horizontal (x-axis) pixel value.
  final double Function(DateTime) scale;

  /// The total date range of the entire chart, from the earliest start date to the
  /// latest end date. This is used to generate all possible tick marks.
  final List<DateTime> domain;

  /// The currently visible date range. This is used to determine the appropriate
  /// interval and format for the tick marks and labels (e.g., days, hours, minutes).
  final List<DateTime> visibleDomain;

  /// The theme data that defines the colors and styles for the grid lines and labels.
  final LegacyGanttTheme theme;

  /// An optional builder function to customize the labels on the timeline axis.
  final String Function(DateTime, Duration)? timelineAxisLabelBuilder;

  /// The color to use for highlighting weekend days.
  final Color? weekendColor;

  /// A list of integers representing the days of the week to be highlighted as weekends.
  final List<int>? weekendDays;

  /// Whether to draw the vertical grid lines (ticks).
  final bool showGridLines;

  /// Whether to vertically center the labels within the [height] of the painter area.
  /// If false, labels are drawn just above the [y] line.
  final bool verticallyCenterLabels;

  /// Controls major boundaries (day/week/month/year) and label placement when not [TimelineViewMode.auto].
  final TimelineViewMode timelineViewMode;

  /// Label placement strategy when [timelineViewMode] is not [TimelineViewMode.auto].
  final TimelineLabelPlacement labelPlacement;

  /// Stroke width for (auto) grid lines.
  final double gridLineStrokeWidth;

  /// Stroke width for major boundary lines in non-auto modes.
  final double majorGridLineStrokeWidth;

  AxisPainter({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.scale,
    required this.domain,
    required this.visibleDomain,
    required this.theme,
    this.timelineAxisLabelBuilder,
    this.weekendColor,
    this.weekendDays,
    this.showGridLines = true,
    this.verticallyCenterLabels = false,
    this.timelineViewMode = TimelineViewMode.auto,
    TimelineLabelPlacement? labelPlacement,
    this.gridLineStrokeWidth = 1.0,
    this.majorGridLineStrokeWidth = 2.0,
  }) : labelPlacement = labelPlacement ??
            (timelineViewMode == TimelineViewMode.week
                ? TimelineLabelPlacement.onBoundary
                : TimelineLabelPlacement.betweenBoundaries);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.gridColor
      ..strokeWidth = gridLineStrokeWidth;

    if (domain.isEmpty || visibleDomain.isEmpty) return;

    if (weekendColor != null && weekendDays != null && weekendDays!.isNotEmpty) {
      final weekendPaint = Paint()..color = weekendColor!;
      DateTime currentDay = DateTime(visibleDomain.first.year, visibleDomain.first.month, visibleDomain.first.day);
      while (currentDay.isBefore(visibleDomain.last)) {
        if (weekendDays!.contains(currentDay.weekday)) {
          final startX = scale(currentDay);
          final endX = scale(currentDay.add(const Duration(days: 1)));
          if (endX > startX) {
            canvas.drawRect(Rect.fromLTWH(startX, y, endX - startX, height), weekendPaint);
          }
        }
        currentDay = currentDay.add(const Duration(days: 1));
      }
    }

    // Non-auto: draw major boundaries and place labels either between boundaries or on them.
    if (timelineViewMode != TimelineViewMode.auto) {
      final majorPaint = Paint()
        ..color = theme.gridColor
        ..strokeWidth = majorGridLineStrokeWidth;

      final boundaries = _generateMajorBoundaries(
        start: domain.first,
        end: domain.last,
        mode: timelineViewMode,
      ).toList();

      if (boundaries.length < 2) return;

      double lastLabelRightEdge = double.negativeInfinity;

      for (int i = 0; i < boundaries.length; i++) {
        final boundaryTime = boundaries[i];
        final boundaryX = scale(boundaryTime);

        if (showGridLines) {
          canvas.drawLine(
            Offset(boundaryX, y),
            Offset(boundaryX, y + height),
            majorPaint,
          );
        }

        double? labelCenterX;
        if (labelPlacement == TimelineLabelPlacement.onBoundary) {
          labelCenterX = boundaryX;
        } else {
          if (i == boundaries.length - 1) {
            labelCenterX = null;
          } else {
            final nextX = scale(boundaries[i + 1]);
            labelCenterX = (boundaryX + nextX) / 2;
          }
        }

        if (labelCenterX == null) continue;

        final approxInterval = _approxIntervalForMode(timelineViewMode);
        final label = timelineAxisLabelBuilder != null
            ? timelineAxisLabelBuilder!(boundaryTime, approxInterval)
            : _defaultMajorLabel(boundaryTime, timelineViewMode);

        lastLabelRightEdge = _paintLabelAtX(
          canvas,
          label: label,
          centerX: labelCenterX,
          lastLabelRightEdge: lastLabelRightEdge,
        );
      }

      return;
    }

    final visibleDuration = visibleDomain.last.difference(visibleDomain.first);
    final usableSteps = _tickSteps.where((s) => s.interval.inMilliseconds * 2 <= visibleDuration.inMilliseconds);

    _TickStep? selectedStep;

    for (final step in usableSteps) {
      final t1 = visibleDomain.first;
      final t2 = t1.add(step.interval);
      final pixelsPerTick = (scale(t2) - scale(t1)).abs();
      final testLabel = step.labelFormat(DateTime(2023, 1, 1, 10, 0)); // Sample date
      final textStyle = theme.axisTextStyle;
      final textSpan = TextSpan(text: testLabel, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();

      if (pixelsPerTick > textPainter.width + 8) {
        selectedStep = step;
        break;
      }
    }

    selectedStep ??= usableSteps.isNotEmpty ? usableSteps.last : _tickSteps.last;

    final Duration tickInterval = selectedStep.interval;
    final String Function(DateTime) labelFormat = selectedStep.labelFormat;

    final List<MapEntry<double, DateTime>> tickPositions = [];
    if (domain.isNotEmpty) {
      DateTime currentTick = _roundDownTo(domain.first, tickInterval);

      final loopEnd = domain.last.add(tickInterval);

      while (currentTick.isBefore(loopEnd)) {
        tickPositions.add(MapEntry(scale(currentTick), currentTick));
        currentTick = currentTick.add(tickInterval);
      }
    }

    bool isFirstVisibleTickFound = false;
    DateTime? previousTickTime;
    double lastLabelRightEdge = double.negativeInfinity;

    for (final entry in tickPositions) {
      final tickX = entry.key;
      final tickTime = entry.value;

      String label;
      final bool isSubDaily = tickInterval.inHours < 24 && tickInterval.inDays < 1;
      final bool isNewDay = previousTickTime != null && tickTime.day != previousTickTime.day;
      final bool isVisible = tickX >= x;

      if (isSubDaily && ((isVisible && !isFirstVisibleTickFound) || isNewDay)) {
        label = DateFormat('MMM d').format(tickTime);
        if (isVisible) {
          isFirstVisibleTickFound = true;
        }
      } else {
        label = timelineAxisLabelBuilder != null
            ? timelineAxisLabelBuilder!(tickTime, tickInterval)
            : labelFormat(tickTime);
      }

      previousTickTime = tickTime;

      if (showGridLines) {
        canvas.drawLine(
          Offset(tickX, y),
          Offset(tickX, y + height),
          paint,
        );
      }

      final textStyle = theme.axisTextStyle;
      if (textStyle.color != Colors.transparent) {
        final textSpan = TextSpan(text: label, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: ui.TextDirection.ltr,
        );
        textPainter.layout();

        final double labelWidth = textPainter.width;
        final double labelX = tickX - (labelWidth / 2);

        // Check for collision with the previously drawn label
        // We add a small padding (8.0) to ensure readability
        if (labelX >= lastLabelRightEdge + 8.0) {
          double textY;
          if (verticallyCenterLabels) {
            textY = y + (height - textPainter.height) / 2;
          } else {
            textY = y - textPainter.height;
          }

          textPainter.paint(
            canvas,
            Offset(labelX, textY),
          );

          lastLabelRightEdge = labelX + labelWidth;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant AxisPainter oldDelegate) =>
      theme != oldDelegate.theme ||
      width != oldDelegate.width ||
      height != oldDelegate.height ||
      showGridLines != oldDelegate.showGridLines ||
      verticallyCenterLabels != oldDelegate.verticallyCenterLabels ||
      timelineViewMode != oldDelegate.timelineViewMode ||
      labelPlacement != oldDelegate.labelPlacement ||
      gridLineStrokeWidth != oldDelegate.gridLineStrokeWidth ||
      majorGridLineStrokeWidth != oldDelegate.majorGridLineStrokeWidth ||
      !listEquals(domain, oldDelegate.domain) ||
      (visibleDomain.isNotEmpty && oldDelegate.visibleDomain.isNotEmpty
          ? visibleDomain.first != oldDelegate.visibleDomain.first ||
              visibleDomain.last != oldDelegate.visibleDomain.last
          : listEquals(visibleDomain, oldDelegate.visibleDomain));

  double _paintLabelAtX(
    Canvas canvas, {
    required String label,
    required double centerX,
    required double lastLabelRightEdge,
  }) {
    final textStyle = theme.axisTextStyle;
    if (textStyle.color == Colors.transparent) return lastLabelRightEdge;

    final textSpan = TextSpan(text: label, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    final labelWidth = textPainter.width;
    final labelX = centerX - (labelWidth / 2);

    // Collision avoidance with padding.
    if (labelX < lastLabelRightEdge + 8.0) return lastLabelRightEdge;

    final double textY =
        verticallyCenterLabels ? (y + (height - textPainter.height) / 2) : (y - textPainter.height);
    textPainter.paint(canvas, Offset(labelX, textY));
    return labelX + labelWidth;
  }

  Duration _approxIntervalForMode(TimelineViewMode mode) {
    switch (mode) {
      case TimelineViewMode.day:
        return const Duration(days: 1);
      case TimelineViewMode.week:
        return const Duration(days: 7);
      case TimelineViewMode.month:
        return const Duration(days: 30);
      case TimelineViewMode.year:
        return const Duration(days: 365);
      case TimelineViewMode.auto:
        return const Duration(days: 1);
    }
  }

  String _defaultMajorLabel(DateTime dt, TimelineViewMode mode) {
    switch (mode) {
      case TimelineViewMode.day:
        return DateFormat('EEE d').format(dt);
      case TimelineViewMode.week:
        return 'Week ${_weekNumber(dt)}';
      case TimelineViewMode.month:
        return DateFormat('MMM yyyy').format(dt);
      case TimelineViewMode.year:
        return DateFormat('yyyy').format(dt);
      case TimelineViewMode.auto:
        return DateFormat('d MMM').format(dt);
    }
  }

  Iterable<DateTime> _generateMajorBoundaries({
    required DateTime start,
    required DateTime end,
    required TimelineViewMode mode,
  }) sync* {
    if (end.isBefore(start)) return;

    DateTime current;
    switch (mode) {
      case TimelineViewMode.day:
        current = DateTime(start.year, start.month, start.day);
        break;
      case TimelineViewMode.week:
        final dayStart = DateTime(start.year, start.month, start.day);
        final deltaToMonday = (dayStart.weekday - DateTime.monday) % 7;
        current = dayStart.subtract(Duration(days: deltaToMonday));
        break;
      case TimelineViewMode.month:
        current = DateTime(start.year, start.month, 1);
        break;
      case TimelineViewMode.year:
        current = DateTime(start.year, 1, 1);
        break;
      case TimelineViewMode.auto:
        current = start;
        break;
    }

    // Generate boundaries that cover [start, end] plus one extra step.
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      yield current;
      current = _addMajorStep(current, mode);
      if (mode == TimelineViewMode.auto) break;
    }
    if (mode != TimelineViewMode.auto) {
      yield _addMajorStep(current, mode);
    }
  }

  DateTime _addMajorStep(DateTime dt, TimelineViewMode mode) {
    switch (mode) {
      case TimelineViewMode.day:
        return dt.add(const Duration(days: 1));
      case TimelineViewMode.week:
        return dt.add(const Duration(days: 7));
      case TimelineViewMode.month:
        final y = dt.year;
        final m = dt.month;
        final nextMonth = m == 12 ? 1 : (m + 1);
        final nextYear = m == 12 ? (y + 1) : y;
        return DateTime(nextYear, nextMonth, 1);
      case TimelineViewMode.year:
        return DateTime(dt.year + 1, 1, 1);
      case TimelineViewMode.auto:
        return dt;
    }
  }

  DateTime _roundDownTo(DateTime dt, Duration delta) {
    if (delta.inDays >= 7) {}
    final int ms = dt.millisecondsSinceEpoch;
    final int deltaMs = delta.inMilliseconds;
    final int offset = dt.timeZoneOffset.inMilliseconds;
    final int localMs = ms + offset;
    final int roundedLocalMs = (localMs ~/ deltaMs) * deltaMs;
    final int resultMs = roundedLocalMs - offset;

    return DateTime.fromMillisecondsSinceEpoch(
      resultMs,
      isUtc: dt.isUtc,
    );
  }
}

class _TickStep {
  final Duration interval;
  final String Function(DateTime) labelFormat;

  const _TickStep(this.interval, this.labelFormat);
}

final List<_TickStep> _tickSteps = [
  _TickStep(const Duration(minutes: 1), (dt) => DateFormat('h:mm:ss').format(dt)),
  _TickStep(const Duration(minutes: 5), (dt) => DateFormat('h:mm').format(dt)),
  _TickStep(const Duration(minutes: 15), (dt) => DateFormat('h:mm a').format(dt)),
  _TickStep(const Duration(minutes: 30), (dt) => DateFormat('h:mm a').format(dt)),
  _TickStep(const Duration(hours: 1), (dt) => DateFormat('h:mm a').format(dt)),
  _TickStep(const Duration(hours: 2), (dt) => DateFormat('h a').format(dt)),
  _TickStep(const Duration(hours: 6), (dt) => DateFormat('h a').format(dt)),
  _TickStep(const Duration(hours: 12), (dt) => DateFormat('ha').format(dt)),
  _TickStep(const Duration(days: 1), (dt) => DateFormat('EEE d').format(dt)),
  _TickStep(const Duration(days: 2), (dt) => DateFormat('d MMM').format(dt)),
  _TickStep(const Duration(days: 7), (dt) => 'Week ${_weekNumber(dt)}'),
  _TickStep(const Duration(days: 30), (dt) => DateFormat('MMM yyyy').format(dt)),
  _TickStep(const Duration(days: 365), (dt) => DateFormat('yyyy').format(dt)),
];

int _weekNumber(DateTime date) {
  final dayOfYear = int.parse(DateFormat('D').format(date));
  final woy = ((dayOfYear - date.weekday + 10) / 7).floor();
  if (woy < 1) return 52;
  if (woy > 52) return 52;
  return woy;
}
