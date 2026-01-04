import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum AppTheme { system, light, dark, black }

enum ChatWallpaperType { komet, solid, gradient, image, video }

enum FolderTabsBackgroundType { none, gradient, image }

enum DrawerBackgroundType { none, gradient, image }

enum ChatsListBackgroundType { none, gradient, image }

enum AppBarBackgroundType { none, gradient, image }

enum TransitionOption { systemDefault, slide }

enum UIMode { both, burgerOnly, panelOnly }

enum MessageBubbleType { solid }

enum ChatPreviewMode { twoLine, threeLine, noNicknames }

extension MessageBubbleTypeExtension on MessageBubbleType {
  String get displayName {
    switch (this) {
      case MessageBubbleType.solid:
        return 'Цвет';
    }
  }
}

extension TransitionOptionExtension on TransitionOption {
  String get displayName {
    switch (this) {
      case TransitionOption.systemDefault:
        return 'Default';
      case TransitionOption.slide:
        return 'Slide';
    }
  }
}

extension ChatWallpaperTypeExtension on ChatWallpaperType {
  String get displayName {
    switch (this) {
      case ChatWallpaperType.komet:
        return 'Komet';
      case ChatWallpaperType.solid:
        return 'Цвет';
      case ChatWallpaperType.gradient:
        return 'Градиент';
      case ChatWallpaperType.image:
        return 'Фото';
      case ChatWallpaperType.video:
        return 'Видео';
    }
  }
}

extension FolderTabsBackgroundTypeExtension on FolderTabsBackgroundType {
  String get displayName {
    switch (this) {
      case FolderTabsBackgroundType.none:
        return 'Нет';
      case FolderTabsBackgroundType.gradient:
        return 'Градиент';
      case FolderTabsBackgroundType.image:
        return 'Фото';
    }
  }
}

extension DrawerBackgroundTypeExtension on DrawerBackgroundType {
  String get displayName {
    switch (this) {
      case DrawerBackgroundType.none:
        return 'Нет';
      case DrawerBackgroundType.gradient:
        return 'Градиент';
      case DrawerBackgroundType.image:
        return 'Фото';
    }
  }
}

extension ChatsListBackgroundTypeExtension on ChatsListBackgroundType {
  String get displayName {
    switch (this) {
      case ChatsListBackgroundType.none:
        return 'Нет';
      case ChatsListBackgroundType.gradient:
        return 'Градиент';
      case ChatsListBackgroundType.image:
        return 'Фото';
    }
  }
}

extension AppBarBackgroundTypeExtension on AppBarBackgroundType {
  String get displayName {
    switch (this) {
      case AppBarBackgroundType.none:
        return 'Нет';
      case AppBarBackgroundType.gradient:
        return 'Градиент';
      case AppBarBackgroundType.image:
        return 'Фото';
    }
  }
}

class CustomThemePreset {
  String id;
  String name;

  AppTheme appTheme;
  Color accentColor;

  bool useCustomChatWallpaper;
  ChatWallpaperType chatWallpaperType;
  Color chatWallpaperColor1;
  Color chatWallpaperColor2;
  String? chatWallpaperImagePath;
  String? chatWallpaperVideoPath;
  bool chatWallpaperBlur;
  double chatWallpaperBlurSigma;
  double chatWallpaperImageBlur;

  bool useGlassPanels;
  double topBarBlur;
  double topBarOpacity;
  double bottomBarBlur;
  double bottomBarOpacity;

  double messageMenuOpacity;
  double messageMenuBlur;
  double profileDialogBlur;
  double profileDialogOpacity;

  UIMode uiMode;
  bool showSeconds;
  double messageBubbleOpacity;
  String messageStyle;
  double messageBackgroundBlur;
  double messageTextOpacity;
  double messageShadowIntensity;
  double messageBorderRadius;

  double messageFontSize;
  Color? myBubbleColorLight;
  Color? theirBubbleColorLight;
  Color? myBubbleColorDark;
  Color? theirBubbleColorDark;
  MessageBubbleType messageBubbleType;
  bool sendOnEnter;

  TransitionOption chatTransition;
  TransitionOption tabTransition;
  TransitionOption messageTransition;
  TransitionOption extraTransition;
  double messageSlideDistance;
  double extraAnimationStrength;
  bool animatePhotoMessages;
  bool optimizeChats;
  bool ultraOptimizeChats;
  bool useDesktopLayout;
  bool useAutoReplyColor;
  Color? customReplyColor;

  bool useGradientForChatsList;
  ChatsListBackgroundType chatsListBackgroundType;
  String? chatsListImagePath;
  bool useGradientForDrawer;
  DrawerBackgroundType drawerBackgroundType;
  String? drawerImagePath;
  bool useGradientForAddAccountButton;
  bool useGradientForAppBar;
  AppBarBackgroundType appBarBackgroundType;
  String? appBarImagePath;
  bool useGradientForFolderTabs;
  FolderTabsBackgroundType folderTabsBackgroundType;
  String? folderTabsImagePath;
  Color chatsListGradientColor1;
  Color chatsListGradientColor2;
  Color drawerGradientColor1;
  Color drawerGradientColor2;
  Color addAccountButtonGradientColor1;
  Color addAccountButtonGradientColor2;
  Color appBarGradientColor1;
  Color appBarGradientColor2;
  Color folderTabsGradientColor1;
  Color folderTabsGradientColor2;

  CustomThemePreset({
    required this.id,
    required this.name,
    this.appTheme = AppTheme.dark,
    this.accentColor = Colors.blue,
    this.useCustomChatWallpaper = false,
    this.chatWallpaperType = ChatWallpaperType.komet,
    this.chatWallpaperColor1 = const Color(0xFF101010),
    this.chatWallpaperColor2 = const Color(0xFF202020),
    this.chatWallpaperImagePath,
    this.chatWallpaperVideoPath,
    this.chatWallpaperBlur = false,
    this.chatWallpaperBlurSigma = 12.0,
    this.chatWallpaperImageBlur = 0.0,
    this.useGlassPanels = true,
    this.topBarBlur = 10.0,
    this.topBarOpacity = 0.6,
    this.bottomBarBlur = 10.0,
    this.bottomBarOpacity = 0.7,
    this.messageMenuOpacity = 0.95,
    this.messageMenuBlur = 4.0,
    this.profileDialogBlur = 12.0,
    this.profileDialogOpacity = 0.26,
    this.uiMode = UIMode.both,
    this.showSeconds = false,
    this.messageBubbleOpacity = 0.12,
    this.messageStyle = 'glass',
    this.messageBackgroundBlur = 0.0,
    this.messageTextOpacity = 1.0,
    this.messageShadowIntensity = 0.1,
    this.messageBorderRadius = 20.0,
    this.messageFontSize = 16.0,
    this.myBubbleColorLight,
    this.theirBubbleColorLight,
    this.myBubbleColorDark,
    this.theirBubbleColorDark,
    this.messageBubbleType = MessageBubbleType.solid,
    this.sendOnEnter = false,
    this.chatTransition = TransitionOption.systemDefault,
    this.tabTransition = TransitionOption.systemDefault,
    this.messageTransition = TransitionOption.systemDefault,
    this.extraTransition = TransitionOption.systemDefault,
    this.messageSlideDistance = 96.0,
    this.extraAnimationStrength = 32.0,
    this.animatePhotoMessages = false,
    this.optimizeChats = false,
    this.ultraOptimizeChats = false,
    this.useDesktopLayout = true,
    this.useAutoReplyColor = true,
    this.customReplyColor,
    this.useGradientForChatsList = false,
    this.chatsListBackgroundType = ChatsListBackgroundType.none,
    this.chatsListImagePath,
    this.useGradientForDrawer = false,
    this.drawerBackgroundType = DrawerBackgroundType.none,
    this.drawerImagePath,
    this.useGradientForAddAccountButton = false,
    this.useGradientForAppBar = false,
    this.appBarBackgroundType = AppBarBackgroundType.none,
    this.appBarImagePath,
    this.useGradientForFolderTabs = false,
    this.folderTabsBackgroundType = FolderTabsBackgroundType.none,
    this.folderTabsImagePath,
    this.chatsListGradientColor1 = const Color(0xFF1E1E1E),
    this.chatsListGradientColor2 = const Color(0xFF2D2D2D),
    this.drawerGradientColor1 = const Color(0xFF1E1E1E),
    this.drawerGradientColor2 = const Color(0xFF2D2D2D),
    this.addAccountButtonGradientColor1 = const Color(0xFF1E1E1E),
    this.addAccountButtonGradientColor2 = const Color(0xFF2D2D2D),
    this.appBarGradientColor1 = const Color(0xFF1E1E1E),
    this.appBarGradientColor2 = const Color(0xFF2D2D2D),
    this.folderTabsGradientColor1 = const Color(0xFF1E1E1E),
    this.folderTabsGradientColor2 = const Color(0xFF2D2D2D),
  });

