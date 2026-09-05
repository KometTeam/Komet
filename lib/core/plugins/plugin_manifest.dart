import 'dart:convert';

const int kPluginApiVersion = 1;
const String kPluginPackageExtension = '.kinet';

enum PluginPermission {
  chatWrite('chat.write', 'Отправка сообщений'),
  chatEdit('chat.edit', 'Редактирование отправленных сообщений'),
  uiNotify('ui.notify', 'Показ уведомлений'),
  contactRead('contact.read', 'Чтение данных собеседника'),
  replyRead(
    'message.readReply',
    'Чтение сообщения, на которое отвечает команда',
  ),
  network('network', 'Доступ к интернету'),
  photoWrite('chat.photo', 'Отправка фотографий'),
  fileWrite('chat.file', 'Отправка файлов'),
  storage('storage', 'Локальное хранилище плагина');

  const PluginPermission(this.id, this.label);

  final String id;
  final String label;

  static PluginPermission? fromId(String id) {
    for (final permission in values) {
      if (permission.id == id) return permission;
    }
    return null;
  }
}

class PluginCommandManifest {
  const PluginCommandManifest({
    required this.name,
    required this.description,
    required this.handler,
    this.arguments = const [],
    this.hidden = false,
  });

  final String name;
  final String description;
  final String handler;
  final List<PluginCommandArgumentManifest> arguments;
  final bool hidden;

  factory PluginCommandManifest.fromJson(Map<String, dynamic> json) {
    final rawName = _requiredString(json, 'name');
    final name = rawName.startsWith('/') ? rawName : '/$rawName';
    if (!RegExp(r'^/[A-Za-z][A-Za-z0-9_-]{0,31}$').hasMatch(name)) {
      throw const FormatException('Некорректное имя команды');
    }
    final handler = _requiredString(json, 'handler');
    if (!RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(handler)) {
      throw const FormatException('Некорректное имя обработчика');
    }
    final rawArguments = json['arguments'];
    final arguments = <PluginCommandArgumentManifest>[];
    if (rawArguments != null) {
      if (rawArguments is! List) {
        throw const FormatException('arguments должен быть массивом');
      }
      for (final raw in rawArguments) {
        if (raw is! Map) {
          throw const FormatException('Некорректный аргумент команды');
        }
        arguments.add(
          PluginCommandArgumentManifest.fromJson(
            Map<String, dynamic>.from(raw),
          ),
        );
      }
    }
    final argumentNames = <String>{};
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (!argumentNames.add(argument.name)) {
        throw FormatException('Аргумент ${argument.name} объявлен дважды');
      }
      if (argument.rest && index != arguments.length - 1) {
        throw const FormatException('rest-аргумент должен быть последним');
      }
    }
    return PluginCommandManifest(
      name: name,
      description: _requiredString(json, 'description'),
      handler: handler,
      arguments: List.unmodifiable(arguments),
      hidden: json['hidden'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'handler': handler,
    if (arguments.isNotEmpty)
      'arguments': arguments.map((argument) => argument.toJson()).toList(),
    if (hidden) 'hidden': true,
  };
}

class PluginCommandArgumentManifest {
  const PluginCommandArgumentManifest({
    required this.name,
    required this.description,
    required this.required,
    required this.rest,
  });

  final String name;
  final String description;
  final bool required;
  final bool rest;

