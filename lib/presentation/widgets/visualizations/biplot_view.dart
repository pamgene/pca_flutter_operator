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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.provider.registerExportCallback(_savePng);
    });
  }

  @override
  void dispose() {
    widget.provider.unregisterExportCallback();
    super.dispose();
  }

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
          axisMarginPercent: provider.biplotAxisPadding,
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
                // Captured area (white background so PNG isn't transparent)
                RepaintBoundary(
                  key: _repaintKey,
                  child: ColoredBox(
                    color: Colors.white,
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
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        if (context.mounted) _showError(context, 'Plot not ready');
        return;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (context.mounted) _showError(context, 'Failed to encode PNG');
        return;
      }
      final bytes = byteData.buffer.asUint8List();

      if (!context.mounted) return;
      _showFilenameDialog(context, bytes, 'biplot_export');
    } catch (e) {
      if (context.mounted) _showError(context, 'Export failed: $e');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
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
