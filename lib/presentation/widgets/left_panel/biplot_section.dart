import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/theme_provider.dart';

class BiplotSection extends StatelessWidget {
  const BiplotSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final labelColor = isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final pcLabels = provider.data?.pcLabels ?? ['PC1', 'PC2'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // X Axis dropdown
        Text('X Axis', style: AppTextStyles.label.copyWith(color: labelColor)),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          child: DropdownButtonFormField<String>(
            value: pcLabels.contains(provider.biplotXAxis) ? provider.biplotXAxis : pcLabels.first,
            decoration: const InputDecoration(),
            items: pcLabels
                .map((pc) => DropdownMenuItem(value: pc, child: Text(pc)))
                .toList(),
            onChanged: (value) {
              if (value != null) provider.setBiplotXAxis(value);
            },
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Y Axis dropdown
        Text('Y Axis', style: AppTextStyles.label.copyWith(color: labelColor)),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          child: DropdownButtonFormField<String>(
            value: pcLabels.contains(provider.biplotYAxis) ? provider.biplotYAxis : pcLabels.last,
            decoration: const InputDecoration(),
            items: pcLabels
                .map((pc) => DropdownMenuItem(value: pc, child: Text(pc)))
                .toList(),
            onChanged: (value) {
              if (value != null) provider.setBiplotYAxis(value);
            },
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Loading Threshold slider (0-100%)
        Text('Loading Threshold', style: AppTextStyles.label.copyWith(color: labelColor)),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: provider.loadingThreshold,
                min: 0,
                max: 100,
                onChanged: provider.setLoadingThreshold,
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '${provider.loadingThreshold.toStringAsFixed(0)}%',
                style: AppTextStyles.body.copyWith(color: labelColor),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // Loading Zoom slider (1-400%)
        Text('Loading Zoom', style: AppTextStyles.label.copyWith(color: labelColor)),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: provider.loadingZoom,
                min: 1,
                max: 400,
                onChanged: provider.setLoadingZoom,
              ),
            ),
            SizedBox(
              width: 42,
              child: Text(
                '${provider.loadingZoom.toStringAsFixed(0)}%',
                style: AppTextStyles.body.copyWith(color: labelColor),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // Label Size slider (8-24 px)
        Text('Label Size', style: AppTextStyles.label.copyWith(color: labelColor)),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: provider.biplotLabelFontSize,
                min: 8,
                max: 24,
                divisions: 16,
                onChanged: provider.setBiplotLabelFontSize,
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '${provider.biplotLabelFontSize.toStringAsFixed(0)}px',
                style: AppTextStyles.body.copyWith(color: labelColor),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
