import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fjs/fjs.dart';
import 'package:path/path.dart' as p;

import 'plugin_host.dart';
import 'plugin_manifest.dart';
import 'plugin_models.dart';
import 'plugin_storage.dart';

class PluginRuntime {
  PluginRuntime._();

  static Future<void>? _initialization;

  static Future<void> initialize() => _initialization ??= LibFjs.init();

  static Future<void> run(
    PluginCommandDescriptor command,
    PluginHost host,
  ) async {
    await initialize();
    final plugin = command.plugin;
    final storage = PluginStorage(plugin.manifest.id);
    final sentMessageIds = <String>{};
    final engine = await JsEngine.create(
      builtins: JsBuiltinOptions.none(),
      runtimeOptions: JsEngineRuntimeOptions(
        memoryLimit: BigInt.from(16 * 1024 * 1024),
        gcThreshold: BigInt.from(4 * 1024 * 1024),
        maxStackSize: BigInt.from(256 * 1024),
        info: plugin.manifest.id,
      ),
    );
    var closed = false;
    Future<void> close() async {
      if (closed) return;
      closed = true;
      await engine.close();
    }

    try {
      await engine.init(
        bridge: (value) =>
            _bridge(plugin, host, storage, sentMessageIds, value),
      );
      await engine.declareNewModule(
        module: JsModule.code(module: 'komet:api', code: _apiModule),
      );
      final sources = await plugin.loadModules();
      final prefix = 'plugin:${plugin.manifest.id}/';
      await engine.declareNewModules(
        modules: sources.entries
            .map(
              (entry) => JsModule.code(
                module: '$prefix${entry.key}',
                code: _rewriteImports(entry.value, prefix, entry.key),
              ),
            )
            .toList(),
      );
      final moduleName = '$prefix${plugin.manifest.main}';
      final call = engine.call(
        module: moduleName,
        method: command.command.handler,
        params: [
          JsValue.from({
            'args': host.args,
            'arguments': host.arguments,
            'reply':
                plugin.grantedPermissions.contains(PluginPermission.replyRead)
                ? host.replyMessage
                : null,
            'apiVersion': kPluginApiVersion,
          }),
        ],
      );
      await call.timeout(
        const Duration(seconds: 30),
        onTimeout: () async {
          await close();
          throw TimeoutException('Плагин превысил лимит времени');
        },
      );
    } finally {
      await close();
    }
  }

  static Future<JsResult> _bridge(
    PluginDescriptor plugin,
    PluginHost host,
    PluginStorage storage,
    Set<String> sentMessageIds,
    JsValue value,
  ) async {
    try {
      final request = value.value;
      if (request is! Map) {
        throw const FormatException('Некорректный вызов API');
      }
      final method = request['method'];
      final args = request['args'];
      if (method is! String || args is! List) {
        throw const FormatException('Некорректный вызов API');
      }
      final Object? result;
      switch (method) {
        case 'chat.sendText':
          result = await _sendText(plugin, host, sentMessageIds, args);
        case 'chat.editText':
          await _editText(plugin, host, sentMessageIds, args);
          result = null;
        case 'chat.sendPhoto':
          await _sendPhoto(plugin, host, args);
          result = null;
        case 'chat.sendFile':
          await _sendFile(plugin, host, args);
          result = null;
        case 'ui.notify':
          await _notify(plugin, host, args);
          result = null;
        case 'contact.getPeer':
          result = await _getPeer(plugin, host);
        case 'runtime.sleep':
          await _sleep(args);
          result = null;
        case 'runtime.isOnline':
          result = host.isOnline;
        case 'runtime.isActive':
          result = host.isActive;
        case 'network.fetch':
          result = await _fetch(plugin, args);
        case 'storage.get':
          result = await _storageGet(plugin, storage, args);
        case 'storage.set':
          await _storageSet(plugin, storage, args);
          result = null;
        case 'storage.remove':
          await _storageRemove(plugin, storage, args);
          result = null;
        default:
          throw FormatException('Неизвестный метод API: $method');
      }
      return JsResult.ok(JsValue.from({'ok': true, 'value': result}));
    } catch (error) {
      return JsResult.ok(JsValue.from({'ok': false, 'error': '$error'}));
    }
  }

  static Future<String> _sendText(
    PluginDescriptor plugin,
    PluginHost host,
    Set<String> sentMessageIds,
    List<dynamic> args,
  ) async {
    _require(plugin, PluginPermission.chatWrite);
    final id = await host.sendText(_stringArg(args, 0));
    if (id.isNotEmpty) sentMessageIds.add(id);
    return id;
  }

  static Future<void> _editText(
    PluginDescriptor plugin,
    PluginHost host,
    Set<String> sentMessageIds,
    List<dynamic> args,
  ) {
    _require(plugin, PluginPermission.chatEdit);
    final messageId = _stringArg(args, 0);
    if (!sentMessageIds.contains(messageId)) {
      throw const FormatException(
        'Плагин может редактировать только созданные им сообщения',
      );
    }
    return host.editText(messageId, _stringArg(args, 1));
  }

