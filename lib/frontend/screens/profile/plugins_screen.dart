import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/plugins/plugin_installer.dart';
import '../../../core/plugins/plugin_models.dart';
import '../../../core/plugins/plugin_permission_label.dart';
import '../../../core/plugins/plugin_store.dart';
import '../../../core/plugins/plugin_updater.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/settings_card.dart';
import '../../../core/security/app_lock.dart';

class PluginsScreen extends StatefulWidget {
  const PluginsScreen({super.key});

  @override
  State<PluginsScreen> createState() => _PluginsScreenState();
}

class _PluginsScreenState extends State<PluginsScreen> {
  final PluginInstaller _installer = const PluginInstaller();
  final PluginUpdater _updater = PluginUpdater();
  final Set<String> _busy = {};

  Future<void> _installFile() async {
    final result = await AppLock.instance.external(
      () => FilePicker.platform.pickFiles(type: FileType.any, withData: true),
    );
    final picked = result?.files.single;
    if (picked == null || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      if (!picked.name.toLowerCase().endsWith('.kinet')) {
        throw FormatException(l10n.pluginsScreenPickKinetFile);
      }
      final path = picked.path;
      final bytes =
          picked.bytes ??
          (path == null ? null : await File(path).readAsBytes());
      if (bytes == null || bytes.isEmpty) {
        throw FormatException(l10n.pluginsScreenReadFileFailed);
      }
      await _confirmAndInstall(await _installer.preview(bytes));
    } catch (error) {
      if (mounted) {
        showCustomNotification(
          context,
          l10n.pluginsScreenOpenFailed(error.toString()),
        );
      }
    }
  }

