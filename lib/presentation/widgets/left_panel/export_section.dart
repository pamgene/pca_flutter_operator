import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';

class ExportSection extends StatelessWidget {
  const ExportSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: provider.canExport ? () => provider.triggerExport(context) : null,
        icon: const Icon(Icons.download, size: 14),
        label: const Text('Save PNG'),
      ),
    );
  }
}