  factory CustomThemePreset.createDefault() {
    return CustomThemePreset(
      id: 'default',
      name: 'По умолчанию',
      appTheme: AppTheme.system, // Material You по умолчанию
    );
  }

  CustomThemePreset copyWith({
    String? id,
    String? name,
    AppTheme? appTheme,
    Color? accentColor,
    bool? useCustomChatWallpaper,
    ChatWallpaperType? chatWallpaperType,
    Color? chatWallpaperColor1,
    Color? chatWallpaperColor2,
    String? chatWallpaperImagePath,
    String? chatWallpaperVideoPath,
    bool? chatWallpaperBlur,
    double? chatWallpaperBlurSigma,
    double? chatWallpaperImageBlur,
    bool? useGlassPanels,
    double? topBarBlur,
    double? topBarOpacity,
    double? bottomBarBlur,
    double? bottomBarOpacity,
    double? messageMenuOpacity,
    double? messageMenuBlur,
    double? profileDialogBlur,
    double? profileDialogOpacity,
    UIMode? uiMode,
    bool? showSeconds,
    double? messageBubbleOpacity,
    String? messageStyle,
    double? messageBackgroundBlur,
    double? messageTextOpacity,
    double? messageShadowIntensity,
    double? messageBorderRadius,
    double? messageFontSize,
    Color? myBubbleColorLight,
    Color? theirBubbleColorLight,
    Color? myBubbleColorDark,
    Color? theirBubbleColorDark,
    MessageBubbleType? messageBubbleType,
    bool? sendOnEnter,
    TransitionOption? chatTransition,
    TransitionOption? tabTransition,
    TransitionOption? messageTransition,
    TransitionOption? extraTransition,
    double? messageSlideDistance,
    double? extraAnimationStrength,
    bool? animatePhotoMessages,
    bool? optimizeChats,
    bool? ultraOptimizeChats,
    bool? useDesktopLayout,
    bool? useAutoReplyColor,
    Color? customReplyColor,
    bool? useGradientForChatsList,
    ChatsListBackgroundType? chatsListBackgroundType,
    String? chatsListImagePath,
    bool? useGradientForDrawer,
    DrawerBackgroundType? drawerBackgroundType,
    String? drawerImagePath,
    bool? useGradientForAddAccountButton,
    bool? useGradientForAppBar,
    AppBarBackgroundType? appBarBackgroundType,
    String? appBarImagePath,
    bool? useGradientForFolderTabs,
    FolderTabsBackgroundType? folderTabsBackgroundType,
    String? folderTabsImagePath,
    Color? chatsListGradientColor1,
    Color? chatsListGradientColor2,
    Color? drawerGradientColor1,
    Color? drawerGradientColor2,
    Color? addAccountButtonGradientColor1,
    Color? addAccountButtonGradientColor2,
    Color? appBarGradientColor1,
    Color? appBarGradientColor2,
    Color? folderTabsGradientColor1,
    Color? folderTabsGradientColor2,
  }) {
    return CustomThemePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      appTheme: appTheme ?? this.appTheme,
      accentColor: accentColor ?? this.accentColor,
      useCustomChatWallpaper:
          useCustomChatWallpaper ?? this.useCustomChatWallpaper,
      chatWallpaperType: chatWallpaperType ?? this.chatWallpaperType,
      chatWallpaperColor1: chatWallpaperColor1 ?? this.chatWallpaperColor1,
      chatWallpaperColor2: chatWallpaperColor2 ?? this.chatWallpaperColor2,
      chatWallpaperImagePath:
          chatWallpaperImagePath ?? this.chatWallpaperImagePath,
      chatWallpaperVideoPath:
          chatWallpaperVideoPath ?? this.chatWallpaperVideoPath,
      chatWallpaperBlur: chatWallpaperBlur ?? this.chatWallpaperBlur,
      chatWallpaperBlurSigma:
          chatWallpaperBlurSigma ?? this.chatWallpaperBlurSigma,
      chatWallpaperImageBlur:
          chatWallpaperImageBlur ?? this.chatWallpaperImageBlur,
      useGlassPanels: useGlassPanels ?? this.useGlassPanels,
      topBarBlur: topBarBlur ?? this.topBarBlur,
      topBarOpacity: topBarOpacity ?? this.topBarOpacity,
      bottomBarBlur: bottomBarBlur ?? this.bottomBarBlur,
      bottomBarOpacity: bottomBarOpacity ?? this.bottomBarOpacity,
      messageMenuOpacity: messageMenuOpacity ?? this.messageMenuOpacity,
      messageMenuBlur: messageMenuBlur ?? this.messageMenuBlur,
      profileDialogBlur: profileDialogBlur ?? this.profileDialogBlur,
      profileDialogOpacity: profileDialogOpacity ?? this.profileDialogOpacity,
      uiMode: uiMode ?? this.uiMode,
      showSeconds: showSeconds ?? this.showSeconds,
      messageBubbleOpacity: messageBubbleOpacity ?? this.messageBubbleOpacity,
      messageStyle: messageStyle ?? this.messageStyle,
      messageBackgroundBlur:
          messageBackgroundBlur ?? this.messageBackgroundBlur,
      messageTextOpacity: messageTextOpacity ?? this.messageTextOpacity,
      messageShadowIntensity:
          messageShadowIntensity ?? this.messageShadowIntensity,
      messageBorderRadius: messageBorderRadius ?? this.messageBorderRadius,
      messageFontSize: messageFontSize ?? this.messageFontSize,
      myBubbleColorLight: myBubbleColorLight ?? this.myBubbleColorLight,
      theirBubbleColorLight:
          theirBubbleColorLight ?? this.theirBubbleColorLight,
      myBubbleColorDark: myBubbleColorDark ?? this.myBubbleColorDark,
      theirBubbleColorDark: theirBubbleColorDark ?? this.theirBubbleColorDark,
      messageBubbleType: messageBubbleType ?? this.messageBubbleType,
      sendOnEnter: sendOnEnter ?? this.sendOnEnter,
      chatTransition: chatTransition ?? this.chatTransition,
      tabTransition: tabTransition ?? this.tabTransition,
      messageTransition: messageTransition ?? this.messageTransition,
      extraTransition: extraTransition ?? this.extraTransition,
      messageSlideDistance: messageSlideDistance ?? this.messageSlideDistance,
      extraAnimationStrength:
          extraAnimationStrength ?? this.extraAnimationStrength,
      animatePhotoMessages: animatePhotoMessages ?? this.animatePhotoMessages,
      optimizeChats: optimizeChats ?? this.optimizeChats,
      ultraOptimizeChats: ultraOptimizeChats ?? this.ultraOptimizeChats,
      useDesktopLayout: useDesktopLayout ?? this.useDesktopLayout,
      useAutoReplyColor: useAutoReplyColor ?? this.useAutoReplyColor,
      customReplyColor: customReplyColor ?? this.customReplyColor,
      useGradientForChatsList:
          useGradientForChatsList ?? this.useGradientForChatsList,
      chatsListBackgroundType:
          chatsListBackgroundType ?? this.chatsListBackgroundType,
      chatsListImagePath: chatsListImagePath ?? this.chatsListImagePath,
      useGradientForDrawer: useGradientForDrawer ?? this.useGradientForDrawer,
      drawerBackgroundType: drawerBackgroundType ?? this.drawerBackgroundType,
      drawerImagePath: drawerImagePath ?? this.drawerImagePath,
      useGradientForAddAccountButton:
          useGradientForAddAccountButton ?? this.useGradientForAddAccountButton,
      useGradientForAppBar: useGradientForAppBar ?? this.useGradientForAppBar,
      appBarBackgroundType: appBarBackgroundType ?? this.appBarBackgroundType,
      appBarImagePath: appBarImagePath ?? this.appBarImagePath,
      useGradientForFolderTabs:
          useGradientForFolderTabs ?? this.useGradientForFolderTabs,
      folderTabsBackgroundType:
          folderTabsBackgroundType ?? this.folderTabsBackgroundType,
      folderTabsImagePath: folderTabsImagePath ?? this.folderTabsImagePath,
      chatsListGradientColor1:
          chatsListGradientColor1 ?? this.chatsListGradientColor1,
      chatsListGradientColor2:
          chatsListGradientColor2 ?? this.chatsListGradientColor2,
      drawerGradientColor1: drawerGradientColor1 ?? this.drawerGradientColor1,
      drawerGradientColor2: drawerGradientColor2 ?? this.drawerGradientColor2,
      addAccountButtonGradientColor1:
          addAccountButtonGradientColor1 ?? this.addAccountButtonGradientColor1,
      addAccountButtonGradientColor2:
          addAccountButtonGradientColor2 ?? this.addAccountButtonGradientColor2,
      appBarGradientColor1: appBarGradientColor1 ?? this.appBarGradientColor1,
      appBarGradientColor2: appBarGradientColor2 ?? this.appBarGradientColor2,
      folderTabsGradientColor1:
          folderTabsGradientColor1 ?? this.folderTabsGradientColor1,
      folderTabsGradientColor2:
          folderTabsGradientColor2 ?? this.folderTabsGradientColor2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'appTheme': appTheme.index,
      'accentColor': accentColor.toARGB32(),
      'useCustomChatWallpaper': useCustomChatWallpaper,
      'chatWallpaperType': chatWallpaperType.index,
      'chatWallpaperColor1': chatWallpaperColor1.toARGB32(),
      'chatWallpaperColor2': chatWallpaperColor2.toARGB32(),
      'chatWallpaperImagePath': chatWallpaperImagePath,
      'chatWallpaperVideoPath': chatWallpaperVideoPath,
      'chatWallpaperBlur': chatWallpaperBlur,
      'chatWallpaperBlurSigma': chatWallpaperBlurSigma,
      'chatWallpaperImageBlur': chatWallpaperImageBlur,
      'useGlassPanels': useGlassPanels,
      'topBarBlur': topBarBlur,
      'topBarOpacity': topBarOpacity,
      'bottomBarBlur': bottomBarBlur,
      'bottomBarOpacity': bottomBarOpacity,
      'messageMenuOpacity': messageMenuOpacity,
      'messageMenuBlur': messageMenuBlur,
      'profileDialogBlur': profileDialogBlur,
      'profileDialogOpacity': profileDialogOpacity,
      'uiMode': uiMode.index,
      'showSeconds': showSeconds,
      'messageBubbleOpacity': messageBubbleOpacity,
      'messageStyle': messageStyle,
      'messageBackgroundBlur': messageBackgroundBlur,
      'messageTextOpacity': messageTextOpacity,
      'messageShadowIntensity': messageShadowIntensity,
      'messageBorderRadius': messageBorderRadius,
      'messageFontSize': messageFontSize,
      'myBubbleColorLight': myBubbleColorLight?.toARGB32(),
      'theirBubbleColorLight': theirBubbleColorLight?.toARGB32(),
      'myBubbleColorDark': myBubbleColorDark?.toARGB32(),
      'theirBubbleColorDark': theirBubbleColorDark?.toARGB32(),
      'messageBubbleType': messageBubbleType.index,
      'sendOnEnter': sendOnEnter,
      'chatTransition': chatTransition.index,
      'tabTransition': tabTransition.index,
      'messageTransition': messageTransition.index,
      'extraTransition': extraTransition.index,
      'messageSlideDistance': messageSlideDistance,
      'extraAnimationStrength': extraAnimationStrength,
      'animatePhotoMessages': animatePhotoMessages,
      'optimizeChats': optimizeChats,
      'ultraOptimizeChats': ultraOptimizeChats,
      'useDesktopLayout': useDesktopLayout,
      'useAutoReplyColor': useAutoReplyColor,
      'customReplyColor': customReplyColor?.toARGB32(),
      'useGradientForChatsList': useGradientForChatsList,
      'chatsListBackgroundType': chatsListBackgroundType.index,
      'chatsListImagePath': chatsListImagePath,
      'useGradientForDrawer': useGradientForDrawer,
      'drawerBackgroundType': drawerBackgroundType.index,
      'drawerImagePath': drawerImagePath,
      'useGradientForAddAccountButton': useGradientForAddAccountButton,
      'useGradientForAppBar': useGradientForAppBar,
      'appBarBackgroundType': appBarBackgroundType.index,
      'appBarImagePath': appBarImagePath,
      'useGradientForFolderTabs': useGradientForFolderTabs,
      'folderTabsBackgroundType': folderTabsBackgroundType.index,
      'folderTabsImagePath': folderTabsImagePath,
      'chatsListGradientColor1': chatsListGradientColor1.toARGB32(),
      'chatsListGradientColor2': chatsListGradientColor2.toARGB32(),
      'drawerGradientColor1': drawerGradientColor1.toARGB32(),
      'drawerGradientColor2': drawerGradientColor2.toARGB32(),
      'addAccountButtonGradientColor1': addAccountButtonGradientColor1
          .toARGB32(),
      'addAccountButtonGradientColor2': addAccountButtonGradientColor2
          .toARGB32(),
      'appBarGradientColor1': appBarGradientColor1.toARGB32(),
      'appBarGradientColor2': appBarGradientColor2.toARGB32(),
      'folderTabsGradientColor1': folderTabsGradientColor1.toARGB32(),
      'folderTabsGradientColor2': folderTabsGradientColor2.toARGB32(),
    };
  }

  factory CustomThemePreset.fromJson(Map<String, dynamic> json) {
    final int appThemeIndex =
        (json['appTheme'] as int?) ?? AppTheme.system.index;
    final AppTheme parsedTheme =
        (appThemeIndex >= 0 && appThemeIndex < AppTheme.values.length)
        ? AppTheme.values[appThemeIndex]
        : AppTheme.system;
    return CustomThemePreset(
      id: json['id'] as String,
      name: json['name'] as String,
      appTheme: parsedTheme,
      accentColor: Color(json['accentColor'] as int? ?? Colors.blue.toARGB32()),
      useCustomChatWallpaper: json['useCustomChatWallpaper'] as bool? ?? false,
      chatWallpaperType:
          ChatWallpaperType.values[json['chatWallpaperType'] as int? ?? 0],
      chatWallpaperColor1: Color(
        json['chatWallpaperColor1'] as int? ??
            const Color(0xFF101010).toARGB32(),
      ),
      chatWallpaperColor2: Color(
        json['chatWallpaperColor2'] as int? ??
            const Color(0xFF202020).toARGB32(),
      ),
      chatWallpaperImagePath: json['chatWallpaperImagePath'] as String?,
      chatWallpaperVideoPath: json['chatWallpaperVideoPath'] as String?,
      chatWallpaperBlur: json['chatWallpaperBlur'] as bool? ?? false,
      chatWallpaperBlurSigma:
          (json['chatWallpaperBlurSigma'] as double? ?? 12.0).clamp(0.0, 20.0),
      chatWallpaperImageBlur: (json['chatWallpaperImageBlur'] as double? ?? 0.0)
          .clamp(0.0, 10.0),
      useGlassPanels: json['useGlassPanels'] as bool? ?? true,
      topBarBlur: json['topBarBlur'] as double? ?? 10.0,
      topBarOpacity: json['topBarOpacity'] as double? ?? 0.6,
      bottomBarBlur: json['bottomBarBlur'] as double? ?? 10.0,
      bottomBarOpacity: json['bottomBarOpacity'] as double? ?? 0.7,
      messageMenuOpacity: json['messageMenuOpacity'] as double? ?? 0.95,
      messageMenuBlur: json['messageMenuBlur'] as double? ?? 4.0,
      profileDialogBlur: (json['profileDialogBlur'] as double? ?? 12.0).clamp(
        0.0,
        30.0,
      ),
      profileDialogOpacity: (json['profileDialogOpacity'] as double? ?? 0.26)
          .clamp(0.0, 1.0),
      uiMode: UIMode.values[json['uiMode'] as int? ?? 0],
      showSeconds: json['showSeconds'] as bool? ?? false,
      messageBubbleOpacity: (json['messageBubbleOpacity'] as double? ?? 0.12)
          .clamp(0.0, 1.0),
      messageStyle: json['messageStyle'] as String? ?? 'glass',
      messageBackgroundBlur: (json['messageBackgroundBlur'] as double? ?? 0.0)
          .clamp(0.0, 10.0),
      messageTextOpacity: (json['messageTextOpacity'] as double? ?? 1.0).clamp(
        0.1,
        1.0,
      ),
      messageShadowIntensity: (json['messageShadowIntensity'] as double? ?? 0.1)
          .clamp(0.0, 0.5),
      messageBorderRadius: (json['messageBorderRadius'] as double? ?? 20.0)
          .clamp(4.0, 50.0),
      messageFontSize: json['messageFontSize'] as double? ?? 16.0,
      myBubbleColorLight: json['myBubbleColorLight'] != null
          ? Color(json['myBubbleColorLight'] as int)
          : null,
      theirBubbleColorLight: json['theirBubbleColorLight'] != null
          ? Color(json['theirBubbleColorLight'] as int)
          : null,
      myBubbleColorDark: json['myBubbleColorDark'] != null
          ? Color(json['myBubbleColorDark'] as int)
          : null,
      theirBubbleColorDark: json['theirBubbleColorDark'] != null
          ? Color(json['theirBubbleColorDark'] as int)
          : null,
      messageBubbleType: () {
        final bubbleTypeIndex = json['messageBubbleType'] as int?;
        if (bubbleTypeIndex == null) {
          return MessageBubbleType.solid;
        }
        if (bubbleTypeIndex >= MessageBubbleType.values.length) {
          return MessageBubbleType.solid;
        }
        return MessageBubbleType.values[bubbleTypeIndex];
      }(),
      sendOnEnter: json['sendOnEnter'] as bool? ?? false,
      chatTransition:
          TransitionOption.values[json['chatTransition'] as int? ?? 0],
      tabTransition:
          TransitionOption.values[json['tabTransition'] as int? ?? 0],
      messageTransition:
          TransitionOption.values[json['messageTransition'] as int? ?? 0],
      extraTransition:
          TransitionOption.values[json['extraTransition'] as int? ?? 0],
      messageSlideDistance: (json['messageSlideDistance'] as double? ?? 96.0)
          .clamp(1.0, 200.0),
      extraAnimationStrength:
          (json['extraAnimationStrength'] as double? ?? 32.0).clamp(1.0, 400.0),
      animatePhotoMessages: json['animatePhotoMessages'] as bool? ?? false,
      optimizeChats: json['optimizeChats'] as bool? ?? false,
      ultraOptimizeChats: json['ultraOptimizeChats'] as bool? ?? false,
      useDesktopLayout: json['useDesktopLayout'] as bool? ?? false,
      useAutoReplyColor: json['useAutoReplyColor'] as bool? ?? true,
      customReplyColor: json['customReplyColor'] != null
          ? Color(json['customReplyColor'] as int)
          : null,
      useGradientForChatsList:
          json['useGradientForChatsList'] as bool? ?? false,
      chatsListBackgroundType: ChatsListBackgroundType
          .values[json['chatsListBackgroundType'] as int? ?? 0],
      chatsListImagePath: json['chatsListImagePath'] as String?,
      useGradientForDrawer: json['useGradientForDrawer'] as bool? ?? false,
      drawerBackgroundType: DrawerBackgroundType
          .values[json['drawerBackgroundType'] as int? ?? 0],
      drawerImagePath: json['drawerImagePath'] as String?,
      useGradientForAddAccountButton:
          json['useGradientForAddAccountButton'] as bool? ?? false,
      useGradientForAppBar: json['useGradientForAppBar'] as bool? ?? false,
      appBarBackgroundType: AppBarBackgroundType
          .values[json['appBarBackgroundType'] as int? ?? 0],
      appBarImagePath: json['appBarImagePath'] as String?,
      useGradientForFolderTabs:
          json['useGradientForFolderTabs'] as bool? ?? false,
      folderTabsBackgroundType: FolderTabsBackgroundType
          .values[json['folderTabsBackgroundType'] as int? ?? 0],
      folderTabsImagePath: json['folderTabsImagePath'] as String?,
      chatsListGradientColor1: Color(
        json['chatsListGradientColor1'] as int? ??
            const Color(0xFF1E1E1E).toARGB32(),
      ),
      chatsListGradientColor2: Color(
        json['chatsListGradientColor2'] as int? ??
            const Color(0xFF2D2D2D).toARGB32(),
      ),
      drawerGradientColor1: Color(
        json['drawerGradientColor1'] as int? ??
            const Color(0xFF1E1E1E).toARGB32(),
      ),
      drawerGradientColor2: Color(
        json['drawerGradientColor2'] as int? ??
            const Color(0xFF2D2D2D).toARGB32(),
      ),
      addAccountButtonGradientColor1: Color(
        json['addAccountButtonGradientColor1'] as int? ??
            const Color(0xFF1E1E1E).toARGB32(),
      ),
      addAccountButtonGradientColor2: Color(
        json['addAccountButtonGradientColor2'] as int? ??
            const Color(0xFF2D2D2D).toARGB32(),
      ),
      appBarGradientColor1: Color(
        json['appBarGradientColor1'] as int? ??
            const Color(0xFF1E1E1E).toARGB32(),
      ),
      appBarGradientColor2: Color(
        json['appBarGradientColor2'] as int? ??
            const Color(0xFF2D2D2D).toARGB32(),
      ),
      folderTabsGradientColor1: Color(
        json['folderTabsGradientColor1'] as int? ??
            const Color(0xFF1E1E1E).toARGB32(),
      ),
      folderTabsGradientColor2: Color(
        json['folderTabsGradientColor2'] as int? ??
            const Color(0xFF2D2D2D).toARGB32(),
      ),
    );
  }
}

