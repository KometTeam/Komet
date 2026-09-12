// #***! вид баннера, текст ссылка или обновление
abstract class BannerType {
  static const int text = 0;
  static const int link = 1;
  static const int update = 2;
}

// #***! битовые флаги поведения, одним числом в settings
abstract class BannerSettings {
  static const int textAnimation = 1;
  static const int hideCloseButton = 2;
  static const int hideOnClick = 4;
  static const int iconThemeColor = 8;
}

// #***! баннер сверху списка чатов
class InformerBanner {
  final String id;
  final String title;
  final String description;
  final int settings;
  final int priority;
  final int repeat;
  final int rerun;
  final int? animojiId;
  final String? url;
  final int type;

  const InformerBanner({
    required this.id,
    required this.title,
    this.description = '',
    this.settings = 0,
    this.priority = 0,
    this.repeat = 0,
    this.rerun = 0,
    this.animojiId,
    this.url,
    this.type = BannerType.text,
  });

  // #***! разбор битовой маски
  bool get animatesText => settings & BannerSettings.textAnimation != 0;
  bool get hidesCloseButton => settings & BannerSettings.hideCloseButton != 0;
  bool get closesOnClick => settings & BannerSettings.hideOnClick != 0;
  bool get tintsIconWithTheme =>
      settings & BannerSettings.iconThemeColor != 0;

  // #***! кликабельный, ссылка или обновление
  bool get isLink =>
      type == BannerType.link && url != null && url!.trim().isNotEmpty;
  bool get isUpdate => type == BannerType.update;
  bool get isClickable => isLink || isUpdate;

  // #***! без id или текста баннер бесполезен
  static InformerBanner? fromMap(Map<dynamic, dynamic> map) {
    final id = map['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final title = map['title']?.toString() ?? '';
    final description = map['description']?.toString() ?? '';
    if (title.isEmpty && description.isEmpty) return null;
    return InformerBanner(
      id: id,
      title: title,
      description: description,
      settings: _int(map['settings']) ?? 0,
      priority: _int(map['priority']) ?? 0,
      repeat: _int(map['repeat']) ?? 0,
      rerun: _int(map['rerun']) ?? 0,
      animojiId: _int(map['animojiId']),
      url: map['url']?.toString(),
      type: _int(map['type']) ?? BannerType.text,
    );
  }

  // #***! сохраняем локально чтоб показать до ответа сервера
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'settings': settings,
    'priority': priority,
    'repeat': repeat,
    'rerun': rerun,
    'animojiId': animojiId,
    'url': url,
    'type': type,
  };

  // #***! числа иногда строкой
  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

// #***! наша память по баннеру, сколько показали и когда закрыли
class BannerShowState {
  final int showCounter;
  final int? showAt;
  final int? closedAt;

  const BannerShowState({this.showCounter = 0, this.showAt, this.closedAt});

  BannerShowState copyWith({int? showCounter, int? showAt, int? closedAt}) =>
      BannerShowState(
        showCounter: showCounter ?? this.showCounter,
        showAt: showAt ?? this.showAt,
        closedAt: closedAt ?? this.closedAt,
      );

  // #***! closedTime исторический, трогать нельзя
  static BannerShowState fromJson(Map<dynamic, dynamic> map) => BannerShowState(
    showCounter: InformerBanner._int(map['showCounter']) ?? 0,
    showAt: InformerBanner._int(map['showAt']),
    closedAt: InformerBanner._int(map['closedTime']),
  );

  Map<String, dynamic> toJson() => {
    'showCounter': showCounter,
    'showAt': showAt,
    'closedTime': closedAt,
  };
}
