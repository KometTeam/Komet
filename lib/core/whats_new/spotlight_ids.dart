abstract final class SpotlightIds {
  static const String navChats = 'nav.chats';
  static const String navCalls = 'nav.calls';
  static const String navContacts = 'nav.contacts';
  static const String navSettings = 'nav.settings';

  static const String settingsCustomization = 'settings.customization';
  static const String settingsTheme = 'settings.theme';
  static const String settingsAppearance = 'settings.appearance';
  static const String settingsChatBackground = 'settings.chat-background';
  static const String settingsFont = 'settings.font';
  static const String settingsAppIcon = 'settings.app-icon';
  static const String settingsChats = 'settings.chats';
  static const String settingsNotifications = 'settings.notifications';
  static const String settingsLanguage = 'settings.language';
  static const String settingsMediaDevices = 'settings.media-devices';
  static const String settingsStorage = 'settings.storage';
  static const String settingsCloud = 'settings.cloud';
  static const String settingsProxy = 'settings.proxy';
  static const String settingsSpoof = 'settings.spoof';
  static const String settingsSecurity = 'settings.security';
  static const String settingsDevices = 'settings.devices';
  static const String settingsKomet = 'settings.komet';

  static const String appearanceAnimations = 'appearance.animations';

  static const String storageUsage = 'storage.usage';
  static const String storageLimit = 'storage.limit';

  static const Set<String> tappable = {
    navChats,
    navCalls,
    navContacts,
    navSettings,
    settingsCustomization,
    settingsTheme,
    settingsAppearance,
    settingsChatBackground,
    settingsFont,
    settingsAppIcon,
    settingsChats,
    settingsNotifications,
    settingsLanguage,
    settingsMediaDevices,
    settingsStorage,
    settingsCloud,
    settingsProxy,
    settingsSpoof,
    settingsSecurity,
    settingsDevices,
    settingsKomet,
  };

  static const Set<String> all = {
    ...tappable,
    appearanceAnimations,
    storageUsage,
    storageLimit,
  };
}
