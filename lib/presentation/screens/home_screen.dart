import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/models/pca_data.dart';
import '../providers/app_state_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/color_legend.dart';
import '../widgets/hover_tooltip.dart';
import '../widgets/left_panel/left_panel.dart';
import '../widgets/left_panel/view_section.dart';
import '../widgets/left_panel/appearance_section.dart';
import '../widgets/left_panel/display_section.dart';
import '../widgets/left_panel/components_section.dart';
import '../widgets/left_panel/biplot_section.dart';
import '../widgets/left_panel/export_section.dart';
import '../widgets/left_panel/actions_section.dart';
import '../widgets/left_panel/info_section.dart';
import '../widgets/visualizations/scores_3d_view.dart';
import '../widgets/visualizations/pairs_matrix_view.dart';
import '../widgets/visualizations/biplot_view.dart';
import '../widgets/visualizations/variation_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<AppStateProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final mode = provider.viewMode;

    final sections = <PanelSection>[
      // VIEW — always visible
      const PanelSection(
        icon: Icons.view_module,
        label: 'VIEW',
        content: ViewSection(),
      ),
      // EXPORT — biplot and pairs only
      if (mode == ViewMode.biplot || mode == ViewMode.pairs)
        const PanelSection(
          icon: Icons.download,
          label: 'EXPORT',
          content: ExportSection(),
        ),
      // APPEARANCE — hidden in Variation mode
      if (mode != ViewMode.variation)
        PanelSection(
          icon: Icons.palette,
          label: 'APPEARANCE',
          content: AppearanceSection(showLabelBy: mode != ViewMode.pairs),
        ),
      // DISPLAY — Scores 3D only
      if (mode == ViewMode.scores3d)
        const PanelSection(
          icon: Icons.visibility,
          label: 'DISPLAY',
          content: DisplaySection(),
        ),
      // COMPONENTS — Pairs only
      if (mode == ViewMode.pairs)
        const PanelSection(
          icon: Icons.layers,
          label: 'COMPONENTS',
          content: ComponentsSection(),
        ),
      // BIPLOT — Biplot only
      if (mode == ViewMode.biplot)
        const PanelSection(
          icon: Icons.scatter_plot,
          label: 'BIPLOT',
          content: BiplotSection(),
        ),
      // ACTIONS — always visible
      const PanelSection(
        icon: Icons.upload,
        label: 'ACTIONS',
        content: ActionsSection(),
      ),
      // INFO — always last
      const PanelSection(
        icon: Icons.info_outline,
        label: 'INFO',
        content: InfoSection(),
      ),
    ];

    return AppShell(
      appTitle: 'PCA Explorer',
      appIcon: Icons.scatter_plot,
      sections: sections,
      content: const _MainContent(),
    );
  }
}

class _MainContent extends StatelessWidget {
  const _MainContent();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    // Graph area always uses light theme for maximum readability.
    // Dark mode only applies to the chrome (left panel, top bar).
    const isDark = false;
    const bgColor = Colors.white;

    if (provider.isLoading) {
      return Container(
        color: bgColor,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.error != null) {
      return Container(
        color: bgColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text('Error loading data', style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.sm),
              Text(provider.error!, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (provider.data == null) {
      return Container(color: bgColor, child: const Center(child: Text('No data')));
    }

    return ClipRect(
      child: Container(
        color: bgColor,
        child: Stack(
          children: [
            // Main visualization
            _buildVisualization(provider, isDark),
            // Helper text for 3D view
            if (provider.viewMode == ViewMode.scores3d)
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.md,
                child: Text(
                  'Zoom with scroll wheel. Drag to rotate.',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            // Color legend overlay (top-right, for modes that use color).
            // Pairs mode handles its own legend inside PairsMatrixView.
            if (provider.viewMode != ViewMode.variation &&
                provider.viewMode != ViewMode.pairs)
              Positioned(
                top: AppSpacing.md,
                right: AppSpacing.md,
                child: ColorLegend(colorMap: provider.colorMap, isDark: isDark),
              ),
            // Hover tooltip overlay
            if (provider.hoveredPointIndex != null && provider.hoverPosition != null)
              Positioned(
                left: provider.hoverPosition!.dx + 12,
                top: provider.hoverPosition!.dy - 20,
                child: HoverTooltip(
                  sampleIndex: provider.hoveredPointIndex!,
                  data: provider.data!,
                  provider: provider,
                  isDark: isDark,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualization(AppStateProvider provider, bool isDark) {
    switch (provider.viewMode) {
      case ViewMode.scores3d:
        return Scores3dView(data: provider.data!, provider: provider, isDark: isDark);
      case ViewMode.pairs:
        return PairsMatrixView(data: provider.data!, provider: provider, isDark: isDark);
      case ViewMode.biplot:
        return BiplotView(data: provider.data!, provider: provider, isDark: isDark);
      case ViewMode.variation:
        return VariationView(data: provider.data!, isDark: isDark);
    }
  }
}