class ThemeProvider with ChangeNotifier {
  CustomThemePreset _activeTheme = CustomThemePreset.createDefault();
  List<CustomThemePreset> _savedThemes = [];

  Color? _myBubbleColorLight;
  Color? _theirBubbleColorLight;
  Color? _myBubbleColorDark;
  Color? _theirBubbleColorDark;

  final Map<int, String> _chatSpecificWallpapers = {};

  bool _debugShowPerformanceOverlay = false;
  bool _debugShowChatsRefreshPanel = false;
  bool _debugShowMessageCount = false;
  bool _debugReadOnEnter = true;
  bool _debugReadOnAction = true;

  bool _blockBypass = false;
  bool _highQualityPhotos = true;
  ChatPreviewMode _chatPreviewMode = ChatPreviewMode.twoLine;
  bool _optimization = false;
  bool _showFpsOverlay = false;
  int _maxFrameRate = 60;

  CustomThemePreset? _savedThemeBeforeOptimization;
  AppTheme _lastNonSystemTheme = AppTheme.dark;

  AppTheme get appTheme => _activeTheme.appTheme;
  AppTheme get lastNonSystemTheme => _lastNonSystemTheme;
  Color get accentColor => _activeTheme.accentColor;

  ThemeMode get themeMode {
    switch (_activeTheme.appTheme) {
      case AppTheme.system:
        return ThemeMode.system;
      case AppTheme.light:
        return ThemeMode.light;
      case AppTheme.dark:
      case AppTheme.black:
        return ThemeMode.dark;
    }
  }

