import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:legacy_gantt_chart/legacy_gantt_chart.dart';
import 'package:intl/intl.dart';
import 'package:legacy_timeline_scrubber/legacy_timeline_scrubber.dart' as scrubber;
import 'dart:ui' as ui;

class MinimalGanttChart extends StatefulWidget {
  const MinimalGanttChart({super.key});

  @override
  State<MinimalGanttChart> createState() => _MinimalGanttChartState();
}

class _MinimalGanttChartState extends State<MinimalGanttChart> {


  // final now = DateTime.now();
  DateTime _currentDate = DateTime.now();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  DateTime _visibleStart = DateTime.now().subtract(const Duration(days: 3));
  DateTime _visibleEnd = DateTime.now().add(const Duration(days: 3));

  Orientation? _lastOrientation;
  bool? _lastIsTablet;
  static const double _leftPaneWidth = 180.0;
  static const double _axisHeight = 44.0;
  static const double _rowHeight = 27.0;

  int _daysAroundToday(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isTablet = mq.size.shortestSide >= 600;
    final isPortrait = mq.orientation == Orientation.portrait;

    if (isTablet) {
      return isPortrait ? 5 : 10;
    }
    return isPortrait ? 3 : 5;
  }

  void _setVisibleRangeAroundToday(BuildContext context, {DateTime? anchorDate}) {
    final days = _daysAroundToday(context);
    final anchor = anchorDate ?? DateTime.now();
    final anchorDay = DateTime(anchor.year, anchor.month, anchor.day);
    _visibleStart = anchorDay.subtract(Duration(days: days));
    _visibleEnd = anchorDay.add(Duration(days: days));
  }

  // 2. Define your tasks
    List<LegacyGanttTask> tasks = [
      // LegacyGanttTask(
      //   id: 'task1',
      //   rowId: 'row1',
      //   name: 'Implement Feature A',
      //   start: _task1Start,
      //   end: _task1End,
      // ),
      // LegacyGanttTask(
      //   id: 'task2',
      //   rowId: 'row2',
      //   name: 'Implement Feature B',
      //   start: _currentDate.add(const Duration(days: 3)),
      //   end: _currentDate.add(const Duration(days: 8)),
      // ),
      // LegacyGanttTask(
      //   id: 'task3',
      //   rowId: 'row3',
      //   name: 'Test Feature A',
      //   start: _currentDate.add(const Duration(days: 11)),
      //   end: _currentDate.add(const Duration(days: 14)),
      // ),
    ];


    // 1. Define your rows
    List<LegacyGanttRow> rows = [
      // LegacyGanttRow(id: 'row1', label: 'Development'),
      // LegacyGanttRow(id: 'row2', label: 'QA'),
      // LegacyGanttRow(id: 'row3', label: 'Planning'),
    ];

    List<scrubber.LegacyGanttTask> get scrubberTasks => tasks.map((task) => scrubber.LegacyGanttTask(
      id: task.id,
      rowId: task.rowId,
      name: task.name,
      start: task.start,
      end: task.end,
    )).toList();

    List<LegacyGanttTaskDependency> deps = [];

  @override
  void initState() {
    _currentDate = DateTime(_currentDate.year, _currentDate.month, _currentDate.day);
    // (removed unused task1 start/end fields)
    for (var i = 0; i < 10; i++) {
      tasks.add(LegacyGanttTask(
        id: 'task$i',
        rowId: 'row$i',
        name: 'Task $i',
        isMilestone: i == 0,
        start: _currentDate.add(Duration(days: i)),
        end: _currentDate.add(Duration(days: i + (i == 0 ? 100 : 1))),
      ));
      rows.add(LegacyGanttRow(id: 'row$i', label: 'Task Label $i'));
    }

    // A couple dependencies to demonstrate arrows attaching to the milestone diamond.
    deps.addAll(const [
      LegacyGanttTaskDependency(
        predecessorTaskId: 'task1',
        successorTaskId: 'task0',
        type: DependencyType.finishToStart,
      ),
      LegacyGanttTaskDependency(
        predecessorTaskId: 'task0',
        successorTaskId: 'task2',
        type: DependencyType.finishToStart,
      ),
    ]);
    super.initState();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.of(context);
    final isTablet = mq.size.shortestSide >= 600;
    final orientation = mq.orientation;

    if (_lastOrientation != orientation || _lastIsTablet != isTablet) {
      _lastOrientation = orientation;
      _lastIsTablet = isTablet;
      setState(() {
        final currentCenter =
            _visibleStart.add(Duration(milliseconds: (_visibleEnd.difference(_visibleStart).inMilliseconds / 2).round()));
        _setVisibleRangeAroundToday(context, anchorDate: currentCenter);
      });
    }
  }