  static Future<void> _notify(
    PluginDescriptor plugin,
    PluginHost host,
    List<dynamic> args,
  ) {
    _require(plugin, PluginPermission.uiNotify);
    return host.notify(_stringArg(args, 0));
  }

  static Future<void> _sendPhoto(
    PluginDescriptor plugin,
    PluginHost host,
    List<dynamic> args,
  ) async {
    _require(plugin, PluginPermission.photoWrite);
    final options = _mapArg(args, 0);
    final bytes = await _mediaBytes(
      plugin,
      options,
      maxBytes: 15 * 1024 * 1024,
    );
    await host.sendPhoto(
      bytes,
      filename: _filename(options, 'plugin_photo.jpg'),
      caption: options['caption']?.toString() ?? '',
    );
  }

  static Future<void> _sendFile(
    PluginDescriptor plugin,
    PluginHost host,
    List<dynamic> args,
  ) async {
    _require(plugin, PluginPermission.fileWrite);
    final options = _mapArg(args, 0);
    final bytes = await _mediaBytes(
      plugin,
      options,
      maxBytes: 25 * 1024 * 1024,
    );
    await host.sendFile(bytes, filename: _filename(options, 'plugin_file.bin'));
  }

  static Future<Map<String, dynamic>> _fetch(
    PluginDescriptor plugin,
    List<dynamic> args,
  ) async {
    _require(plugin, PluginPermission.network);
    final url = _stringArg(args, 0);
    final options = args.length > 1 && args[1] is Map
        ? Map<String, dynamic>.from(args[1] as Map)
        : const <String, dynamic>{};
    final uri = _httpsUri(url);
    final method = (options['method']?.toString() ?? 'GET').toUpperCase();
    if (!const {'GET', 'POST', 'PUT', 'PATCH', 'DELETE'}.contains(method)) {
      throw const FormatException('Неподдерживаемый HTTP-метод');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.openUrl(method, uri);
      request.followRedirects = false;
      final rawHeaders = options['headers'];
      if (rawHeaders is Map) {
        rawHeaders.forEach((key, value) {
          final name = key.toString();
          if (_forbiddenHeader(name)) return;
          request.headers.set(name, value.toString());
        });
      }
      final body = options['body'];
      if (body != null) request.write(body.toString());
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.isRedirect) {
        await response.drain<void>();
        throw const HttpException('HTTP redirects are disabled for plugins');
      }
      final bytes = await _readLimited(response, 1024 * 1024);
      final headers = <String, String>{};
      response.headers.forEach((name, values) {
        headers[name] = values.join(', ');
      });
      return {
        'status': response.statusCode,
        'headers': headers,
        'body': utf8.decode(bytes, allowMalformed: true),
        'base64': base64Encode(bytes),
      };
    } finally {
      client.close(force: true);
    }
  }

  static Future<Uint8List> _mediaBytes(
    PluginDescriptor plugin,
    Map<String, dynamic> options, {
    required int maxBytes,
  }) async {
    final encoded = options['base64'];
    if (encoded is String && encoded.isNotEmpty) {
      final bytes = base64Decode(encoded);
      if (bytes.length > maxBytes) {
        throw const FormatException('Файл слишком большой');
      }
      return bytes;
    }
    final url = options['url'];
    if (url is! String || url.isEmpty) {
      throw const FormatException('Нужно указать url или base64');
    }
    _require(plugin, PluginPermission.network);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(_httpsUri(url));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.isRedirect) {
        await response.drain<void>();
        throw const HttpException('HTTP redirects are disabled for plugins');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        throw HttpException('HTTP ${response.statusCode}');
      }
      return _readLimited(response, maxBytes);
    } finally {
      client.close(force: true);
    }
  }

  static Future<Uint8List> _readLimited(
    HttpClientResponse response,
    int maxBytes,
  ) async {
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 20))) {
      bytes.addAll(chunk);
      if (bytes.length > maxBytes) {
        throw const FormatException('Ответ слишком большой');
      }
    }
    return Uint8List.fromList(bytes);
  }

  static Uri _httpsUri(String source) {
    final uri = Uri.tryParse(source);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Разрешены только корректные HTTPS URL');
    }
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host.endsWith('.localhost')) {
      throw const FormatException('Локальные адреса запрещены');
    }
    final address = InternetAddress.tryParse(host);
    if (address != null && _isPrivateAddress(address)) {
      throw const FormatException('Локальные адреса запрещены');
    }
    return uri;
  }

  static bool _isPrivateAddress(InternetAddress address) {
    if (address.isLoopback || address.isLinkLocal) return true;
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      return bytes[0] == 10 ||
          bytes[0] == 127 ||
          bytes[0] == 0 ||
          (bytes[0] == 169 && bytes[1] == 254) ||
          (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
          (bytes[0] == 192 && bytes[1] == 168);
    }
    return bytes.every((byte) => byte == 0) ||
        (bytes[0] & 0xfe) == 0xfc ||
        (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80);
  }

  static bool _forbiddenHeader(String name) {
    final lower = name.toLowerCase();
    return lower == 'host' ||
        lower == 'content-length' ||
        lower == 'connection' ||
        lower == 'proxy-authorization';
  }

  static Map<String, dynamic> _mapArg(List<dynamic> args, int index) {
    if (index >= args.length || args[index] is! Map) {
      throw const FormatException('Ожидался объект');
    }
    return Map<String, dynamic>.from(args[index] as Map);
  }

  static String _filename(Map<String, dynamic> options, String fallback) {
    final raw = options['filename']?.toString().trim() ?? '';
    final value = raw.isEmpty ? fallback : raw;
    return value
        .replaceAll(RegExp(r'[^A-Za-zА-Яа-яЁё0-9._ -]'), '_')
        .substring(0, value.length > 120 ? 120 : value.length);
  }

  static Future<Map<String, dynamic>?> _getPeer(
    PluginDescriptor plugin,
    PluginHost host,
  ) {
    _require(plugin, PluginPermission.contactRead);
    return host.getPeer();
  }

  static Future<void> _sleep(List<dynamic> args) async {
    final value = args.isEmpty ? null : args.first;
    if (value is! num || value < 0 || value > 10000) {
      throw const FormatException('Некорректная задержка');
    }
    await Future.delayed(Duration(milliseconds: value.round()));
  }

  static Future<Object?> _storageGet(
    PluginDescriptor plugin,
    PluginStorage storage,
    List<dynamic> args,
  ) {
    _require(plugin, PluginPermission.storage);
    return storage.get(_storageKey(args));
  }

  static Future<void> _storageSet(
    PluginDescriptor plugin,
    PluginStorage storage,
    List<dynamic> args,
  ) {
    _require(plugin, PluginPermission.storage);
    if (args.length < 2) throw const FormatException('Не задано значение');
    return storage.set(_storageKey(args), args[1]);
  }

  static Future<void> _storageRemove(
    PluginDescriptor plugin,
    PluginStorage storage,
    List<dynamic> args,
  ) {
    _require(plugin, PluginPermission.storage);
    return storage.remove(_storageKey(args));
  }

  static void _require(PluginDescriptor plugin, PluginPermission permission) {
    if (!plugin.grantedPermissions.contains(permission)) {
      throw FormatException('Нет разрешения ${permission.id}');
    }
  }

  static String _stringArg(List<dynamic> args, int index) {
    if (index >= args.length || args[index] is! String) {
      throw const FormatException('Ожидалась строка');
    }
    final value = args[index] as String;
    if (value.length > 65536) {
      throw const FormatException('Строка слишком длинная');
    }
    return value;
  }

  static String _storageKey(List<dynamic> args) {
    final key = _stringArg(args, 0);
    if (!RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(key)) {
      throw const FormatException('Некорректный ключ хранилища');
    }
    return key;
  }

  static String _rewriteImports(
    String source,
    String prefix,
    String modulePath,
  ) {
    return source.replaceAllMapped(
      RegExp(r'''(from\s+|import\s+|import\s*\()(['"])(\.?\.?/[^'"]+)\2'''),
      (match) {
        final relative = match.group(3)!;
        final resolved = p.posix.normalize(
          p.posix.join(p.posix.dirname(modulePath), relative),
        );
        if (resolved == '..' || resolved.startsWith('../')) {
          throw const FormatException('Импорт за пределы плагина запрещён');
        }
        return '${match.group(1)}${match.group(2)}$prefix$resolved${match.group(2)}';
      },
    );
  }

  static const String _apiModule = '''
const call = async (method, args = []) => {
  const response = await fjs.bridge_call({ method, args });
  if (!response.ok) throw new Error(response.error || 'Komet API error');
  return response.value;
};
export const chat = Object.freeze({
  sendText: text => call('chat.sendText', [text]),
  editText: (messageId, text) => call('chat.editText', [messageId, text]),
  sendPhoto: options => call('chat.sendPhoto', [options]),
  sendFile: options => call('chat.sendFile', [options])
});
export const ui = Object.freeze({ notify: message => call('ui.notify', [message]) });
export const contact = Object.freeze({ getPeer: () => call('contact.getPeer') });
export const runtime = Object.freeze({
  sleep: milliseconds => call('runtime.sleep', [milliseconds]),
  isOnline: () => call('runtime.isOnline'),
  isActive: () => call('runtime.isActive')
});
export const network = Object.freeze({
  fetch: (url, options = {}) => call('network.fetch', [url, options])
});
export const storage = Object.freeze({
  get: key => call('storage.get', [key]),
  set: (key, value) => call('storage.set', [key, value]),
  remove: key => call('storage.remove', [key])
});
''';
}