  bool get useCustomChatWallpaper => _activeTheme.useCustomChatWallpaper;
  ChatWallpaperType get chatWallpaperType => _activeTheme.chatWallpaperType;
  Color get chatWallpaperColor1 => _activeTheme.chatWallpaperColor1;
  Color get chatWallpaperColor2 => _activeTheme.chatWallpaperColor2;
  String? get chatWallpaperImagePath => _activeTheme.chatWallpaperImagePath;
  String? get chatWallpaperVideoPath => _activeTheme.chatWallpaperVideoPath;
  bool get chatWallpaperBlur => _activeTheme.chatWallpaperBlur;
  double get chatWallpaperBlurSigma => _activeTheme.chatWallpaperBlurSigma;
  double get chatWallpaperImageBlur => _activeTheme.chatWallpaperImageBlur;

  bool get useGlassPanels =>
      _optimization ? false : _activeTheme.useGlassPanels;
  double get topBarBlur => _activeTheme.topBarBlur;
  double get topBarOpacity => _activeTheme.topBarOpacity;
  double get bottomBarBlur => _activeTheme.bottomBarBlur;
  double get bottomBarOpacity => _activeTheme.bottomBarOpacity;

  double get messageMenuOpacity => _activeTheme.messageMenuOpacity;
  double get messageMenuBlur => _activeTheme.messageMenuBlur;

