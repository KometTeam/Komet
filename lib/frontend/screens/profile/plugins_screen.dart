import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/plugins/plugin_installer.dart';
import '../../../core/plugins/plugin_models.dart';
import '../../../core/plugins/plugin_store.dart';
import '../../../core/plugins/plugin_updater.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/settings_card.dart';

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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    final picked = result?.files.single;
    if (picked == null || !mounted) return;
    try {
      if (!picked.name.toLowerCase().endsWith('.kinet')) {
        throw const FormatException('Выберите файл с расширением .kinet');
      }
      final path = picked.path;
      final bytes =
          picked.bytes ??
          (path == null ? null : await File(path).readAsBytes());
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('Не удалось прочитать выбранный файл');
      }
      await _confirmAndInstall(await _installer.preview(bytes));
    } catch (error) {
      if (mounted) {
        showCustomNotification(context, 'Не удалось открыть .kinet: $error');
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
      showCustomNotification(context, 'Нужна корректная HTTPS-ссылка');
      return;
    }
    _setBusy('install-url', true);
    try {
      final preview = await _installer.download(uri);
      if (!mounted) return;
      await _confirmAndInstall(preview, sourceUrl: uri);
    } catch (error) {
      if (mounted) {
        showCustomNotification(context, 'Не удалось загрузить .kinet: $error');
      }
    } finally {
      _setBusy('install-url', false);
    }
  }

  Future<void> _confirmAndInstall(
    PluginPackagePreview preview, {
    Uri? sourceUrl,
  }) async {
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
                'Версия ${preview.manifest.version} · ${preview.manifest.author}',
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
                          ? 'Подпись Ed25519 проверена\n${preview.signerFingerprint}'
                          : 'Плагин не подписан',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Плагин получит разрешения:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (preview.manifest.permissions.isEmpty)
                const Text('Нет')
              else
                for (final permission in preview.manifest.permissions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Symbols.check, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(permission.label)),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Разрешить и установить'),
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
        showCustomNotification(context, '${preview.manifest.name} установлен');
      }
    } catch (error) {
      if (mounted) {
        showCustomNotification(context, 'Не удалось установить плагин: $error');
      }
    }
  }

  Future<void> _checkUpdate(PluginDescriptor plugin) async {
    _setBusy(plugin.manifest.id, true);
    try {
      final update = await _updater.check(plugin);
      if (!mounted) return;
      if (update == null) {
        showCustomNotification(context, 'Обновлений нет');
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Обновить плагин?'),
          content: Text(
            '${plugin.manifest.name}: ${plugin.manifest.version} → ${update.version}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Обновить'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _updater.apply(update);
      if (mounted) showCustomNotification(context, 'Плагин обновлён');
    } catch (error) {
      if (mounted) {
        showCustomNotification(context, 'Не удалось обновить: $error');
      }
    } finally {
      _setBusy(plugin.manifest.id, false);
    }
  }

  Future<void> _uninstall(PluginDescriptor plugin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить плагин?'),
        content: Text(plugin.manifest.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _setBusy(plugin.manifest.id, true);
    try {
      await PluginStore.instance.uninstall(plugin.manifest.id);
      if (mounted) {
        showCustomNotification(context, 'Плагин и его данные удалены');
      }
    } catch (error) {
      if (mounted) {
        showCustomNotification(context, 'Не удалось удалить: $error');
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
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Плагины'),
        backgroundColor: cs.surface,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) =>
                value == 'file' ? _installFile() : _installUrl(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'file', child: Text('Установить .kinet')),
              PopupMenuItem(value: 'url', child: Text('Установить по URL')),
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
                        PluginSignatureStatus.bundled => 'Встроенный плагин Komet',
                        PluginSignatureStatus.verified => 'Подписан · ${plugin.signerFingerprint}',
                        PluginSignatureStatus.unsigned => 'Не подписан',
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
                      title: const Text('Проверить обновления'),
                      onTap: _busy.contains(plugin.manifest.id)
                          ? null
                          : () => _checkUpdate(plugin),
                    ),
                  if (plugin.origin == PluginOrigin.installed)
                    ListTile(
                      leading: Icon(Symbols.delete, color: cs.error),
                      title: Text('Удалить', style: TextStyle(color: cs.error)),
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
    return AlertDialog(
      title: const Text('Установить по URL'),
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
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Загрузить')),
      ],
    );
  }
}
