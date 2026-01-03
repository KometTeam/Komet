import 'package:flutter/material.dart';
import 'package:gwid/plugins/plugin_model.dart';
import 'package:gwid/plugins/plugin_ui_builder.dart';
import 'package:gwid/app_sizes.dart';

class PluginSectionScreen extends StatelessWidget {
  final PluginSection section;

  const PluginSectionScreen({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final builder = PluginUIBuilder();

    return Scaffold(
      appBar: AppBar(title: Text(section.title)),
      body: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        itemCount: section.items.length,
        itemBuilder: (context, index) {
          return builder.buildSettingsItem(section.items[index], context);
        },
      ),
    );
  }
}

class PluginReplacementScreen extends StatelessWidget {
  final PluginScreen screen;
  final String? title;

  const PluginReplacementScreen({super.key, required this.screen, this.title});

  @override
  Widget build(BuildContext context) {
    final builder = PluginUIBuilder();
    return builder.buildScreen(screen, context);
  }
}