  double get profileDialogBlur => _activeTheme.profileDialogBlur;
  double get profileDialogOpacity => _activeTheme.profileDialogOpacity;

  UIMode get uiMode => _activeTheme.uiMode;
  bool get showSeconds => _activeTheme.showSeconds;
  double get messageBubbleOpacity => _activeTheme.messageBubbleOpacity;
  String get messageStyle => _activeTheme.messageStyle;
  double get messageBackgroundBlur => _activeTheme.messageBackgroundBlur;
  double get messageTextOpacity => _activeTheme.messageTextOpacity;
  double get messageShadowIntensity => _activeTheme.messageShadowIntensity;
  double get messageBorderRadius => _activeTheme.messageBorderRadius;

  double get messageFontSize => _activeTheme.messageFontSize;
  bool get sendOnEnter => _activeTheme.sendOnEnter;

  MessageBubbleType get messageBubbleType => _activeTheme.messageBubbleType;

  Color? get myBubbleColorLight => _myBubbleColorLight;
  Color? get theirBubbleColorLight => _theirBubbleColorLight;
  Color? get myBubbleColorDark => _myBubbleColorDark;
  Color? get theirBubbleColorDark => _theirBubbleColorDark;

  Color? get myBubbleColor {
    if (appTheme == AppTheme.light) return _myBubbleColorLight;
    if (appTheme == AppTheme.dark || appTheme == AppTheme.black) {
      return _myBubbleColorDark;
    }
    return null;
  }

  Color? get theirBubbleColor {
    if (appTheme == AppTheme.light) return _theirBubbleColorLight;
    if (appTheme == AppTheme.dark || appTheme == AppTheme.black) {
      return _theirBubbleColorDark;
    }
    return null;
  }

  bool get debugShowBottomBar =>
      _activeTheme.uiMode == UIMode.both ||
      _activeTheme.uiMode == UIMode.panelOnly;
  bool get debugShowBurgerMenu =>
      _activeTheme.uiMode == UIMode.both ||
      _activeTheme.uiMode == UIMode.burgerOnly;
  bool get debugShowPerformanceOverlay => _debugShowPerformanceOverlay;
  bool get debugShowChatsRefreshPanel => _debugShowChatsRefreshPanel;
  bool get debugShowMessageCount => _debugShowMessageCount;
  bool get debugReadOnEnter => _debugReadOnEnter;
  bool get debugReadOnAction => _debugReadOnAction;

  TransitionOption get chatTransition =>
      (_optimization || _activeTheme.ultraOptimizeChats)
      ? TransitionOption.systemDefault
      : _activeTheme.chatTransition;
  TransitionOption get tabTransition =>
      (_optimization || _activeTheme.ultraOptimizeChats)
      ? TransitionOption.systemDefault
      : _activeTheme.tabTransition;
  TransitionOption get messageTransition =>
      (_optimization || _activeTheme.ultraOptimizeChats)
      ? TransitionOption.systemDefault
      : _activeTheme.messageTransition;
  TransitionOption get extraTransition =>
      (_optimization || _activeTheme.ultraOptimizeChats)
      ? TransitionOption.systemDefault
      : _activeTheme.extraTransition;
  double get messageSlideDistance => _activeTheme.messageSlideDistance;
  double get extraAnimationStrength => _activeTheme.extraAnimationStrength;
  bool get animatePhotoMessages =>
      (_optimization || _activeTheme.ultraOptimizeChats)
      ? false
      : _activeTheme.animatePhotoMessages;
  bool get optimizeChats => _activeTheme.optimizeChats;
  bool get ultraOptimizeChats => _activeTheme.ultraOptimizeChats;
  bool get useDesktopLayout => _activeTheme.useDesktopLayout;
  bool get useAutoReplyColor => _activeTheme.useAutoReplyColor;
  Color? get customReplyColor => _activeTheme.customReplyColor;
  bool get useGradientForChatsList => _activeTheme.useGradientForChatsList;
  ChatsListBackgroundType get chatsListBackgroundType =>
      _activeTheme.chatsListBackgroundType;
  String? get chatsListImagePath => _activeTheme.chatsListImagePath;
  bool get useGradientForDrawer => _activeTheme.useGradientForDrawer;
  DrawerBackgroundType get drawerBackgroundType =>
      _activeTheme.drawerBackgroundType;
  String? get drawerImagePath => _activeTheme.drawerImagePath;
  bool get useGradientForAddAccountButton =>
      _activeTheme.useGradientForAddAccountButton;
  bool get useGradientForAppBar => _activeTheme.useGradientForAppBar;
  AppBarBackgroundType get appBarBackgroundType =>
      _activeTheme.appBarBackgroundType;
  String? get appBarImagePath => _activeTheme.appBarImagePath;
  bool get useGradientForFolderTabs => _activeTheme.useGradientForFolderTabs;
  FolderTabsBackgroundType get folderTabsBackgroundType =>
      _activeTheme.folderTabsBackgroundType;
  String? get folderTabsImagePath => _activeTheme.folderTabsImagePath;
  Color get chatsListGradientColor1 => _activeTheme.chatsListGradientColor1;
  Color get chatsListGradientColor2 => _activeTheme.chatsListGradientColor2;
  Color get drawerGradientColor1 => _activeTheme.drawerGradientColor1;
  Color get drawerGradientColor2 => _activeTheme.drawerGradientColor2;
  Color get addAccountButtonGradientColor1 =>
      _activeTheme.addAccountButtonGradientColor1;
  Color get addAccountButtonGradientColor2 =>
      _activeTheme.addAccountButtonGradientColor2;
  Color get appBarGradientColor1 => _activeTheme.appBarGradientColor1;
  Color get appBarGradientColor2 => _activeTheme.appBarGradientColor2;
  Color get folderTabsGradientColor1 => _activeTheme.folderTabsGradientColor1;
  Color get folderTabsGradientColor2 => _activeTheme.folderTabsGradientColor2;
  bool get highQualityPhotos => _highQualityPhotos;
  bool get blockBypass => _blockBypass;
  ChatPreviewMode get chatPreviewMode => _chatPreviewMode;
  bool get optimization => _optimization;
  bool get showFpsOverlay => _showFpsOverlay;
  int get maxFrameRate => _maxFrameRate;

  List<CustomThemePreset> get savedThemes => _savedThemes;
  CustomThemePreset get activeTheme => _activeTheme;

  ThemeProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final themesJson = prefs.getStringList('saved_themes') ?? [];
    _savedThemes = themesJson
        .map((jsonString) {
          try {
            return CustomThemePreset.fromJson(jsonDecode(jsonString));
          } catch (e) {
            print('Ошибка загрузки темы: $e');
            return null;
          }
        })
        .whereType<CustomThemePreset>()
        .toList();

    if (_savedThemes.isEmpty) {
      _savedThemes.add(CustomThemePreset.createDefault());
    }

    final activeId =
        prefs.getString('active_theme_id') ?? _savedThemes.first.id;

