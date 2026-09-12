// #***! коды фильтров папки, числа но бывают строкой
class FolderFilter {
  static const int unread = 0;
  static const int read = 1;
  static const int channel = 2;
  static const int chat = 3;
  static const int dialog = 4;
  static const int owner = 5;
  static const int admin = 6;
  static const int muted = 7;
  static const int contact = 8;
  static const int notContact = 9;
  static const int bot = 10;
  static const int notMuted = 11;
  static const int markedUnread = 12;
  static const int org = 13;

  // #***! типы по или, остальное по и
  static const Set<int> chatTypes = {
    contact,
    notContact,
    chat,
    channel,
    bot,
    dialog,
    org,
  };

  static const Set<int> roles = {owner, admin};

  static const Set<int> showOnly = {
    unread,
    read,
    muted,
    notMuted,
    markedUnread,
  };

  static const Map<String, int> _byName = {
    'UNREAD': unread,
    'READ': read,
    'CHANNEL': channel,
    'CHAT': chat,
    'GROUP': chat,
    'DIALOG': dialog,
    'OWNER': owner,
    'ADMIN': admin,
    'MUTED': muted,
    'CONTACT': contact,
    'NOT_CONTACT': notContact,
    'BOT': bot,
    'NOT_MUTED': notMuted,
    'MARKED_UNREAD': markedUnread,
    'ORG': org,
  };

  // #***! принимаем и число, и строковое имя
  static int? parse(dynamic raw) {
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? _byName[raw];
    return null;
  }
}

// #***! флаги папки
class FolderOption {
  static const int hideEmpty = 0;
  static const int noDelete = 1;
  static const int noTitleEdit = 2;
  static const int noFiltersEdit = 3;
  static const int chatSuggest = 4;

  static const Map<String, int> _byName = {
    'HIDE_EMPTY': hideEmpty,
    'NO_DELETE': noDelete,
    'NO_TITLE_EDIT': noTitleEdit,
    'NO_FILTERS_EDIT': noFiltersEdit,
    'CHAT_SUGGEST': chatSuggest,
  };

  static int? parse(dynamic raw) {
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? _byName[raw];
    return null;
  }
}

// #***! папка чатов
class ChatFolder {
  final String id;
  final String title;
  final String? emoji;
  final List<int> include;
  final List<int> filters;
  final List<int> options;
  final List<int> favorites;
  final List<ChatFolderWidget> widgets;
  final Map<String, dynamic>? filterSubjects;
  final int updateTime;
  final int? sourceId;

  const ChatFolder({
    required this.id,
    required this.title,
    this.emoji,
    this.include = const [],
    this.filters = const [],
    this.options = const [],
    this.favorites = const [],
    this.widgets = const [],
    this.filterSubjects,
    this.updateTime = 0,
    this.sourceId,
  });

  // #***! обёртки над options для юишки
  bool get hideEmpty => options.contains(FolderOption.hideEmpty);

  bool get canDelete => !options.contains(FolderOption.noDelete);

  bool get canEditTitle => !options.contains(FolderOption.noTitleEdit);

  bool get canEditFilters => !options.contains(FolderOption.noFiltersEdit);

  // #***! приходит разнотипным, приводим аккуратно
  static List<int> _parseIds(dynamic raw) {
    if (raw is! List) return <int>[];
    return raw
        .map((e) {
          if (e is int) return e;
          if (e is String) return int.tryParse(e);
          return null;
        })
        .whereType<int>()
        .toList();
  }

  static List<int> _parseCodes(dynamic raw, int? Function(dynamic) parse) {
    if (raw is! List) return <int>[];
    return raw.map(parse).whereType<int>().toList();
  }

  static Map<String, dynamic>? _parseMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  // #***! hideEmpty раньше был отдельным полем
  factory ChatFolder.fromJson(Map<String, dynamic> json) {
    final options = _parseCodes(json['options'], FolderOption.parse);
    if (json['hideEmpty'] == true &&
        !options.contains(FolderOption.hideEmpty)) {
      options.add(FolderOption.hideEmpty);
    }
    return ChatFolder(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      emoji: json['emoji']?.toString(),
      include: _parseIds(json['include']),
      filters: _parseCodes(json['filters'], FolderFilter.parse),
      options: options,
      favorites: _parseIds(json['favorites']),
      widgets:
          (json['widgets'] as List<dynamic>?)
              ?.map(_parseMap)
              .whereType<Map<String, dynamic>>()
              .map(ChatFolderWidget.fromJson)
              .toList() ??
          const [],
      filterSubjects: _parseMap(json['filterSubjects']),
      updateTime: json['updateTime'] is int ? json['updateTime'] as int : 0,
      sourceId: json['sourceId'] is int ? json['sourceId'] as int : null,
    );
  }

  ChatFolder copyWith({
    String? title,
    String? emoji,
    List<int>? include,
    List<int>? filters,
    List<int>? options,
    List<int>? favorites,
    int? updateTime,
  }) => ChatFolder(
    id: id,
    title: title ?? this.title,
    emoji: emoji ?? this.emoji,
    include: include ?? this.include,
    filters: filters ?? this.filters,
    options: options ?? this.options,
    favorites: favorites ?? this.favorites,
    widgets: widgets,
    filterSubjects: filterSubjects,
    updateTime: updateTime ?? this.updateTime,
    sourceId: sourceId,
  );

  // #***! в этом же виде папка уходит на сервер
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (emoji != null) 'emoji': emoji,
    'include': include,
    'filters': filters,
    'options': options,
    'favorites': favorites,
    'widgets': widgets.map((w) => w.toJson()).toList(),
    if (filterSubjects != null) 'filterSubjects': filterSubjects,
    'updateTime': updateTime,
    if (sourceId != null) 'sourceId': sourceId,
  };
}

// #***! виджет мини аппы в папке
class ChatFolderWidget {
  final int id;
  final String name;
  final String description;
  final String? iconUrl;
  final String? url;
  final String? startParam;
  final String? background;
  final int? appId;

  ChatFolderWidget({
    required this.id,
    required this.name,
    required this.description,
    this.iconUrl,
    this.url,
    this.startParam,
    this.background,
    this.appId,
  });

  factory ChatFolderWidget.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return ChatFolderWidget(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      iconUrl: json['iconUrl']?.toString(),
      url: json['url']?.toString(),
      startParam: json['startParam']?.toString(),
      background: json['background']?.toString(),
      appId: json['appId'] is int
          ? json['appId'] as int
          : int.tryParse(json['appId']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    if (iconUrl != null) 'iconUrl': iconUrl,
    if (url != null) 'url': url,
    if (startParam != null) 'startParam': startParam,
    if (background != null) 'background': background,
    if (appId != null) 'appId': appId,
  };
}
