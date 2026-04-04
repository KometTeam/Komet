class ChatFolder {
  final String id;
  final String title;
  final String? emoji;
  final List<int>? include;
  final List<dynamic> filters;
  final bool hideEmpty;
  final List<ChatFolderWidget> widgets;
  final List<int>? favorites;
  final Map<String, dynamic>? filterSubjects;
  final List<int>? options;

  ChatFolder({
    required this.id,
    required this.title,
    this.emoji,
    this.include,
    required this.filters,
    required this.hideEmpty,
    required this.widgets,
    this.favorites,
    this.filterSubjects,
    this.options,
  });

  factory ChatFolder.fromJson(Map<String, dynamic> json) {
    return ChatFolder(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? '',
      emoji: json['emoji']?.toString(),
      include: (json['include'] as List<dynamic>?)
          ?.map((e) {
            if (e is int) return e;
            if (e is String) return int.tryParse(e) ?? 0;
            return 0;
          })
          .toList(),
      filters:
          (json['filters'] as List<dynamic>?)
              ?.map((e) {
                if (e is int) return e;
                if (e is String) return int.tryParse(e) ?? e;
                return e;
              })
              .toList() ??
          [],
      hideEmpty: json['hideEmpty'] ?? false,
      widgets:
          (json['widgets'] as List<dynamic>?)
              ?.map((w) {
                if (w is Map<String, dynamic>) {
                  return ChatFolderWidget.fromJson(w);
                }
                return ChatFolderWidget.fromJson(
                  Map<String, dynamic>.from(w as Map),
                );
              })
              .toList() ??
          [],
      favorites: (json['favorites'] as List<dynamic>?)
          ?.map((e) {
            if (e is int) return e;
            if (e is String) return int.tryParse(e) ?? 0;
            return 0;
          })
          .toList(),
      filterSubjects: json['filterSubjects'] is Map<String, dynamic>
          ? json['filterSubjects'] as Map<String, dynamic>
          : (json['filterSubjects'] is Map
                ? Map<String, dynamic>.from(
                    (json['filterSubjects'] as Map).cast<dynamic, dynamic>(),
                  )
                : null),
      options: (json['options'] as List<dynamic>?)
          ?.map((e) {
            if (e is int) return e;
            if (e is String) return int.tryParse(e) ?? 0;
            return 0;
          })
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (emoji != null) 'emoji': emoji,
    if (include != null) 'include': include,
    'filters': filters,
    'hideEmpty': hideEmpty,
    'widgets': widgets.map((w) => w.toJson()).toList(),
    if (favorites != null) 'favorites': favorites,
    if (filterSubjects != null) 'filterSubjects': filterSubjects,
    if (options != null) 'options': options,
  };
}

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