    _activeTheme = _savedThemes.firstWhere(
      (t) => t.id == activeId,
      orElse: () => _savedThemes.first,
    );

    if (_savedThemes.length == 1 &&
        _activeTheme.id == 'default' &&
        _activeTheme.appTheme != AppTheme.system) {
      _activeTheme = _activeTheme.copyWith(appTheme: AppTheme.system);
      await _saveActiveTheme();
    }

    final int storedLastNonSystemIndex =
        prefs.getInt('last_non_system_theme') ?? AppTheme.dark.index;
    final AppTheme storedLastNonSystemTheme =
        (storedLastNonSystemIndex >= 0 &&
            storedLastNonSystemIndex < AppTheme.values.length)
        ? AppTheme.values[storedLastNonSystemIndex]
        : AppTheme.dark;
    _lastNonSystemTheme = storedLastNonSystemTheme == AppTheme.system
        ? AppTheme.dark
        : storedLastNonSystemTheme;

    if (_activeTheme.appTheme != AppTheme.system) {
      _lastNonSystemTheme = _activeTheme.appTheme;
      await prefs.setInt('last_non_system_theme', _lastNonSystemTheme.index);
    }

    if (_activeTheme.myBubbleColorLight == null ||
        _activeTheme.theirBubbleColorLight == null ||
        _activeTheme.myBubbleColorDark == null ||
        _activeTheme.theirBubbleColorDark == null) {
      _updateBubbleColorsFromAccent(_activeTheme.accentColor);
      _activeTheme = _activeTheme.copyWith(
        myBubbleColorLight: _myBubbleColorLight,
        theirBubbleColorLight: _theirBubbleColorLight,
        myBubbleColorDark: _myBubbleColorDark,
        theirBubbleColorDark: _theirBubbleColorDark,
      );
      await _saveActiveTheme();
    } else {
      _myBubbleColorLight = _activeTheme.myBubbleColorLight;
      _theirBubbleColorLight = _activeTheme.theirBubbleColorLight;
      _myBubbleColorDark = _activeTheme.myBubbleColorDark;
      _theirBubbleColorDark = _activeTheme.theirBubbleColorDark;
    }

    _debugShowPerformanceOverlay = prefs.getBool('debug_perf_overlay') ?? false;
    _debugShowChatsRefreshPanel =
        prefs.getBool('debug_show_chats_refresh_panel') ?? false;
    _debugShowMessageCount = prefs.getBool('debug_show_message_count') ?? false;
    _debugReadOnEnter = prefs.getBool('debug_read_on_enter') ?? true;
    _debugReadOnAction = prefs.getBool('debug_read_on_action') ?? true;
    _highQualityPhotos = prefs.getBool('high_quality_photos') ?? true;
    _blockBypass = prefs.getBool('block_bypass') ?? false;
    _chatPreviewMode =
        ChatPreviewMode.values[prefs.getInt('chat_preview_mode') ?? 0];
    _optimization = prefs.getBool('optimization') ?? false;
    _showFpsOverlay = prefs.getBool('show_fps_overlay') ?? false;
    _maxFrameRate = prefs.getInt('max_frame_rate') ?? 60;

    await loadChatSpecificWallpapers();

