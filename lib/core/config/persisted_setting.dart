import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef PrefReader<T> = T? Function(SharedPreferences prefs, String key);
typedef PrefWriter<T> =
    Future<void> Function(SharedPreferences prefs, String key, T value);

class PersistedSetting<T> {
  PersistedSetting({
    required this.prefKey,
    required this.defaultValue,
    required this.read,
    required this.write,
    T Function(T value)? sanitize,
  }) : sanitize = sanitize ?? ((value) => value),
       current = ValueNotifier<T>(defaultValue);

  final String prefKey;
  final T defaultValue;
  final PrefReader<T> read;
  final PrefWriter<T> write;
  final T Function(T value) sanitize;
  final ValueNotifier<T> current;

  Future<T> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = sanitize(read(prefs, prefKey) ?? defaultValue);
    current.value = value;
    return value;
  }

  Future<void> save(T value) async {
    final sanitized = sanitize(value);
    current.value = sanitized;
    final prefs = await SharedPreferences.getInstance();
    await write(prefs, prefKey, sanitized);
  }
}

typedef EnumEncoder<T extends Enum> = String Function(T value);
typedef EnumDecoder<T extends Enum> = T Function(String? raw);

T enumFromName<T extends Enum>(List<T> values, String? raw, T fallback) =>
    values.firstWhere((v) => v.name == raw, orElse: () => fallback);

class PersistedEnum<T extends Enum> {
  PersistedEnum({
    required this.prefKey,
    required this.defaultValue,
    required this.encode,
    required this.decode,
  }) : current = ValueNotifier<T>(defaultValue);

  final String prefKey;
  final T defaultValue;
  final EnumEncoder<T> encode;
  final EnumDecoder<T> decode;
  final ValueNotifier<T> current;

  Future<T> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = decode(prefs.getString(prefKey));
    current.value = value;
    return value;
  }

  Future<void> save(T value) async {
    current.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, encode(value));
  }
}