  double _zoom = 1.0;
  DateTime? _zoomBaselineStart;
  DateTime? _zoomBaselineEnd;

  String _fmtDay(DateTime d) => '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  @override
  Widget build(BuildContext context) {
    // 3. Create the widget
    final baselineText = _zoomBaselineStart != null && _zoomBaselineEnd != null
        ? 'Baseline (zoom=1 ref): ${_fmtDay(_zoomBaselineStart!)} … ${_fmtDay(_zoomBaselineEnd!)}'
        : 'Baseline: (zoom in to capture; updates again after each reset to zoom 1)';
    final visibleText = 'Visible: ${_fmtDay(_visibleStart)} … ${_fmtDay(_visibleEnd)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Gantt Chart'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('Zoom: ${_zoom.toStringAsFixed(2)}x'),
            ),
          ),
          IconButton(
            tooltip: 'Zoom out',
            onPressed: () => setState(() {
              _zoom = (_zoom / 1.2).clamp(1.0, 8.0);
            }),
            icon: const Icon(Icons.zoom_out),
          ),
          IconButton(
            tooltip: 'Reset zoom',
            onPressed: () {
              
              setState(() {
                _zoom = 1.0;
              });
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Zoom in',
            onPressed: () => setState(() {
              _zoom = (_zoom * 1.2).clamp(1.0, 8.0);
            }),
            icon: const Icon(Icons.zoom_in),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(baselineText, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(visibleText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text(
                    'Test: pan at zoom 1 → zoom in → pan → reset zoom. Visible span should match baseline duration, centered on current view. Repeat pan+zoom to see baseline refresh.',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Row(
        children: [
          SizedBox(
            width: _leftPaneWidth,
            child: Column(
              children: [ 
                Container(
                  height: _axisHeight,
                  alignment: Alignment.center,
                  color: Colors.white,
                  child: Text('Task Name'),
                ),
                Expanded(child: 
                  ListView.builder(
                    controller: _verticalScrollController,
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      // Keep left list row height aligned with chart rows.
                      final height = _rowHeight;
                      return SizedBox(
                        height: height,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(children: [ Text(
                                row.label ?? row.id,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(width: 8),
                              IconButton(onPressed: (){
                                setState(() {
                                  tasks.removeAt(index);
                                  rows.removeAt(index);
                                });
                              }, icon: Icon(Icons.delete))
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                )
              ]
            )
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, chartConstraints) {
                // Important: do NOT wrap the chart in an additional horizontal
                // SingleChildScrollView when using horizontalZoomFactor. The
                // chart uses zoom to change the visible time window (Option A).
                return LegacyGanttChartWidget(
                  scrollController: _verticalScrollController,
                  horizontalScrollController: _horizontalScrollController,
                  axisHeight: _axisHeight,
                  rowHeight: _rowHeight,
                  onVisibleRangeChanged: (start, end) {
                    setState(() {
                      _visibleStart = start;
                      _visibleEnd = end;
                    });
                  },
                  enableDragAndDrop: false,

                  horizontalZoomFactor: _zoom,
                  allowHorizontalZoomGestures: true,
                  // true: zoom dengan scroll vertikal biasa (trackpad/mouse).
                  // false: kalau chart ditempatkan di dalam ScrollView vertikal dan
                  // parent harus mengambil wheel, set ke false dan pakai Ctrl/Cmd/Alt+scroll.
                  horizontalZoomOnVerticalWheel: true,
                  onHorizontalZoomFactorChanged: (z) {
                    setState(() {
                      _zoom = z;
                      // debugPrint('zoom: $_zoom');
                    });
                  },
                  onHorizontalZoomBaselineCaptured: (start, end) {
                    setState(() {
                      _zoomBaselineStart = start;
                      _zoomBaselineEnd = end;
                    });
                  },
                  dependencies: deps,
                  data: tasks,
                  visibleRows: rows,
                  showNowLine: true,
                  // Keep it simple for the demo: all rows are single-lane.
                  rowMaxStackDepth: {for (final r in rows) r.id: 1},
                  gridMin: _visibleStart.millisecondsSinceEpoch.toDouble(),
                  gridMax: _visibleEnd.millisecondsSinceEpoch.toDouble(),
                  // Example: custom milestone diamond via taskBarBuilder.
                  // Dependency arrows for milestones will attach to the diamond (0.8 * rowHeight),
                  // not the full time-width bar rect.
                  taskBarBuilder: (task) {
                    if (task.isMilestone) {
                      return _ExampleMilestoneDiamondWithLabel(name: task.name ?? '');
                    }
                    return _ExampleTaskBar(name: task.name ?? task.id, color: task.color ?? Colors.blue);
                  },
                  timelineAxisHeaderBuilder: (context, scale, visibleDomain, totalDomain, theme, totalContentWidth) {
                    return Container(
                      color: theme.backgroundColor,
                      child: RepaintBoundary(
                        child: SizedBox.expand(
                          child: CustomPaint(
                            painter: _CenteredAxisHeaderLabelsPainter(
                              scale: scale,
                              domain: totalDomain,
                              visibleDomain: visibleDomain,
                              theme: theme,
                              showEveryDayLabel: true,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleTaskBar extends StatelessWidget {
  const _ExampleTaskBar({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: onColor, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ExampleMilestoneDiamondWithLabel extends StatelessWidget {
  const _ExampleMilestoneDiamondWithLabel({required this.name});

  final String name;

  static const Color _milestoneYellow = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context) {
    // Render the diamond at the start (left) of the milestone bar, while the
    // label is to the right of the diamond. This matches the dependency-anchor
    // behavior for custom milestones (anchored at startDate).
    return LayoutBuilder(
      builder: (context, constraints) {
        final diamondSide = constraints.maxHeight * 0.8;
        const gap = 10.0;
        return Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: diamondSide,
              height: diamondSide,
              child: CustomPaint(
                painter: const _ExampleMilestoneDiamondPainter(color: _milestoneYellow),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExampleMilestoneDiamondPainter extends CustomPainter {
  const _ExampleMilestoneDiamondPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final side = size.height;
    final x = (size.width - side) / 2;
    const y = 0.0;
    final path = Path()
      ..moveTo(x, y + side / 2)
      ..lineTo(x + side / 2, y)
      ..lineTo(x + side, y + side / 2)
      ..lineTo(x + side / 2, y + side)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ExampleMilestoneDiamondPainter oldDelegate) => oldDelegate.color != color;
}

class MinimalGanttChart2 extends StatelessWidget {
  const MinimalGanttChart2({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentDate = DateTime(now.year, now.month, now.day);
    // 1. Define your rows
    final rows = [
      LegacyGanttRow(id: 'row1', label: 'Development'),
      LegacyGanttRow(id: 'row2', label: 'QA'),
      LegacyGanttRow(id: 'row3', label: 'Planning'),
    ];

    // 2. Define your tasks
    final tasks = [
      LegacyGanttTask(
        id: 'task1',
        rowId: 'row1',
        name: 'Implement Feature A',
        start: DateTime(currentDate.subtract(const Duration(days: 1)).year, currentDate.subtract(const Duration(days: 1)).month, currentDate.subtract(const Duration(days: 1)).day, 0, 0),
        end: DateTime(currentDate.add(const Duration(days: 1)).year, currentDate.add(const Duration(days: 1)).month, currentDate.add(const Duration(days: 1)).day, 23, 59),
      ),
      LegacyGanttTask(
        id: 'task2',
        rowId: 'row2',
        name: 'Implement Feature B',
        start: currentDate.add(const Duration(days: 3)),
        end: currentDate.add(const Duration(days: 8)),
      ),
      LegacyGanttTask(
        id: 'task3',
        rowId: 'row3',
        name: 'Test Feature A',
        start: currentDate.add(const Duration(days: 2)),
        end: currentDate.add(const Duration(days: 4)),
      ),
    ];

    // 3. Create the widget
    return Scaffold(
      appBar: AppBar(title: const Text('Simple Gantt Chart')),
      body: LegacyGanttChartWidget(
        scrollController: ScrollController(),
        enableDragAndDrop: true,
        data: tasks,
        visibleRows: rows,
        showNowLine: true,
        rowMaxStackDepth: const {'row1': 2, 'row2': 1}, // Max overlapping tasks per row
        gridMin: DateTime.now().subtract(const Duration(days: 10)).millisecondsSinceEpoch.toDouble(),
        gridMax: DateTime.now().add(const Duration(days: 150)).millisecondsSinceEpoch.toDouble(),
        timelineAxisHeaderBuilder: (context, scale, visibleDomain, totalDomain, theme, totalContentWidth) {
          return RepaintBoundary(
            child: CustomPaint(
              size: Size(double.infinity, double.infinity),
              painter: _CenteredAxisHeaderLabelsPainter(
                scale: scale,
                domain: totalDomain,
                visibleDomain: visibleDomain,
                theme: theme,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CenteredAxisHeaderLabelsPainter extends CustomPainter {
  final double Function(DateTime) scale;
  final List<DateTime> domain;
  final List<DateTime> visibleDomain;
  final LegacyGanttTheme theme;
  final bool showEveryDayLabel;

  const _CenteredAxisHeaderLabelsPainter({
    required this.scale,
    required this.domain,
    required this.visibleDomain,
    required this.theme,
    this.showEveryDayLabel = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (domain.isEmpty || visibleDomain.isEmpty) return;

    final Duration tickInterval = showEveryDayLabel ? const Duration(days: 1) : _chooseAutoTickInterval();
    final String Function(DateTime) labelFormat = showEveryDayLabel
        ? (dt) => "${DateFormat('d MMM', 'en_US').format(dt)}."
        : _labelFormatFor(tickInterval);

    final List<MapEntry<double, DateTime>> tickPositions = [];
    var currentTick = _roundDownTo(domain.first, tickInterval);
    final loopEnd = domain.last.add(tickInterval);
    while (currentTick.isBefore(loopEnd)) {
      tickPositions.add(MapEntry(scale(currentTick), currentTick));
      currentTick = currentTick.add(tickInterval);
    }
    if (tickPositions.length < 2) return;

    final baseStyle = theme.axisTextStyle;
    if (baseStyle.color == Colors.transparent) return;

    // Two-row header: year (top) + day label (bottom)
    final dayStyle = baseStyle;
    final yearStyle = baseStyle.copyWith(fontWeight: FontWeight.w600, fontSize: 18);

    final yearPainter = TextPainter(textDirection: ui.TextDirection.ltr, textAlign: TextAlign.center);
    yearPainter.text = TextSpan(text: '2026', style: yearStyle);
    yearPainter.layout();

    final dayPainter = TextPainter(textDirection: ui.TextDirection.ltr, textAlign: TextAlign.center);
    dayPainter.text = TextSpan(text: '30 Sep.', style: dayStyle);
    dayPainter.layout();

    const double rowGap = 2.0;
    final totalTextHeight = yearPainter.height + rowGap + dayPainter.height;
    final topRowY = (size.height - totalTextHeight) / 2;
    final bottomRowY = topRowY + yearPainter.height + rowGap;

    // Year label: centered across the whole visible span (daily mode).
    if (tickInterval == const Duration(days: 1)) {
      final startX = scale(visibleDomain.first);
      final endX = scale(visibleDomain.last);
      if (endX > startX) {
        final midX = (startX + endX) / 2;
        // Pick the year at the center of the viewport, so the label flips
        // when Jan 1 passes under the year label / center line.
        int bestIndex = 0;
        double bestDist = double.infinity;
        for (var i = 0; i < tickPositions.length - 1; i++) {
          final tickX = tickPositions[i].key;
          final nextTickX = tickPositions[i + 1].key;
          if (nextTickX <= tickX) continue;
          final cellMidX = (tickX + nextTickX) / 2;
          final dist = (cellMidX - midX).abs();
          if (dist < bestDist) {
            bestDist = dist;
            bestIndex = i;
          }
        }
        final centeredDate = tickPositions[bestIndex].value;
        final yearLabel = DateFormat('yyyy', 'en_US').format(centeredDate);
        final tp = TextPainter(
          text: TextSpan(text: yearLabel, style: yearStyle),
          textAlign: TextAlign.center,
          textDirection: ui.TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: (endX - startX).clamp(0, size.width));

        tp.paint(canvas, Offset(midX - (tp.width / 2), topRowY));
      }
    }

    for (var i = 0; i < tickPositions.length - 1; i++) {
      final tickX = tickPositions[i].key;
      final nextTickX = tickPositions[i + 1].key;
      if (nextTickX <= tickX) continue;

      final midX = (tickX + nextTickX) / 2;
      final tickTime = tickPositions[i].value;

      final label = labelFormat(tickTime);
      final textPainter = TextPainter(
        text: TextSpan(text: label, style: dayStyle),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final labelX = midX - (textPainter.width / 2);
      textPainter.paint(canvas, Offset(labelX, bottomRowY));
    }
  }

  @override
  bool shouldRepaint(covariant _CenteredAxisHeaderLabelsPainter oldDelegate) =>
      theme != oldDelegate.theme ||
      showEveryDayLabel != oldDelegate.showEveryDayLabel ||
      !listEquals(domain, oldDelegate.domain) ||
      !listEquals(visibleDomain, oldDelegate.visibleDomain);

  Duration _chooseAutoTickInterval() {
    final visibleDuration = visibleDomain.last.difference(visibleDomain.first);
    final usableSteps = _tickSteps.where((s) => s.interval.inMilliseconds * 2 <= visibleDuration.inMilliseconds);

    _TickStep selectedStep;
    selectedStep = usableSteps.isNotEmpty ? usableSteps.last : _tickSteps.last;
    for (final step in usableSteps) {
      final t1 = visibleDomain.first;
      final t2 = t1.add(step.interval);
      final pixelsPerTick = (scale(t2) - scale(t1)).abs();

      final testLabel = step.labelFormat(DateTime(2023, 1, 1, 10, 0));
      final textSpan = TextSpan(text: testLabel, style: theme.axisTextStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      )..layout();

      if (pixelsPerTick > textPainter.width + 8) {
        selectedStep = step;
        break;
      }
    }

    return selectedStep.interval;
  }

  String Function(DateTime) _labelFormatFor(Duration tickInterval) {
    // Map to the closest predefined format we already have.
    final match = _tickSteps.where((s) => s.interval == tickInterval).toList();
    if (match.isNotEmpty) return match.first.labelFormat;
    return (dt) => DateFormat('d').format(dt);
  }

  DateTime _roundDownTo(DateTime dt, Duration delta) {
    final int ms = dt.millisecondsSinceEpoch;
    final int deltaMs = delta.inMilliseconds;
    final int offset = dt.timeZoneOffset.inMilliseconds;
    final int localMs = ms + offset;
    final int roundedLocalMs = (localMs ~/ deltaMs) * deltaMs;
    final int resultMs = roundedLocalMs - offset;
    return DateTime.fromMillisecondsSinceEpoch(resultMs, isUtc: dt.isUtc);
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