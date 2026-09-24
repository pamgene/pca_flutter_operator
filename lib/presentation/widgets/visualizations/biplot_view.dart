import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/utils/web_download.dart';
import '../../../domain/models/pca_data.dart';
import '../../painters/biplot_painter.dart';
import '../../providers/app_state_provider.dart';

class BiplotView extends StatefulWidget {
  final PcaData data;
  final AppStateProvider provider;
  final bool isDark;

  const BiplotView({
    super.key,
    required this.data,
    required this.provider,
    required this.isDark,
  });

  @override
  State<BiplotView> createState() => _BiplotViewState();
}

class _BiplotViewState extends State<BiplotView> {
  BiplotPainter? _painter;
  int? _hoveredLoadingIndex;
  final GlobalKey _repaintKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    final hintColor = widget.isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);

    return LayoutBuilder(
      builder: (context, constraints) {
        final squareSize =
            min(constraints.maxWidth, constraints.maxHeight);

        _painter = BiplotPainter(
          scores: widget.data.scores,
          loadings: widget.data.loadings,
          pcIndexX: provider.pcIndex(provider.biplotXAxis),
          pcIndexY: provider.pcIndex(provider.biplotYAxis),
          colorForSample: provider.getColorForSample,
          labelForSample: provider.getLabelForSample,
          loadingThresholdPercent: provider.loadingThreshold,
          loadingZoomPercent: provider.loadingZoom,
          labelFontSize: provider.biplotLabelFontSize,
          isDark: widget.isDark,
          hoveredIndex: provider.hoveredPointIndex,
          hoveredLoadingIndex: _hoveredLoadingIndex,
        );

        return Center(
          child: SizedBox(
            width: squareSize,
            height: squareSize,
            child: Stack(
              children: [
                // Captured area
                RepaintBoundary(
                  key: _repaintKey,
                  child: MouseRegion(
                    onHover: (event) => _onHover(event.localPosition),
                    onExit: (_) {
                      provider.setHoveredPoint(null, null);
                      if (_hoveredLoadingIndex != null) {
                        setState(() => _hoveredLoadingIndex = null);
                      }
                    },
                    child: CustomPaint(
                      size: Size(squareSize, squareSize),
                      painter: _painter,
                    ),
                  ),
                ),
                // Hint text — outside RepaintBoundary so it won't appear in PNG
                Positioned(
                  top: 6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Hover arrow to see label',
                      style: TextStyle(
                        color: hintColor,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
                // Save PNG button
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: _SavePngButton(
                    onPressed: () => _savePng(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onHover(Offset position) {
    final painter = _painter;
    if (painter == null) return;

    const hitRadius = 15.0;

    int? nearestScore;
    double nearestScoreDist = hitRadius;
    for (var i = 0; i < painter.projectedScorePositions.length; i++) {
      final d = (painter.projectedScorePositions[i] - position).distance;
      if (d < nearestScoreDist) {
        nearestScoreDist = d;
        nearestScore = widget.data.scores[i].ci;
      }
    }

    int? nearestLoading;
    double nearestLoadingDist = hitRadius;
    for (var i = 0; i < painter.projectedArrowTips.length; i++) {
      final d = (painter.projectedArrowTips[i] - position).distance;
      if (d < nearestLoadingDist) {
        nearestLoadingDist = d;
        nearestLoading = painter.visibleLoadingIndices[i];
      }
    }

    widget.provider
        .setHoveredPoint(nearestScore, nearestScore != null ? position : null);

    if (_hoveredLoadingIndex != nearestLoading) {
      setState(() => _hoveredLoadingIndex = nearestLoading);
    }
  }

  Future<void> _savePng(BuildContext context) async {
    final boundary = _repaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;
    final bytes = byteData.buffer.asUint8List();

    if (!context.mounted) return;
    _showFilenameDialog(context, bytes, 'biplot_export');
  }
}

class _SavePngButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _SavePngButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Save as PNG',
      child: Material(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download, size: 14, color: Color(0xFF374151)),
                SizedBox(width: 4),
                Text(
                  'Save PNG',
                  style: TextStyle(fontSize: 12, color: Color(0xFF374151)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showFilenameDialog(
    BuildContext context, Uint8List bytes, String defaultName) {
  final controller = TextEditingController(text: defaultName);
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Save PNG'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Filename',
          suffixText: '.png',
        ),
        autofocus: true,
        onSubmitted: (_) {
          final name = controller.text.trim();
          if (name.isNotEmpty) {
            Navigator.of(ctx).pop();
            downloadPng(bytes, name);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              Navigator.of(ctx).pop();
              downloadPng(bytes, name);
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