  Future<void> _installUrl() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => const PluginUrlDialog(),
    );
    if (value == null || value.isEmpty || !mounted) return;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https') {
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.pluginsScreenHttpsRequired,
      );
      return;
    }
    _setBusy('install-url', true);
    try {
      final preview = await _installer.download(uri);
      if (!mounted) return;
      await _confirmAndInstall(preview, sourceUrl: uri);
    } catch (error) {
      if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(
            context,
          )!.pluginsScreenDownloadFailed(error.toString()),
        );
      }
    } finally {
      _setBusy('install-url', false);
    }
  }

  Future<void> _confirmAndInstall(
    PluginPackagePreview preview, {
    Uri? sourceUrl,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(preview.manifest.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.pluginsScreenVersionAuthor(
                  preview.manifest.version,
                  preview.manifest.author,
                ),
              ),
              if (preview.manifest.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(preview.manifest.description),
              ],
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    preview.signatureStatus == PluginSignatureStatus.verified
                        ? Symbols.verified_user
                        : Symbols.gpp_maybe,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      preview.signatureStatus == PluginSignatureStatus.verified
                          ? l10n.pluginsScreenSignatureVerified(
                              '${preview.signerFingerprint}',
                            )
                          : l10n.pluginsScreenNotSigned,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.pluginsScreenPermissionsTitle,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (preview.manifest.permissions.isEmpty)
                Text(l10n.appearanceChatChromeNone)
              else
                for (final permission in preview.manifest.permissions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Symbols.check, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(permission.label(l10n))),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.chatInfoActionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.pluginsScreenAllowAndInstall),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await PluginStore.instance.install(
        preview.bytes,
        grantedPermissions: preview.manifest.permissions,
        sourceUrl: sourceUrl,
      );
      if (mounted) {
        showCustomNotification(
          context,
          l10n.pluginsScreenInstalled(preview.manifest.name),
        );
      }
    } catch (error) {
      if (mounted) {
        showCustomNotification(
          context,
          l10n.pluginsScreenInstallFailed(error.toString()),
        );
      }
    }
  }

  Future<void> _checkUpdate(PluginDescriptor plugin) async {
    final l10n = AppLocalizations.of(context)!;
    _setBusy(plugin.manifest.id, true);
    try {
      final update = await _updater.check(plugin);
      if (!mounted) return;
      if (update == null) {
        showCustomNotification(context, l10n.pluginsScreenNoUpdates);
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.pluginsScreenUpdateTitle),
          content: Text(
            '${plugin.manifest.name}: ${plugin.manifest.version} → ${update.version}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.chatInfoActionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.updateAction),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _updater.apply(update, l10n);
      if (mounted) {
        showCustomNotification(context, l10n.pluginsScreenUpdated);
      }
    } catch (error) {
      if (mounted) {
        showCustomNotification(
          context,
          l10n.pluginsScreenUpdateFailed(error.toString()),
        );
      }
    } finally {
      _setBusy(plugin.manifest.id, false);
    }
  }

  Future<void> _uninstall(PluginDescriptor plugin) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.pluginsScreenUninstallTitle),
        content: Text(plugin.manifest.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.chatInfoActionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.msgActionsDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _setBusy(plugin.manifest.id, true);
    try {
      await PluginStore.instance.uninstall(plugin.manifest.id);
      if (mounted) {
        showCustomNotification(context, l10n.pluginsScreenUninstalled);
      }
    } catch (error) {
      if (mounted) {
        showCustomNotification(
          context,
          l10n.pluginsScreenUninstallFailed(error.toString()),
        );
      }
    } finally {
      _setBusy(plugin.manifest.id, false);
    }
  }

  void _setBusy(String id, bool busy) {
    if (!mounted) return;
    setState(() => busy ? _busy.add(id) : _busy.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(l10n.pluginsScreenTitle),
        backgroundColor: cs.surface,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) =>
                value == 'file' ? _installFile() : _installUrl(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'file',
                child: Text(l10n.pluginsScreenInstallFile),
              ),
              PopupMenuItem(
                value: 'url',
                child: Text(l10n.pluginsScreenInstallUrl),
              ),
            ],
          ),
        ],
      ),
      body: ValueListenableBuilder<List<PluginDescriptor>>(
        valueListenable: PluginStore.instance.plugins,
        builder: (context, plugins, _) => ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            if (_busy.contains('install-url')) const LinearProgressIndicator(),
            if (_busy.contains('install-url')) const SizedBox(height: 12),
            for (final plugin in plugins) ...[
              SettingsCard(
                children: [
                  ListTile(
                    leading: const Icon(Symbols.extension),
                    title: Text(plugin.manifest.name),
                    subtitle: Text(
                      '${plugin.manifest.version} · ${plugin.manifest.commands.map((item) => item.name).join(', ')}\n'
                      '${switch (plugin.signatureStatus) {
                        PluginSignatureStatus.bundled => l10n.pluginsScreenBundled,
                        PluginSignatureStatus.verified => l10n.pluginsScreenSigned('${plugin.signerFingerprint}'),
                        PluginSignatureStatus.unsigned => l10n.pluginsScreenUnsigned,
                      }}',
                    ),
                    trailing: Switch(
                      value: plugin.enabled,
                      onChanged: (value) => PluginStore.instance.setEnabled(
                        plugin.manifest.id,
                        value,
                      ),
                    ),
                  ),
                  if (plugin.manifest.updateUrl != null)
                    ListTile(
                      leading: _busy.contains(plugin.manifest.id)
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Symbols.update),
                      title: Text(l10n.pluginsScreenCheckUpdates),
                      onTap: _busy.contains(plugin.manifest.id)
                          ? null
                          : () => _checkUpdate(plugin),
                    ),
                  if (plugin.origin == PluginOrigin.installed)
                    ListTile(
                      leading: Icon(Symbols.delete, color: cs.error),
                      title: Text(
                        l10n.msgActionsDelete,
                        style: TextStyle(color: cs.error),
                      ),
                      onTap: () => _uninstall(plugin),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class PluginUrlDialog extends StatefulWidget {
  const PluginUrlDialog({super.key});

  @override
  State<PluginUrlDialog> createState() => _PluginUrlDialogState();
}

class _PluginUrlDialogState extends State<PluginUrlDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    Navigator.pop(context, value.isEmpty ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.pluginsScreenInstallUrl),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
          hintText: 'https://example.org/plugin.kinet',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.chatInfoActionCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.pluginsScreenDownload),
        ),
      ],
    );
  }
}
