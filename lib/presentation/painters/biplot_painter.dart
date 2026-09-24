import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/models/pca_data.dart';

class BiplotPainter extends CustomPainter {
  final List<PcaScore> scores;
  final List<PcaLoading> loadings;
  final int pcIndexX;
  final int pcIndexY;
  final Color Function(int ci) colorForSample;
  final String Function(int ci) labelForSample;
  final double loadingThresholdPercent;
  final double loadingZoomPercent;
  final double labelFontSize;
  final double axisMarginPercent;
  final bool isDark;
  final int? hoveredIndex;
  final int? hoveredLoadingIndex;

  /// Populated during paint() for hit-testing in the view widget.
  final List<Offset> projectedScorePositions = [];
  final List<Offset> projectedArrowTips = [];
  final List<int> visibleLoadingIndices = [];

  BiplotPainter({
    required this.scores,
    required this.loadings,
    required this.pcIndexX,
    required this.pcIndexY,
    required this.colorForSample,
    required this.labelForSample,
    required this.loadingThresholdPercent,
    required this.loadingZoomPercent,
    required this.labelFontSize,
    required this.axisMarginPercent,
    required this.isDark,
    this.hoveredIndex,
    this.hoveredLoadingIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    projectedScorePositions.clear();
    projectedArrowTips.clear();
    visibleLoadingIndices.clear();

    if (scores.isEmpty) return;

    const padding = 60.0;
    final plotLeft = padding;
    final plotTop = padding * 0.6;
    final plotWidth = size.width - padding - plotLeft;
    final plotHeight = size.height - padding - plotTop;

    if (plotWidth <= 0 || plotHeight <= 0) return;

    final textColor =
        isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    final axisColor =
        isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    final arrowColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    // Compute score ranges
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final s in scores) {
      final x = s[pcIndexX];
      final y = s[pcIndexY];
      minX = min(minX, x);
      maxX = max(maxX, x);
      minY = min(minY, y);
      maxY = max(maxY, y);
    }

    final rangeX = maxX - minX;
    final rangeY = maxY - minY;
    if (rangeX == 0 && rangeY == 0) return;

    final marginFraction = axisMarginPercent / 100.0;
    final marginX = max(rangeX * marginFraction, 0.1);
    final marginY = max(rangeY * marginFraction, 0.1);
    final adjMinX = minX - marginX;
    final adjMaxX = maxX + marginX;
    final adjMinY = minY - marginY;
    final adjMaxY = maxY + marginY;
    final adjRangeX = adjMaxX - adjMinX;
    final adjRangeY = adjMaxY - adjMinY;

    Offset toScreen(double dataX, double dataY) {
      final normX = (dataX - adjMinX) / adjRangeX;
      final normY = (dataY - adjMinY) / adjRangeY;
      return Offset(
          plotLeft + normX * plotWidth, plotTop + (1 - normY) * plotHeight);
    }

    // --- Bounding box ---
    final boxPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final boxRect =
        Rect.fromLTWH(plotLeft, plotTop, plotWidth, plotHeight);
    canvas.drawRect(boxRect, boxPaint);

    // --- Grid lines through origin ---
    final origin = toScreen(0, 0);
    final gridPaint = Paint()
      ..color = axisColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    if (origin.dx > plotLeft && origin.dx < plotLeft + plotWidth) {
      canvas.drawLine(
          Offset(origin.dx, plotTop), Offset(origin.dx, plotTop + plotHeight), gridPaint);
    }
    if (origin.dy > plotTop && origin.dy < plotTop + plotHeight) {
      canvas.drawLine(
          Offset(plotLeft, origin.dy), Offset(plotLeft + plotWidth, origin.dy), gridPaint);
    }

    // --- Tick marks and labels on X axis (bottom edge) ---
    _drawLinearTicks(
      canvas: canvas,
      start: Offset(plotLeft, plotTop + plotHeight),
      end: Offset(plotLeft + plotWidth, plotTop + plotHeight),
      dataMin: adjMinX,
      dataMax: adjMaxX,
      tickDirection: const Offset(0, 1),
      textColor: textColor,
      tickPaint: Paint()
        ..color = axisColor
        ..strokeWidth = 1.5,
    );

    // --- Tick marks and labels on Y axis (left edge) ---
    _drawLinearTicks(
      canvas: canvas,
      start: Offset(plotLeft, plotTop + plotHeight),
      end: Offset(plotLeft, plotTop),
      dataMin: adjMinY,
      dataMax: adjMaxY,
      tickDirection: const Offset(-1, 0),
      textColor: textColor,
      tickPaint: Paint()
        ..color = axisColor
        ..strokeWidth = 1.5,
      alignRight: true,
    );

    // --- Axis labels ---
    final xLabel = TextPainter(
      text: TextSpan(
          text: 'PC${pcIndexX + 1}',
          style: TextStyle(
              color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    xLabel.paint(
        canvas,
        Offset(plotLeft + plotWidth / 2 - xLabel.width / 2,
            plotTop + plotHeight + 35));

    canvas.save();
    canvas.translate(15, plotTop + plotHeight / 2);
    canvas.rotate(-pi / 2);
    final yLabel = TextPainter(
      text: TextSpan(
          text: 'PC${pcIndexY + 1}',
          style: TextStyle(
              color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    yLabel.paint(canvas, Offset(-yLabel.width / 2, 0));
    canvas.restore();

    // --- Loading arrows (labels shown only on hover) ---
    if (loadingThresholdPercent > 0) {
      final magnitudes = loadings.map((l) {
        final lx = l[pcIndexX];
        final ly = l[pcIndexY];
        return sqrt(lx * lx + ly * ly);
      }).toList();

      final sortedMags = List<double>.from(magnitudes)..sort();
      final cutoffIndex =
          ((1 - loadingThresholdPercent / 100) * sortedMags.length)
              .floor()
              .clamp(0, sortedMags.length - 1);
      final cutoff = sortedMags[cutoffIndex];

      final zoomFactor = loadingZoomPercent / 100.0;
      final loadingScale = max(adjRangeX, adjRangeY) * 0.4 * zoomFactor;

      final arrowPaint = Paint()
        ..color = arrowColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.save();
      canvas.clipRect(boxRect);

      for (var i = 0; i < loadings.length; i++) {
        if (magnitudes[i] < cutoff) continue;

        final l = loadings[i];
        final lx = l[pcIndexX] * loadingScale;
        final ly = l[pcIndexY] * loadingScale;

        final tipScreen = toScreen(lx, ly);
        final originScreen = origin;

        visibleLoadingIndices.add(i);
        projectedArrowTips.add(tipScreen);

        final isHoveredLoading = hoveredLoadingIndex == i;
        final currentArrowPaint = isHoveredLoading
            ? (Paint()
              ..color = textColor
              ..strokeWidth = 2.0
              ..style = PaintingStyle.stroke)
            : arrowPaint;

        canvas.drawLine(originScreen, tipScreen, currentArrowPaint);

        final angle = atan2(
            tipScreen.dy - originScreen.dy, tipScreen.dx - originScreen.dx);
        const headLen = 8.0;
        const headAngle = 0.4;
        final p1 = Offset(
          tipScreen.dx - headLen * cos(angle - headAngle),
          tipScreen.dy - headLen * sin(angle - headAngle),
        );
        final p2 = Offset(
          tipScreen.dx - headLen * cos(angle + headAngle),
          tipScreen.dy - headLen * sin(angle + headAngle),
        );
        canvas.drawLine(tipScreen, p1, currentArrowPaint);
        canvas.drawLine(tipScreen, p2, currentArrowPaint);
      }

      canvas.restore();

      for (var i = 0; i < loadings.length; i++) {
        if (magnitudes[i] < cutoff) continue;
        if (hoveredLoadingIndex != i) continue;

        final l = loadings[i];
        final lx = l[pcIndexX] * loadingScale;
        final ly = l[pcIndexY] * loadingScale;
        final tipScreen = toScreen(lx, ly);

        final clampedTip = Offset(
          tipScreen.dx.clamp(plotLeft, plotLeft + plotWidth),
          tipScreen.dy.clamp(plotTop, plotTop + plotHeight),
        );

        final nameTp = TextPainter(
          text: TextSpan(
            text: l.variable,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final labelRect = Rect.fromLTWH(
          clampedTip.dx + 6,
          clampedTip.dy - nameTp.height / 2 - 2,
          nameTp.width + 6,
          nameTp.height + 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(labelRect, const Radius.circular(3)),
          Paint()
            ..color = (isDark ? const Color(0xFF1F2937) : Colors.white)
                .withValues(alpha: 0.9),
        );
        nameTp.paint(canvas,
            Offset(clampedTip.dx + 9, clampedTip.dy - nameTp.height / 2));
      }
    }

    // --- Score points: compute positions first, then place labels with overlap avoidance ---
    final List<_LabelPlacement> placements = [];

    for (final s in scores) {
      final pos = toScreen(s[pcIndexX], s[pcIndexY]);
      projectedScorePositions.add(pos);

      final label = labelForSample(s.ci);
      final color = colorForSample(s.ci);
      final isHovered = hoveredIndex == s.ci;
      final fontSize = isHovered ? labelFontSize + 1 : labelFontSize;

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: isHovered ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Default position: centred on the point
      Offset labelOrigin = Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2);
      Rect labelRect = Rect.fromLTWH(
          labelOrigin.dx, labelOrigin.dy, tp.width, tp.height);

      // Greedy offset search to avoid overlap with already-placed labels
      if (!_overlapsAny(labelRect, placements)) {
        placements.add(_LabelPlacement(labelRect, tp));
      } else {
        final step = fontSize + 2;
        const directions = [
          Offset(1, 0), Offset(1, -1), Offset(0, -1), Offset(-1, -1),
          Offset(-1, 0), Offset(-1, 1), Offset(0, 1), Offset(1, 1),
        ];
        outer:
        for (var dist = 1; dist <= 3; dist++) {
          for (final dir in directions) {
            final candidate = Offset(
              labelOrigin.dx + dir.dx * step * dist,
              labelOrigin.dy + dir.dy * step * dist,
            );
            final candidateRect = Rect.fromLTWH(
                candidate.dx, candidate.dy, tp.width, tp.height);
            if (!_overlapsAny(candidateRect, placements)) {
              labelRect = candidateRect;
              break outer;
            }
          }
        }
        placements.add(_LabelPlacement(labelRect, tp));
      }
    }

    // Draw score points and their labels
    for (var i = 0; i < scores.length; i++) {
      final s = scores[i];
      final pos = projectedScorePositions[i];
      final color = colorForSample(s.ci);
      final isHovered = hoveredIndex == s.ci;
      final p = placements[i];

      if (isHovered) {
        canvas.drawCircle(
            pos, 8, Paint()..color = color.withValues(alpha: 0.3));
      }

      p.painter.paint(canvas, p.rect.topLeft);
    }
  }

  bool _overlapsAny(Rect rect, List<_LabelPlacement> placements) {
    for (final p in placements) {
      if (rect.overlaps(p.rect.inflate(2))) return true;
    }
    return false;
  }

  void _drawLinearTicks({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required double dataMin,
    required double dataMax,
    required Offset tickDirection,
    required Color textColor,
    required Paint tickPaint,
    bool alignRight = false,
  }) {
    const numTicks = 5;
    const tickLen = 4.0;

    for (var i = 0; i <= numTicks; i++) {
      final t = i / numTicks;
      final pos = Offset(
        start.dx + (end.dx - start.dx) * t,
        start.dy + (end.dy - start.dy) * t,
      );
      final tickEnd = Offset(
        pos.dx + tickDirection.dx * tickLen,
        pos.dy + tickDirection.dy * tickLen,
      );

      canvas.drawLine(pos, tickEnd, tickPaint);

      final value = dataMin + (dataMax - dataMin) * t;
      final valueStr = value.abs() < 1
          ? value.toStringAsFixed(2)
          : value.toStringAsFixed(1);

      final tp = TextPainter(
        text: TextSpan(
          text: valueStr,
          style: TextStyle(color: textColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      if (alignRight) {
        tp.paint(canvas,
            Offset(tickEnd.dx - tp.width - 3, tickEnd.dy - tp.height / 2));
      } else {
        tp.paint(
            canvas, Offset(tickEnd.dx - tp.width / 2, tickEnd.dy + 2));
      }
    }
  }

  @override
  bool shouldRepaint(BiplotPainter oldDelegate) => true;
}

class _LabelPlacement {
  final Rect rect;
  final TextPainter painter;

  _LabelPlacement(this.rect, this.painter);
}
