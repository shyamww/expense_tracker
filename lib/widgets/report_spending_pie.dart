import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../constants/categories.dart';

/// Slices at or above this share get category + % inside the ring.
const double kReportPieInsideLabelMinPct = 5.5;

const double _kCenterSpaceRadius = 45;
const double _kSectionRadius = 52;
const double _kStartDegreeOffset = -90;

Color _sliceTitleOnColor(Color sliceColor) {
  return sliceColor.computeLuminance() > 0.52
      ? const Color(0xFF1A1A1A)
      : Colors.white;
}

class _SliceGeom {
  _SliceGeom({
    required this.category,
    required this.value,
    required this.pct,
    required this.info,
    required this.midAngleDeg,
  });

  final String category;
  final double value;
  final double pct;
  final CategoryInfo info;
  final double midAngleDeg;
}

class _CalloutLine {
  _CalloutLine({
    required this.anchor,
    required this.rim,
    required this.color,
  });

  final Offset anchor;
  final Offset rim;
  final Color color;
}

/// Donut chart for reports: large slices labeled inside; small slices get a
/// dedicated label column with one leader line per slice (no overlapping badges).
class ReportSpendingPie extends StatelessWidget {
  const ReportSpendingPie({
    super.key,
    required this.categoryTotals,
    required this.resolveVisual,
  });

  final Map<String, double> categoryTotals;
  final CategoryInfo Function(String name) resolveVisual;

