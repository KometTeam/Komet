import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KometSettings {
  static const _kViewDeleted = 'komet_view_deleted';
  static const _kViewRedacted = 'komet_view_redacted';
  static const _kFullTimestamp = 'komet_full_timestamp';
  static const _kGhostMode = 'komet_ghost_mode';
  static const _kAntiRead = 'komet_anti_read';
  static const _kSelfOnlineCheck = 'komet_self_online_check';
  static const _kHideAllChatsFolder = 'komet_hide_all_chats_folder';
  static const _kShowHiddenChats = 'komet_show_hidden_chats';

  static final ValueNotifier<bool> viewDeleted = ValueNotifier(false);
  static final ValueNotifier<bool> viewRedacted = ValueNotifier(false);
  static final ValueNotifier<bool> fullTimestamp = ValueNotifier(false);
  static final ValueNotifier<bool> ghostMode = ValueNotifier(false);
  static final ValueNotifier<bool> antiRead = ValueNotifier(false);
  static final ValueNotifier<bool> selfOnlineCheck = ValueNotifier(true);
  static final ValueNotifier<bool> hideAllChatsFolder = ValueNotifier(false);
  static final ValueNotifier<bool> showHiddenChats = ValueNotifier(false);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    viewDeleted.value = prefs.getBool(_kViewDeleted) ?? false;
    viewRedacted.value = prefs.getBool(_kViewRedacted) ?? false;
    fullTimestamp.value = prefs.getBool(_kFullTimestamp) ?? false;
    ghostMode.value = prefs.getBool(_kGhostMode) ?? false;
    antiRead.value = prefs.getBool(_kAntiRead) ?? false;
    selfOnlineCheck.value = prefs.getBool(_kSelfOnlineCheck) ?? true;
    hideAllChatsFolder.value = prefs.getBool(_kHideAllChatsFolder) ?? false;
    showHiddenChats.value = prefs.getBool(_kShowHiddenChats) ?? false;
  }

  static Future<void> setViewDeleted(bool value) async {
    viewDeleted.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kViewDeleted, value);
  }

  static Future<void> setViewRedacted(bool value) async {
    viewRedacted.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kViewRedacted, value);
  }

  static Future<void> setFullTimestamp(bool value) async {
    fullTimestamp.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFullTimestamp, value);
  }

  static Future<void> setGhostMode(bool value) async {
    ghostMode.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGhostMode, value);
  }

  static Future<void> setAntiRead(bool value) async {
    antiRead.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAntiRead, value);
  }

  static Future<void> setSelfOnlineCheck(bool value) async {
    selfOnlineCheck.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSelfOnlineCheck, value);
  }

  static Future<void> setHideAllChatsFolder(bool value) async {
    hideAllChatsFolder.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHideAllChatsFolder, value);
  }

  static Future<void> setShowHiddenChats(bool value) async {
    showHiddenChats.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowHiddenChats, value);
  }
}