    notifyListeners();
  }

  Future<void> _saveThemeListToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themesJson = _savedThemes
        .map((theme) => jsonEncode(theme.toJson()))
        .toList();
    await prefs.setStringList('saved_themes', themesJson);
  }

  Future<void> _saveActiveTheme() async {
    final index = _savedThemes.indexWhere((t) => t.id == _activeTheme.id);
    if (index != -1) {
      _savedThemes[index] = _activeTheme;
    } else {
      _savedThemes.add(_activeTheme);
    }
    await _saveThemeListToPrefs();
  }

  Future<void> applyTheme(String themeId) async {
    final themeToApply = _savedThemes.firstWhere((t) => t.id == themeId);
    _activeTheme = themeToApply;

    _myBubbleColorLight = _activeTheme.myBubbleColorLight;
    _theirBubbleColorLight = _activeTheme.theirBubbleColorLight;
    _myBubbleColorDark = _activeTheme.myBubbleColorDark;
    _theirBubbleColorDark = _activeTheme.theirBubbleColorDark;

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_theme_id', themeId);
  }

  Future<void> saveCurrentThemeAs(String name) async {
    final newTheme = _activeTheme.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Новая тема' : name.trim(),
    );

    _savedThemes.add(newTheme);
    await _saveThemeListToPrefs();
    await applyTheme(newTheme.id);
  }

  Future<void> deleteTheme(String themeId) async {
    if (themeId == 'default') return;
    _savedThemes.removeWhere((t) => t.id == themeId);

    if (_activeTheme.id == themeId) {
      await applyTheme('default');
    } else {
      await _saveThemeListToPrefs();
      notifyListeners();
    }
  }

  Future<void> renameTheme(String themeId, String newName) async {
    if (themeId == 'default') return;

    final index = _savedThemes.indexWhere((t) => t.id == themeId);
    if (index != -1) {
      final String finalName = newName.trim().isEmpty
          ? _savedThemes[index].name
          : newName.trim();
      _savedThemes[index] = _savedThemes[index].copyWith(name: finalName);

      if (_activeTheme.id == themeId) {
        _activeTheme = _activeTheme.copyWith(name: finalName);
      }

      await _saveThemeListToPrefs();
      notifyListeners();
    }
  }

  Future<bool> importThemeFromJson(String jsonString) async {
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);

      if (!jsonMap.containsKey('id') || !jsonMap.containsKey('name')) {
        debugPrint("Ошибка импорта: JSON не содержит ключи 'id' или 'name'.");
        return false;
      }

      final importedPreset = CustomThemePreset.fromJson(jsonMap);

      final newPreset = importedPreset.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: "Импорт: ${importedPreset.name}",
      );

      _savedThemes.add(newPreset);
      await _saveThemeListToPrefs();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Ошибка импорта темы: $e");
      return false;
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    _activeTheme = _activeTheme.copyWith(appTheme: theme);

    if (theme != AppTheme.system) {
      _lastNonSystemTheme = theme;
      _updateBubbleColorsFromAccent(_activeTheme.accentColor);
      _activeTheme = _activeTheme.copyWith(
        myBubbleColorLight: _myBubbleColorLight,
        theirBubbleColorLight: _theirBubbleColorLight,
        myBubbleColorDark: _myBubbleColorDark,
        theirBubbleColorDark: _theirBubbleColorDark,
      );
    }

    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (theme != AppTheme.system) {
      await prefs.setInt('last_non_system_theme', _lastNonSystemTheme.index);
    }
    await _saveActiveTheme();
  }

  Future<void> setMaterialYouEnabled(bool enabled) async {
    if (enabled) {
      await setTheme(AppTheme.system);
      return;
    }

    final fallback = (_lastNonSystemTheme == AppTheme.system)
        ? AppTheme.dark
        : _lastNonSystemTheme;
    await setTheme(fallback);
  }

  Future<void> setAccentColor(Color color) async {
    _updateBubbleColorsFromAccent(color);
    _activeTheme = _activeTheme.copyWith(
      accentColor: color,
      myBubbleColorLight: _myBubbleColorLight,
      theirBubbleColorLight: _theirBubbleColorLight,
      myBubbleColorDark: _myBubbleColorDark,
      theirBubbleColorDark: _theirBubbleColorDark,
    );
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> updateBubbleColorsForSystemTheme(Color systemAccentColor) async {
    _updateBubbleColorsFromAccent(systemAccentColor);
    notifyListeners();
  }

  void _updateBubbleColorsFromAccent(Color accent) {
    final Color myColorDark = accent;

    final hslDark = HSLColor.fromColor(accent);
    final double theirSatDark = (hslDark.saturation * 0.4).clamp(0.0, 1.0);
    final double theirLightDark = (hslDark.lightness * 0.7).clamp(0.1, 0.85);
    final Color theirColorDark = HSLColor.fromAHSL(
      hslDark.alpha,
      hslDark.hue,
      theirSatDark,
      theirLightDark,
    ).toColor();

    final hslLight = HSLColor.fromColor(accent);

    final double myLightSat = (hslLight.saturation * 0.6).clamp(0.3, 0.7);
    final double myLightLight = (hslLight.lightness * 0.3 + 0.6).clamp(
      0.6,
      0.9,
    );
    final Color myColorLight = HSLColor.fromAHSL(
      hslLight.alpha,
      hslLight.hue,
      myLightSat,
      myLightLight,
    ).toColor();

    final Color theirColorLight = const Color(0xFF464646);

    if (_myBubbleColorLight == myColorLight &&
        _theirBubbleColorLight == theirColorLight &&
        _myBubbleColorDark == myColorDark &&
        _theirBubbleColorDark == theirColorDark) {
      return;
    }

    _myBubbleColorLight = myColorLight;
    _theirBubbleColorLight = theirColorLight;
    _myBubbleColorDark = myColorDark;
    _theirBubbleColorDark = theirColorDark;
  }

  Future<void> setUseGlassPanels(bool value) async {
    _activeTheme = _activeTheme.copyWith(useGlassPanels: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setTopBarBlur(double value) async {
    _activeTheme = _activeTheme.copyWith(topBarBlur: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setTopBarOpacity(double value) async {
    _activeTheme = _activeTheme.copyWith(topBarOpacity: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setBottomBarBlur(double value) async {
    _activeTheme = _activeTheme.copyWith(bottomBarBlur: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setBottomBarOpacity(double value) async {
    _activeTheme = _activeTheme.copyWith(bottomBarOpacity: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setMessageFontSize(double value) async {
    _activeTheme = _activeTheme.copyWith(messageFontSize: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setMyBubbleColorLight(Color? color) async {
    _myBubbleColorLight = color;
    _activeTheme = _activeTheme.copyWith(myBubbleColorLight: color);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setTheirBubbleColorLight(Color? color) async {
    _theirBubbleColorLight = color;
    _activeTheme = _activeTheme.copyWith(theirBubbleColorLight: color);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setMyBubbleColorDark(Color? color) async {
    _myBubbleColorDark = color;
    _activeTheme = _activeTheme.copyWith(myBubbleColorDark: color);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setTheirBubbleColorDark(Color? color) async {
    _theirBubbleColorDark = color;
    _activeTheme = _activeTheme.copyWith(theirBubbleColorDark: color);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setMessageBubbleType(MessageBubbleType value) async {
    _activeTheme = _activeTheme.copyWith(messageBubbleType: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setSendOnEnter(bool value) async {
    _activeTheme = _activeTheme.copyWith(sendOnEnter: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setUseCustomChatWallpaper(bool value) async {
    _activeTheme = _activeTheme.copyWith(useCustomChatWallpaper: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setChatWallpaperType(ChatWallpaperType type) async {
    _activeTheme = _activeTheme.copyWith(chatWallpaperType: type);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setChatWallpaperColor1(Color color) async {
    _activeTheme = _activeTheme.copyWith(chatWallpaperColor1: color);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setChatWallpaperColor2(Color color) async {
    _activeTheme = _activeTheme.copyWith(chatWallpaperColor2: color);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setChatWallpaperImagePath(String? path) async {
    _activeTheme = _activeTheme.copyWith(chatWallpaperImagePath: path);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setChatWallpaperVideoPath(String? path) async {
    _activeTheme = _activeTheme.copyWith(chatWallpaperVideoPath: path);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setProfileDialogBlur(double value) async {
    _activeTheme = _activeTheme.copyWith(
      profileDialogBlur: value.clamp(0.0, 30.0),
    );
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setProfileDialogOpacity(double value) async {
    _activeTheme = _activeTheme.copyWith(
      profileDialogOpacity: value.clamp(0.0, 1.0),
    );
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setChatWallpaperBlur(bool value) async {
    _activeTheme = _activeTheme.copyWith(chatWallpaperBlur: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setChatWallpaperBlurSigma(double value) async {
    _activeTheme = _activeTheme.copyWith(
      chatWallpaperBlurSigma: value.clamp(0.0, 20.0),
    );
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setChatWallpaperImageBlur(double value) async {
    _activeTheme = _activeTheme.copyWith(
      chatWallpaperImageBlur: value.clamp(0.0, 10.0),
    );
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> resetChatWallpaperToDefaults() async {
    _activeTheme = _activeTheme.copyWith(
      useCustomChatWallpaper: false,
      chatWallpaperType: ChatWallpaperType.komet,
      chatWallpaperColor1: const Color(0xFF101010),
      chatWallpaperColor2: const Color(0xFF202020),
      chatWallpaperImagePath: null,
      chatWallpaperBlur: false,
      chatWallpaperImageBlur: 0.0,
    );
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setChatSpecificWallpaper(int chatId, String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) {
      _chatSpecificWallpapers.remove(chatId);
    } else {
      _chatSpecificWallpapers[chatId] = imagePath;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_wallpaper_$chatId';
    if (imagePath == null || imagePath.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, imagePath);
    }
  }

  String? getChatSpecificWallpaper(int chatId) {
    return _chatSpecificWallpapers[chatId];
  }

  bool hasChatSpecificWallpaper(int chatId) {
    return _chatSpecificWallpapers.containsKey(chatId) &&
        _chatSpecificWallpapers[chatId] != null &&
        _chatSpecificWallpapers[chatId]!.isNotEmpty;
  }

  Future<void> loadChatSpecificWallpapers() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    _chatSpecificWallpapers.clear();

    for (final key in keys) {
      if (key.startsWith('chat_wallpaper_')) {
        final chatIdStr = key.substring('chat_wallpaper_'.length);
        final chatId = int.tryParse(chatIdStr);
        if (chatId != null) {
          final imagePath = prefs.getString(key);
          if (imagePath != null && imagePath.isNotEmpty) {
            _chatSpecificWallpapers[chatId] = imagePath;
          }
        }
      }
    }
    notifyListeners();
  }

  Future<void> setUIMode(UIMode value) async {
    _activeTheme = _activeTheme.copyWith(uiMode: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setShowSeconds(bool value) async {
    _activeTheme = _activeTheme.copyWith(showSeconds: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setMessageBubbleOpacity(double value) async {
    _activeTheme = _activeTheme.copyWith(
      messageBubbleOpacity: value.clamp(0.0, 1.0),
    );
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setMessageStyle(String value) async {
    _activeTheme = _activeTheme.copyWith(messageStyle: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setMessageBackgroundBlur(double value) async {
    _activeTheme = _activeTheme.copyWith(
      messageBackgroundBlur: value.clamp(0.0, 10.0),
    );
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setMessageTextOpacity(double value) async {
    _activeTheme = _activeTheme.copyWith(
      messageTextOpacity: value.clamp(0.1, 1.0),
    );
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setMessageShadowIntensity(double value) async {
    _activeTheme = _activeTheme.copyWith(
      messageShadowIntensity: value.clamp(0.0, 0.5),
    );
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setMessageBorderRadius(double value) async {
    _activeTheme = _activeTheme.copyWith(
      messageBorderRadius: value.clamp(4.0, 50.0),
    );
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setMessageMenuOpacity(double value) async {
    _activeTheme = _activeTheme.copyWith(messageMenuOpacity: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setMessageMenuBlur(double value) async {
    _activeTheme = _activeTheme.copyWith(messageMenuBlur: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setDebugShowPerformanceOverlay(bool value) async {
    _debugShowPerformanceOverlay = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debug_perf_overlay', value);
  }

  Future<void> setDebugShowChatsRefreshPanel(bool value) async {
    _debugShowChatsRefreshPanel = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debug_show_chats_refresh_panel', value);
  }

  Future<void> setDebugShowMessageCount(bool value) async {
    _debugShowMessageCount = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debug_show_message_count', value);
  }

  Future<void> setDebugReadOnEnter(bool value) async {
    _debugReadOnEnter = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debug_read_on_enter', value);
  }

  Future<void> setDebugReadOnAction(bool value) async {
    _debugReadOnAction = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debug_read_on_action', value);
  }

  Future<void> setDebugShowBurgerMenu(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debug_show_burger_menu', value);
  }

  Future<void> setChatTransition(TransitionOption value) async {
    _activeTheme = _activeTheme.copyWith(chatTransition: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setTabTransition(TransitionOption value) async {
    _activeTheme = _activeTheme.copyWith(tabTransition: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setMessageTransition(TransitionOption value) async {
    _activeTheme = _activeTheme.copyWith(messageTransition: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setExtraTransition(TransitionOption value) async {
    _activeTheme = _activeTheme.copyWith(extraTransition: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setExtraAnimationStrength(double value) async {
    _activeTheme = _activeTheme.copyWith(
      extraAnimationStrength: value.clamp(1.0, 400.0),
    );
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setMessageSlideDistance(double value) async {
    _activeTheme = _activeTheme.copyWith(
      messageSlideDistance: value.clamp(1.0, 200.0),
    );
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setAnimatePhotoMessages(bool value) async {
    _activeTheme = _activeTheme.copyWith(animatePhotoMessages: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setOptimizeChats(bool value) async {
    _activeTheme = _activeTheme.copyWith(
      optimizeChats: value,
      ultraOptimizeChats: value ? false : _activeTheme.ultraOptimizeChats,
    );
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setUltraOptimizeChats(bool value) async {
    _activeTheme = _activeTheme.copyWith(
      ultraOptimizeChats: value,
      optimizeChats: value ? false : _activeTheme.optimizeChats,
    );
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setHighQualityPhotos(bool value) async {
    _highQualityPhotos = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('high_quality_photos', _highQualityPhotos);
  }

  Future<void> setBlockBypass(bool value) async {
    _blockBypass = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('block_bypass', _blockBypass);
  }

  Future<void> setChatPreviewMode(ChatPreviewMode value) async {
    _chatPreviewMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('chat_preview_mode', _chatPreviewMode.index);
  }

  Future<void> setShowFpsOverlay(bool value) async {
    _showFpsOverlay = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_fps_overlay', _showFpsOverlay);
  }

  Future<void> setMaxFrameRate(int value) async {
    _maxFrameRate = value.clamp(30, 120);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('max_frame_rate', _maxFrameRate);
  }

  Future<void> setOptimization(bool value) async {
    if (value && !_optimization) {
      _savedThemeBeforeOptimization = _activeTheme;

      _activeTheme = _activeTheme.copyWith(
        chatTransition: TransitionOption.systemDefault,
        tabTransition: TransitionOption.systemDefault,
        messageTransition: TransitionOption.systemDefault,
        extraTransition: TransitionOption.systemDefault,
        animatePhotoMessages: false,

        useGlassPanels: false,

        useCustomChatWallpaper: false,
        chatsListBackgroundType: ChatsListBackgroundType.none,
        drawerBackgroundType: DrawerBackgroundType.none,
        appBarBackgroundType: AppBarBackgroundType.none,
        folderTabsBackgroundType: FolderTabsBackgroundType.none,
        useGradientForChatsList: false,
        useGradientForDrawer: false,
        useGradientForAppBar: false,
        useGradientForFolderTabs: false,
        useGradientForAddAccountButton: false,

        topBarBlur: 0.0,
        bottomBarBlur: 0.0,
        profileDialogBlur: 0.0,
        messageMenuBlur: 0.0,
        chatWallpaperImageBlur: 0.0,
        messageBackgroundBlur: 0.0,

        topBarOpacity: 1.0,
        bottomBarOpacity: 1.0,
        profileDialogOpacity: 1.0,
        messageMenuOpacity: 1.0,
        messageBubbleOpacity: 0.0,
        messageTextOpacity: 1.0,
      );

      await _saveActiveTheme();
    } else if (!value && _optimization) {
      if (_savedThemeBeforeOptimization != null) {
        _activeTheme = _savedThemeBeforeOptimization!;
        _savedThemeBeforeOptimization = null;
        await _saveActiveTheme();
      }
    }

    _optimization = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('optimization', _optimization);
  }

  Future<void> setUseDesktopLayout(bool value) async {
    _activeTheme = _activeTheme.copyWith(useDesktopLayout: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setUseAutoReplyColor(bool value) async {
    _activeTheme = _activeTheme.copyWith(useAutoReplyColor: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setCustomReplyColor(Color? color) async {
    _activeTheme = _activeTheme.copyWith(customReplyColor: color);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setUseGradientForChatsList(bool value) async {
    _activeTheme = _activeTheme.copyWith(useGradientForChatsList: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setChatsListBackgroundType(ChatsListBackgroundType type) async {
    _activeTheme = _activeTheme.copyWith(chatsListBackgroundType: type);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setChatsListImagePath(String? path) async {
    _activeTheme = _activeTheme.copyWith(chatsListImagePath: path);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setUseGradientForDrawer(bool value) async {
    _activeTheme = _activeTheme.copyWith(useGradientForDrawer: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setDrawerBackgroundType(DrawerBackgroundType type) async {
    _activeTheme = _activeTheme.copyWith(drawerBackgroundType: type);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setDrawerImagePath(String? path) async {
    _activeTheme = _activeTheme.copyWith(drawerImagePath: path);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setChatsListGradientColor1(Color color) async {
    _activeTheme = _activeTheme.copyWith(chatsListGradientColor1: color);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setChatsListGradientColor2(Color color) async {
    _activeTheme = _activeTheme.copyWith(chatsListGradientColor2: color);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setDrawerGradientColor1(Color color) async {
    _activeTheme = _activeTheme.copyWith(drawerGradientColor1: color);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setDrawerGradientColor2(Color color) async {
    _activeTheme = _activeTheme.copyWith(drawerGradientColor2: color);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setUseGradientForAddAccountButton(bool value) async {
    _activeTheme = _activeTheme.copyWith(useGradientForAddAccountButton: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setAddAccountButtonGradientColor1(Color color) async {
    _activeTheme = _activeTheme.copyWith(addAccountButtonGradientColor1: color);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setAddAccountButtonGradientColor2(Color color) async {
    _activeTheme = _activeTheme.copyWith(addAccountButtonGradientColor2: color);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setUseGradientForAppBar(bool value) async {
    _activeTheme = _activeTheme.copyWith(useGradientForAppBar: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setAppBarGradientColor1(Color color) async {
    _activeTheme = _activeTheme.copyWith(appBarGradientColor1: color);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setAppBarGradientColor2(Color color) async {
    _activeTheme = _activeTheme.copyWith(appBarGradientColor2: color);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setAppBarBackgroundType(AppBarBackgroundType type) async {
    _activeTheme = _activeTheme.copyWith(appBarBackgroundType: type);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setAppBarImagePath(String? path) async {
    _activeTheme = _activeTheme.copyWith(appBarImagePath: path);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setUseGradientForFolderTabs(bool value) async {
    _activeTheme = _activeTheme.copyWith(useGradientForFolderTabs: value);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setFolderTabsGradientColor1(Color color) async {
    _activeTheme = _activeTheme.copyWith(folderTabsGradientColor1: color);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setFolderTabsGradientColor2(Color color) async {
    _activeTheme = _activeTheme.copyWith(folderTabsGradientColor2: color);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setFolderTabsBackgroundType(
    FolderTabsBackgroundType type,
  ) async {
    _activeTheme = _activeTheme.copyWith(folderTabsBackgroundType: type);
    notifyListeners();
    await _saveActiveTheme();
  }

  Future<void> setFolderTabsImagePath(String? path) async {
    _activeTheme = _activeTheme.copyWith(folderTabsImagePath: path);
    notifyListeners();
    await _saveActiveTheme();
  }

  void toggleTheme() {
    if (appTheme == AppTheme.light) {
      setTheme(AppTheme.dark);
    } else {
      setTheme(AppTheme.light);
    }
  }

  Future<void> resetAnimationsToDefault() async {
    _activeTheme = _activeTheme.copyWith(
      chatTransition: TransitionOption.systemDefault,
      tabTransition: TransitionOption.systemDefault,
      messageTransition: TransitionOption.systemDefault,
      extraTransition: TransitionOption.systemDefault,
      messageSlideDistance: 96.0,
      extraAnimationStrength: 32.0,
    );
    notifyListeners();
    await _saveActiveTheme();
  }
}