  static List<_SliceGeom> _computeSlices(
    Map<String, double> totals,
    CategoryInfo Function(String) resolve,
  ) {
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sum = entries.fold<double>(0, (s, e) => s + e.value);
    if (sum <= 0) return [];

    var cursorDeg = _kStartDegreeOffset;
    return entries.map((e) {
      final pct = e.value / sum * 100;
      final sweep = 360 * e.value / sum;
      final mid = cursorDeg + sweep / 2;
      cursorDeg += sweep;
      return _SliceGeom(
        category: e.key,
        value: e.value,
        pct: pct,
        info: resolve(e.key),
        midAngleDeg: mid,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final slices = _computeSlices(categoryTotals, resolveVisual);
    if (slices.isEmpty) {
      return const SizedBox.shrink();
    }

    final small = slices
        .where((s) => s.pct < kReportPieInsideLabelMinPct)
        .toList()
      ..sort((a, b) => a.midAngleDeg.compareTo(b.midAngleDeg));

    const labelColW = 132.0;
    const rowH = 26.0;
    final hasSmall = small.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final showCallouts = hasSmall && maxW >= 420;
        final labelW = showCallouts ? labelColW : 0.0;
        final pieCellW = math.max(maxW - labelW, 120.0);
        final pieSize = math.min(pieCellW, 268.0);
        final blockH = showCallouts ? small.length * rowH + 8 : 0.0;
        final chartH = math.max(pieSize, blockH);

        final cx = labelW + pieCellW / 2;
        final cy = chartH / 2;
        const rOuter = _kCenterSpaceRadius + _kSectionRadius;

        final callouts = <_CalloutLine>[];
        if (showCallouts) {
          final startY = math.max(4.0, (chartH - small.length * rowH) / 2);
          for (var i = 0; i < small.length; i++) {
            final s = small[i];
            final rad = s.midAngleDeg * math.pi / 180;
            final rim = Offset(
              cx + math.cos(rad) * rOuter,
              cy + math.sin(rad) * rOuter,
            );
            final y = startY + i * rowH + rowH / 2;
            final anchor = Offset(labelW - 2, y);
            callouts.add(
                _CalloutLine(anchor: anchor, rim: rim, color: s.info.color));
          }
        }

        return SizedBox(
          width: maxW,
          height: chartH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (showCallouts)
                    SizedBox(
                      width: labelW,
                      height: chartH,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < small.length; i++)
                              SizedBox(
                                height: rowH,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${small[i].category}, ${small[i].pct.toStringAsFixed(1)}%',
                                          textAlign: TextAlign.right,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            color: scheme.onSurface,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        small[i].info.icon,
                                        size: 15,
                                        color: small[i].info.color,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(
                    width: pieCellW,
                    height: chartH,
                    child: Center(
                      child: SizedBox(
                        width: pieSize,
                        height: pieSize,
                        child: PieChart(
                          PieChartData(
                            startDegreeOffset: _kStartDegreeOffset,
                            sectionsSpace: 2,
                            centerSpaceRadius: _kCenterSpaceRadius,
                            sections: slices.map((s) {
                              final inside =
                                  s.pct >= kReportPieInsideLabelMinPct;
                              final onSlice = _sliceTitleOnColor(s.info.color);
                              return PieChartSectionData(
                                value: s.value,
                                color: s.info.color,
                                radius: _kSectionRadius,
                                showTitle: inside,
                                title: inside
                                    ? '${s.category}\n${s.pct.toStringAsFixed(1)}%'
                                    : '',
                                titleStyle: TextStyle(
                                  color: onSlice,
                                  fontSize: s.pct >= 14 ? 12 : 10,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                                titlePositionPercentageOffset: 0.56,
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (showCallouts && callouts.isNotEmpty)
                CustomPaint(
                  size: Size(maxW, chartH),
                  painter: _ReportPieCalloutPainter(
                    callouts: callouts,
                    pieCenter: Offset(cx, cy),
                    rOuter: rOuter,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Point just west of the donut at [anchor]'s height, so the segment from
/// [anchor] to the result stays outside the ring.
Offset _hingeWestOfDonut(Offset anchor, Offset o, double r, double pad) {
  final dy = anchor.dy - o.dy;
  if (dy.abs() >= r - 1e-3) {
    return Offset(o.dx - r - pad, anchor.dy);
  }
  final clamped = dy.clamp(-r + 1e-6, r - 1e-6);
  final halfChord = math.sqrt(r * r - clamped * clamped);
  final xLeft = o.dx - halfChord;
  return Offset(xLeft - pad, anchor.dy);
}

class _ReportPieCalloutPainter extends CustomPainter {
  _ReportPieCalloutPainter({
    required this.callouts,
    required this.pieCenter,
    required this.rOuter,
  });

  final List<_CalloutLine> callouts;
  final Offset pieCenter;
  final double rOuter;

  static const double _kWestPad = 14;
  static const double _kOutwardBulge = 48;

  @override
  void paint(Canvas canvas, Size size) {
    final o = pieCenter;
    final r = rOuter;

    for (final c in callouts) {
      final a = c.anchor;
      final rim = c.rim;
      final v = rim - o;
      final len = v.distance;
      final u = len > 1e-6 ? v / len : const Offset(1.0, 0.0);
      // Past the rim along the slice bisector — bends the curve outside the donut.
      final c2 = o + u * (r + _kOutwardBulge);
      var hinge = _hingeWestOfDonut(a, o, r, _kWestPad);
      if (hinge.dx <= a.dx) {
        hinge = Offset(a.dx + 18, a.dy);
      }

      final linePaint = Paint()
        ..color = c.color.withValues(alpha: 0.88)
        ..strokeWidth = 1.75
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Straight segment stays in the west margin (outside the ring at this y),
      // then a quadratic arc to the rim so the leader does not cut through the chart.
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(hinge.dx, hinge.dy)
        ..quadraticBezierTo(c2.dx, c2.dy, rim.dx, rim.dy);
      canvas.drawPath(path, linePaint);

      canvas.drawCircle(
        rim,
        3.2,
        Paint()
          ..color = c.color
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        rim,
        3.2,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReportPieCalloutPainter oldDelegate) {
    return oldDelegate.callouts != callouts ||
        oldDelegate.pieCenter != pieCenter ||
        oldDelegate.rOuter != rOuter;
  }
}
