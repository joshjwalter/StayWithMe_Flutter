import 'package:flutter/material.dart';

/// Settings page for app-level options.
class SettingsPage extends StatelessWidget {
  /// Creates a settings page with debug mode controls.
  const SettingsPage({
    super.key,
    required this.debugMode,
    required this.onDebugModeChanged,
  });

  final bool debugMode;
  final ValueChanged<bool> onDebugModeChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SwitchListTile(
          key: const Key('debug_mode_toggle'),
          title: const Text('Debug Mode'),
          subtitle: const Text(
            'Enables 2-min preset and shows debug messages under the timer.',
          ),
          value: debugMode,
          onChanged: onDebugModeChanged,
        ),
      ],
    );
  }
}
