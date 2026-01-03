class KometPlugin {
  final String id;
  final String name;
  final String version;
  final String? description;
  final String? author;
  final String filePath;

  final Map<String, dynamic> overrideConstants;
  final List<PluginSection> settingsSections;
  final List<PluginSubsection> settingsSubsections;
  final Map<String, PluginScreen> replaceScreens;

  bool isEnabled;

  KometPlugin({
    required this.id,
    required this.name,
    required this.version,
    this.description,
    this.author,
    required this.filePath,
    this.overrideConstants = const {},
    this.settingsSections = const [],
    this.settingsSubsections = const [],
    this.replaceScreens = const {},
    this.isEnabled = true,
  });

  factory KometPlugin.fromJson(Map<String, dynamic> json, String filePath) {
    return KometPlugin(
      id: json['id'] ?? 'unknown',
      name: json['name'] ?? 'Без названия',
      version: json['version'] ?? '1.0.0',
      description: json['description'],
      author: json['author'],
      filePath: filePath,
      overrideConstants: Map<String, dynamic>.from(
        json['overrideConstants'] ?? {},
      ),
      settingsSections:
          (json['settingsSections'] as List?)
              ?.map((e) => PluginSection.fromJson(e))
              .toList() ??
          [],
      settingsSubsections:
          (json['settingsSubsections'] as List?)
              ?.map((e) => PluginSubsection.fromJson(e))
              .toList() ??
          [],
      replaceScreens:
          (json['replaceScreens'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, PluginScreen.fromJson(v)),
          ) ??
          {},
      isEnabled: json['isEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'description': description,
    'author': author,
    'overrideConstants': overrideConstants,
    'settingsSections': settingsSections.map((e) => e.toJson()).toList(),
    'settingsSubsections': settingsSubsections.map((e) => e.toJson()).toList(),
    'replaceScreens': replaceScreens.map((k, v) => MapEntry(k, v.toJson())),
    'isEnabled': isEnabled,
  };

  List<String> getSummary() {
    final summary = <String>[];

    if (settingsSections.isNotEmpty) {
      final names = settingsSections.map((s) => s.title).join(', ');
      summary.add('Добавляет разделы: $names');
    }

    if (settingsSubsections.isNotEmpty) {
      final names = settingsSubsections
          .map((s) => '${s.title} в ${_getScreenDisplayName(s.parentSection)}')
          .join(', ');
      summary.add('Добавляет подразделы: $names');
    }

    if (replaceScreens.isNotEmpty) {
      final names = replaceScreens.keys.map(_getScreenDisplayName).join(', ');
      summary.add('Заменяет экраны: $names');
    }

    if (overrideConstants.isNotEmpty) {
      summary.add('Изменяет ${overrideConstants.length} констант');
    }

    return summary;
  }

  static String _getScreenDisplayName(String screenId) {
    const screenNames = {
      'AboutScreen': 'О приложении',
      'CustomizationScreen': 'Кастомизация',
      'OptimizationScreen': 'Оптимизация',
      'PrivacyScreen': 'Приватность',
      'NotificationsScreen': 'Уведомления',
      'ChatsScreen': 'Список чатов',
      'ChatScreen': 'Экран чата',
      'ProfileScreen': 'Профиль',
      'SettingsScreen': 'Настройки',
    };
    return screenNames[screenId] ?? screenId;
  }
}

class PluginSection {
  final String id;
  final String title;
  final String? icon;
  final List<PluginItem> items;

  PluginSection({
    required this.id,
    required this.title,
    this.icon,
    this.items = const [],
  });

  factory PluginSection.fromJson(Map<String, dynamic> json) {
    return PluginSection(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      icon: json['icon'],
      items:
          (json['items'] as List?)
              ?.map((e) => PluginItem.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'icon': icon,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

class PluginSubsection {
  final String id;
  final String parentSection;
  final String title;
  final String? icon;
  final List<PluginItem> items;

  PluginSubsection({
    required this.id,
    required this.parentSection,
    required this.title,
    this.icon,
    this.items = const [],
  });

  factory PluginSubsection.fromJson(Map<String, dynamic> json) {
    return PluginSubsection(
      id: json['id'] ?? '',
      parentSection: json['parentSection'] ?? '',
      title: json['title'] ?? '',
      icon: json['icon'],
      items:
          (json['items'] as List?)
              ?.map((e) => PluginItem.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'parentSection': parentSection,
    'title': title,
    'icon': icon,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

enum PluginItemType { button, toggle, slider, text, divider, navigation }

class PluginItem {
  final PluginItemType type;
  final String? id;
  final String? title;
  final String? subtitle;
  final String? icon;
  final String? key;
  final dynamic defaultValue;
  final double? min;
  final double? max;
  final int? divisions;
  final PluginAction? action;
  final List<PluginItem>? children;

  PluginItem({
    required this.type,
    this.id,
    this.title,
    this.subtitle,
    this.icon,
    this.key,
    this.defaultValue,
    this.min,
    this.max,
    this.divisions,
    this.action,
    this.children,
  });

  factory PluginItem.fromJson(Map<String, dynamic> json) {
    return PluginItem(
      type: _parseType(json['type']),
      id: json['id'],
      title: json['title'],
      subtitle: json['subtitle'],
      icon: json['icon'],
      key: json['key'],
      defaultValue: json['defaultValue'],
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
      divisions: json['divisions'],
      action: json['action'] != null
          ? PluginAction.fromJson(json['action'])
          : null,
      children: (json['children'] as List?)
          ?.map((e) => PluginItem.fromJson(e))
          .toList(),
    );
  }

  static PluginItemType _parseType(String? type) {
    switch (type) {
      case 'button':
        return PluginItemType.button;
      case 'toggle':
        return PluginItemType.toggle;
      case 'slider':
        return PluginItemType.slider;
      case 'text':
        return PluginItemType.text;
      case 'divider':
        return PluginItemType.divider;
      case 'navigation':
        return PluginItemType.navigation;
      default:
        return PluginItemType.text;
    }
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'icon': icon,
    'key': key,
    'defaultValue': defaultValue,
    'min': min,
    'max': max,
    'divisions': divisions,
    'action': action?.toJson(),
    'children': children?.map((e) => e.toJson()).toList(),
  };
}

enum PluginActionType { setValue, callAction, openUrl, navigate }

class PluginAction {
  final PluginActionType type;
  final String target;
  final dynamic value;

  PluginAction({required this.type, required this.target, this.value});

  factory PluginAction.fromJson(Map<String, dynamic> json) {
    return PluginAction(
      type: _parseType(json['type']),
      target: json['target'] ?? '',
      value: json['value'],
    );
  }

  static PluginActionType _parseType(String? type) {
    switch (type) {
      case 'setValue':
        return PluginActionType.setValue;
      case 'callAction':
        return PluginActionType.callAction;
      case 'openUrl':
        return PluginActionType.openUrl;
      case 'navigate':
        return PluginActionType.navigate;
      default:
        return PluginActionType.callAction;
    }
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'target': target,
    'value': value,
  };
}

class PluginScreen {
  final String? title;
  final List<PluginScreenWidget> widgets;

  PluginScreen({this.title, this.widgets = const []});

  factory PluginScreen.fromJson(Map<String, dynamic> json) {
    return PluginScreen(
      title: json['title'],
      widgets:
          (json['widgets'] as List?)
              ?.map((e) => PluginScreenWidget.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'widgets': widgets.map((e) => e.toJson()).toList(),
  };
}

enum PluginWidgetType {
  text,
  button,
  image,
  container,
  column,
  row,
  list,
  card,
  divider,
  spacer,
  icon,
}

class PluginScreenWidget {
  final PluginWidgetType type;
  final Map<String, dynamic> properties;
  final List<PluginScreenWidget>? children;
  final PluginAction? onTap;

  PluginScreenWidget({
    required this.type,
    this.properties = const {},
    this.children,
    this.onTap,
  });

  factory PluginScreenWidget.fromJson(Map<String, dynamic> json) {
    return PluginScreenWidget(
      type: _parseType(json['type']),
      properties: Map<String, dynamic>.from(json['properties'] ?? {}),
      children: (json['children'] as List?)
          ?.map((e) => PluginScreenWidget.fromJson(e))
          .toList(),
      onTap: json['onTap'] != null
          ? PluginAction.fromJson(json['onTap'])
          : null,
    );
  }

  static PluginWidgetType _parseType(String? type) {
    switch (type) {
      case 'text':
        return PluginWidgetType.text;
      case 'button':
        return PluginWidgetType.button;
      case 'image':
        return PluginWidgetType.image;
      case 'container':
        return PluginWidgetType.container;
      case 'column':
        return PluginWidgetType.column;
      case 'row':
        return PluginWidgetType.row;
      case 'list':
        return PluginWidgetType.list;
      case 'card':
        return PluginWidgetType.card;
      case 'divider':
        return PluginWidgetType.divider;
      case 'spacer':
        return PluginWidgetType.spacer;
      case 'icon':
        return PluginWidgetType.icon;
      default:
        return PluginWidgetType.text;
    }
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'properties': properties,
    'children': children?.map((e) => e.toJson()).toList(),
    'onTap': onTap?.toJson(),
  };
}
