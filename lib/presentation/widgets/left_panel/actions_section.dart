import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';

class ActionsSection extends StatelessWidget {
  const ActionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();

    final hasFailed = provider.saveError != null && !provider.isSaving;

    final FaIconData iconData;
    final String label;
    if (provider.isSaving) {
      iconData = FontAwesomeIcons.floppyDisk;
      label = 'Saving results...';
    } else if (hasFailed) {
      iconData = FontAwesomeIcons.triangleExclamation;
      label = 'Retry save';
    } else if (provider.hasSaved) {
      iconData = FontAwesomeIcons.check;
      label = 'Results saved';
    } else {
      iconData = FontAwesomeIcons.floppyDisk;
      label = 'Waiting to save...';
    }

    final button = SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: hasFailed ? () => provider.savePcaResults() : null,
        icon: provider.isSaving
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : FaIcon(iconData, size: 14),
        label: Text(label),
      ),
    );

    return hasFailed
        ? Tooltip(message: provider.saveError ?? '', child: button)
        : button;
  }
}
