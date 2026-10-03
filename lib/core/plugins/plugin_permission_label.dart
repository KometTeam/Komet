import '../../l10n/app_localizations.dart';
import 'plugin_manifest.dart';

extension PluginPermissionLabel on PluginPermission {
  String label(AppLocalizations l10n) => switch (this) {
    PluginPermission.chatWrite => l10n.pluginPermissionChatWrite,
    PluginPermission.chatEdit => l10n.pluginPermissionChatEdit,
    PluginPermission.uiNotify => l10n.pluginPermissionUiNotify,
    PluginPermission.contactRead => l10n.pluginPermissionContactRead,
    PluginPermission.replyRead => l10n.pluginPermissionReplyRead,
    PluginPermission.network => l10n.pluginPermissionNetwork,
    PluginPermission.photoWrite => l10n.pluginPermissionPhotoWrite,
    PluginPermission.fileWrite => l10n.pluginPermissionFileWrite,
    PluginPermission.storage => l10n.pluginPermissionStorage,
  };
}
