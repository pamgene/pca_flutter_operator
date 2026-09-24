import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/utils/web_download.dart';
import '../../../domain/models/pca_data.dart';
import '../../painters/pairs_matrix_painter.dart';
import '../../providers/app_state_provider.dart';
import '../color_legend.dart';

class PairsMatrixView extends StatefulWidget {
  final PcaData data;
  final AppStateProvider provider;
  final bool isDark;

  const PairsMatrixView({
    super.key,
    required this.data,
    required this.provider,
    required this.isDark,
  });

  @override
  State<PairsMatrixView> createState() => _PairsMatrixViewState();
}

class _PairsMatrixViewState extends State<PairsMatrixView> {
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
    final n = provider.numComponents;
    final isDark = widget.isDark;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final textColor = isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final diagBg = isDark ? const Color(0xFF374151) : AppColors.neutral100;
    final tickColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF374151);

    const outerLabelW = 28.0;
    const outerLabelH = 22.0;
    const legendGap = 16.0;
    const legendReserve = 130.0;
    const padding = 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availW =
            constraints.maxWidth - padding * 2 - outerLabelW - legendGap - legendReserve;
        final availH = constraints.maxHeight - padding * 2 - outerLabelH;
        final gridSize = min(availW, availH).clamp(0.0, double.infinity);

        final matrixBlock = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(width: outerLabelW),
                SizedBox(
                  width: gridSize,
                  height: outerLabelH,
                  child: Row(
                    children: List.generate(
                      n,
                      (col) => Expanded(
                        child: Center(
                          child: Text(
                            'PC${col + 1}',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: outerLabelW,
                  height: gridSize,
                  child: Column(
                    children: List.generate(
                      n,
                      (row) => Expanded(
                        child: Center(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              'PC${row + 1}',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: gridSize,
                  height: gridSize,
                  child: Column(
                    children: List.generate(
                      n,
                      (row) => Expanded(
                        child: Row(
                          children: List.generate(n, (col) {
                            if (row == col) {
                              return Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: diagBg,
                                    border:
                                        Border.all(color: borderColor, width: 1.0),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'PC${row + 1}',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: borderColor, width: 1.0),
                                ),
                                child: CustomPaint(
                                  painter: PairsCellPainter(
                                    scores: widget.data.scores,
                                    pcIndexX: col,
                                    pcIndexY: row,
                                    colorForSample: provider.getColorForSample,
                                    showYTicks: col == n - 1,
                                    showXTicks: row == n - 1,
                                    tickColor: tickColor,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(padding),
            child: RepaintBoundary(
              key: _repaintKey,
              child: ColoredBox(
                color: Colors.white,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    matrixBlock,
                    const SizedBox(width: legendGap),
                    ColorLegend(colorMap: provider.colorMap, isDark: isDark),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
      _showFilenameDialog(context, bytes, 'pairs_export');
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