  factory PluginCommandArgumentManifest.fromJson(Map<String, dynamic> json) {
    final name = _requiredString(json, 'name');
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_-]{0,31}$').hasMatch(name)) {
      throw const FormatException('Некорректное имя аргумента');
    }
    return PluginCommandArgumentManifest(
      name: name,
      description: _optionalString(json, 'description'),
      required: json['required'] != false,
      rest: json['rest'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'required': required,
    if (rest) 'rest': true,
  };
}

class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.apiVersion,
    required this.description,
    required this.author,
    required this.main,
    required this.permissions,
    required this.commands,
    this.updateUrl,
    this.signature,
  });

  final String id;
  final String name;
  final String version;
  final int apiVersion;
  final String description;
  final String author;
  final String main;
  final Set<PluginPermission> permissions;
  final List<PluginCommandManifest> commands;
  final Uri? updateUrl;
  final PluginSignatureManifest? signature;

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != 1) {
      throw const FormatException('Неподдерживаемая версия manifest');
    }
    final id = _requiredString(json, 'id');
    if (!RegExp(r'^[a-z][a-z0-9]*(?:\.[a-z0-9]+)+$').hasMatch(id)) {
      throw const FormatException('Некорректный id плагина');
    }
    final version = _requiredString(json, 'version');
    if (!RegExp(r'^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$').hasMatch(version)) {
      throw const FormatException('Некорректная версия плагина');
    }
    final apiVersion = json['apiVersion'];
    if (apiVersion is! int || apiVersion < 1) {
      throw const FormatException('Некорректная версия API');
    }
    if (apiVersion > kPluginApiVersion) {
      throw FormatException('Плагину требуется API $apiVersion');
    }
    final main = _safeRelativePath(_requiredString(json, 'main'));
    if (!main.endsWith('.js')) {
      throw const FormatException(
        'Главный модуль должен быть JavaScript-файлом',
      );
    }
    final rawPermissions = json['permissions'];
    if (rawPermissions is! List) {
      throw const FormatException('permissions должен быть массивом');
    }
    final permissions = <PluginPermission>{};
    for (final raw in rawPermissions) {
      if (raw is! String) {
        throw const FormatException('Некорректное разрешение');
      }
      final permission = PluginPermission.fromId(raw);
      if (permission == null) {
        throw FormatException('Неизвестное разрешение: $raw');
      }
      permissions.add(permission);
    }
    final rawCommands = json['commands'];
    if (rawCommands is! List || rawCommands.isEmpty) {
      throw const FormatException('Плагин должен содержать команды');
    }
    final commands = rawCommands
        .map((raw) {
          if (raw is! Map) {
            throw const FormatException('Некорректная команда');
          }
          return PluginCommandManifest.fromJson(Map<String, dynamic>.from(raw));
        })
        .toList(growable: false);
    final commandNames = <String>{};
    for (final command in commands) {
      if (!commandNames.add(command.name.toLowerCase())) {
        throw FormatException('Команда ${command.name} объявлена дважды');
      }
    }
    Uri? updateUrl;
    final rawUpdateUrl = json['updateUrl'];
    if (rawUpdateUrl != null) {
      if (rawUpdateUrl is! String) {
        throw const FormatException('Некорректный updateUrl');
      }
      updateUrl = Uri.tryParse(rawUpdateUrl.trim());
      if (updateUrl == null || updateUrl.scheme != 'https') {
        throw const FormatException('updateUrl должен использовать HTTPS');
      }
    }
    PluginSignatureManifest? signature;
    final rawSignature = json['signature'];
    if (rawSignature != null) {
      if (rawSignature is! Map) {
        throw const FormatException('Некорректная подпись плагина');
      }
      signature = PluginSignatureManifest.fromJson(
        Map<String, dynamic>.from(rawSignature),
      );
    }
    return PluginManifest(
      id: id,
      name: _requiredString(json, 'name'),
      version: version,
      apiVersion: apiVersion,
      description: _optionalString(json, 'description'),
      author: _optionalString(json, 'author'),
      main: main,
      permissions: Set.unmodifiable(permissions),
      commands: List.unmodifiable(commands),
      updateUrl: updateUrl,
      signature: signature,
    );
  }

  factory PluginManifest.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('manifest.json должен быть объектом');
    }
    return PluginManifest.fromJson(Map<String, dynamic>.from(decoded));
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'name': name,
    'version': version,
    'apiVersion': apiVersion,
    'description': description,
    'author': author,
    'main': main,
    'permissions': permissions.map((permission) => permission.id).toList(),
    'commands': commands.map((command) => command.toJson()).toList(),
    if (updateUrl != null) 'updateUrl': updateUrl.toString(),
    if (signature != null) 'signature': signature!.toJson(),
  };

  Map<String, dynamic> toUnsignedJson() {
    final json = toJson();
    json.remove('signature');
    return json;
  }
}

class PluginSignatureManifest {
  const PluginSignatureManifest({
    required this.algorithm,
    required this.publicKey,
    required this.value,
  });

  final String algorithm;
  final String publicKey;
  final String value;

  factory PluginSignatureManifest.fromJson(Map<String, dynamic> json) {
    final algorithm = _requiredString(json, 'algorithm');
    if (algorithm != 'ed25519') {
      throw FormatException('Неподдерживаемый алгоритм подписи: $algorithm');
    }
    return PluginSignatureManifest(
      algorithm: algorithm,
      publicKey: _requiredString(json, 'publicKey'),
      value: _requiredString(json, 'value'),
    );
  }

  Map<String, dynamic> toJson() => {
    'algorithm': algorithm,
    'publicKey': publicKey,
    'value': value,
  };
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Поле $key обязательно');
  }
  return value.trim();
}

String _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String ? value.trim() : '';
}

String _safeRelativePath(String path) {
  final normalized = path.replaceAll('\\', '/');
  if (normalized.startsWith('/') ||
      normalized.split('/').any((part) => part.isEmpty || part == '..')) {
    throw const FormatException('Некорректный путь в плагине');
  }
  return normalized;
}
