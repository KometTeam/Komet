import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:gwid/utils/theme_provider.dart';
import 'dart:io';
import 'dart:ui';
import 'package:gwid/models/message.dart';
import 'package:gwid/widgets/chat_message_bubble.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void _showColorPicker(
  BuildContext context, {
  required Color initialColor,
  required ValueChanged<Color> onColorChanged,
}) {
  Color pickedColor = initialColor;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Выберите цвет"),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      content: SingleChildScrollView(
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return ColorPicker(
              pickerColor: pickedColor,
              onColorChanged: (color) {
                setState(() => pickedColor = color);
              },
              enableAlpha: false,
              pickerAreaHeightPercent: 0.8,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Отмена'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          onPressed: () {
            onColorChanged(pickedColor);
            Navigator.of(context).pop();
          },
          child: const Text('Готово'),
        ),
      ],
    ),
  );
}

class CustomizationScreen extends StatefulWidget {
  const CustomizationScreen({super.key});

  @override
  State<CustomizationScreen> createState() => _CustomizationScreenState();
}

class _CustomizationScreenState extends State<CustomizationScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = Theme.of(context).colorScheme;
    final bool isMaterialYou = theme.appTheme == AppTheme.system;
    final bool isCurrentlyDark =
        Theme.of(context).brightness == Brightness.dark;

    final Color? myBubbleColorToShow = isCurrentlyDark
        ? (isMaterialYou ? colors.primaryContainer : theme.myBubbleColorDark)
        : (isMaterialYou ? colors.primaryContainer : theme.myBubbleColorLight);
    final Color? theirBubbleColorToShow = isCurrentlyDark
        ? (isMaterialYou
              ? colors.secondaryContainer
              : theme.theirBubbleColorDark)
        : (isMaterialYou
              ? colors.secondaryContainer
              : theme.theirBubbleColorLight);

    final Function(Color?) myBubbleSetter = isCurrentlyDark
        ? theme.setMyBubbleColorDark
        : theme.setMyBubbleColorLight;
    final Function(Color?) theirBubbleSetter = isCurrentlyDark
        ? theme.setTheirBubbleColorDark
        : theme.setTheirBubbleColorLight;

    final Color myBubbleFallback = isCurrentlyDark
        ? const Color(0xFF2b5278)
        : Colors.blue.shade100;
    final Color theirBubbleFallback = isCurrentlyDark
        ? const Color(0xFF182533)
        : const Color(0xFF464646);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Персонализация"),
        surfaceTintColor: Colors.transparent,
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          const _MessagePreviewSection(),
          const SizedBox(height: 16),
          const _ThemeManagementSection(),
          const SizedBox(height: 16),
          _ModernSection(
            title: "Тема приложения",
            children: [
              const SizedBox(height: 8),
              _CustomSettingTile(
                icon: Icons.auto_awesome_outlined,
                title: "Material You",
                subtitle: "Использовать цвета системы (Android 12+)",
                child: Switch(
                  value: isMaterialYou,
                  onChanged: (value) => theme.setMaterialYouEnabled(value),
                ),
              ),
              const SizedBox(height: 12),
              IgnorePointer(
                ignoring: isMaterialYou,
                child: Opacity(
                  opacity: isMaterialYou ? 0.5 : 1.0,
                  child: AppThemeSelector(
                    selectedTheme: isMaterialYou
                        ? theme.lastNonSystemTheme
                        : theme.appTheme,
                    onChanged: (appTheme) => theme.setTheme(appTheme),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              IgnorePointer(
                ignoring: isMaterialYou,
                child: Opacity(
                  opacity: isMaterialYou ? 0.5 : 1.0,
                  child: _ColorPickerTile(
                    title: "Акцентный цвет",
                    subtitle: isMaterialYou
                        ? "Используются цвета системы (Material You)"
                        : "Основной цвет интерфейса",
                    color: isMaterialYou ? colors.primary : theme.accentColor,
                    onColorChanged: (color) => theme.setAccentColor(color),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _ModernSection(
                title: "Обои чата",
                children: [
                  const SizedBox(height: 8),
                  _CustomSettingTile(
                    icon: Icons.wallpaper,
                    title: "Использовать свои обои",
                    child: Switch(
                      value: theme.useCustomChatWallpaper,
                      onChanged: (value) =>
                          theme.setUseCustomChatWallpaper(value),
                    ),
                  ),
                  if (theme.useCustomChatWallpaper) ...[
                    const Divider(height: 24),
                    _CustomSettingTile(
                      icon: Icons.image,
                      title: "Тип обоев",
                      child: DropdownButton<ChatWallpaperType>(
                        value:
                            theme.chatWallpaperType == ChatWallpaperType.komet
                            ? ChatWallpaperType.solid
                            : theme.chatWallpaperType,
                        underline: const SizedBox.shrink(),
                        onChanged: (value) {
                          if (value != null) theme.setChatWallpaperType(value);
                        },
                        items: ChatWallpaperType.values
                            .where((type) => type != ChatWallpaperType.komet)
                            .map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type.displayName),
                              );
                            })
                            .toList(),
                      ),
                    ),
                    if (theme.chatWallpaperType == ChatWallpaperType.solid ||
                        theme.chatWallpaperType ==
                            ChatWallpaperType.gradient) ...[
                      const SizedBox(height: 16),
                      _ColorPickerTile(
                        title: "Цвет 1",
                        subtitle: "Основной цвет фона",
                        color: theme.chatWallpaperColor1,
                        onColorChanged: (color) =>
                            theme.setChatWallpaperColor1(color),
                      ),
                    ],
                    if (theme.chatWallpaperType ==
                        ChatWallpaperType.gradient) ...[
                      const SizedBox(height: 16),
                      _ColorPickerTile(
                        title: "Цвет 2",
                        subtitle: "Дополнительный цвет для градиента",
                        color: theme.chatWallpaperColor2,
                        onColorChanged: (color) =>
                            theme.setChatWallpaperColor2(color),
                      ),
                    ],
                    if (theme.chatWallpaperType == ChatWallpaperType.image) ...[
                      const Divider(height: 16),
                      _ActionTile(
                        icon: Icons.photo_library_outlined,
                        title: "Выбрать изображение",
                        onTap: () async {
                          final picker = ImagePicker();
                          final image = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (image != null) {
                            theme.setChatWallpaperImagePath(image.path);
                          }
                        },
                      ),
                      if (theme.chatWallpaperImagePath?.isNotEmpty == true) ...[
                        _SliderTile(
                          icon: Icons.blur_on,
                          label: "Размытие",
                          value: theme.chatWallpaperImageBlur,
                          min: 0.0,
                          max: 10.0,
                          divisions: 20,
                          onChanged: (value) =>
                              theme.setChatWallpaperImageBlur(value),
                          displayValue: theme.chatWallpaperImageBlur
                              .toStringAsFixed(1),
                        ),
                        _ActionTile(
                          icon: Icons.delete_outline,
                          title: "Удалить изображение",
                          isDestructive: true,
                          onTap: () => theme.setChatWallpaperImagePath(null),
                        ),
                      ],
                    ],
                    if (theme.chatWallpaperType == ChatWallpaperType.video) ...[
                      const Divider(height: 16),
                      _ActionTile(
                        icon: Icons.video_library_outlined,
                        title: "Выбрать видео",
                        onTap: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.video,
                          );
                          if (result != null &&
                              result.files.single.path != null) {
                            theme.setChatWallpaperVideoPath(
                              result.files.single.path!,
                            );
                          }
                        },
                      ),
                      if (theme.chatWallpaperVideoPath?.isNotEmpty == true) ...[
                        _ActionTile(
                          icon: Icons.delete_outline,
                          title: "Удалить видео",
                          isDestructive: true,
                          onTap: () => theme.setChatWallpaperVideoPath(null),
                        ),
                      ],
                    ],
                  ],
                ],
              ),
              const SizedBox(height: 8),
              _ModernSection(
                title: "Сообщения",
                children: [
                  const SizedBox(height: 8),
                  _ExpandableSection(
                    title: "Прозрачность",
                    initiallyExpanded: false,
                    children: [
                      _SliderTile(
                        icon: Icons.text_fields,
                        label: "Непрозрачность текста",
                        value: theme.messageTextOpacity,
                        min: 0.1,
                        max: 1.0,
                        divisions: 18,
                        onChanged: (value) =>
                            theme.setMessageTextOpacity(value),
                        displayValue:
                            "${(theme.messageTextOpacity * 100).round()}%",
                      ),
                      _SliderTile(
                        icon: Icons.blur_circular,
                        label: "Интенсивность тени",
                        value: theme.messageShadowIntensity,
                        min: 0.0,
                        max: 0.5,
                        divisions: 10,
                        onChanged: (value) =>
                            theme.setMessageShadowIntensity(value),
                        displayValue:
                            "${(theme.messageShadowIntensity * 100).round()}%",
                      ),
                      _SliderTile(
                        icon: Icons.menu,
                        label: "Непрозрачность меню",
                        value: theme.messageMenuOpacity,
                        min: 0.1,
                        max: 1.0,
                        divisions: 18,
                        onChanged: (value) =>
                            theme.setMessageMenuOpacity(value),
                        displayValue:
                            "${(theme.messageMenuOpacity * 100).round()}%",
                      ),
                      _SliderTile(
                        icon: Icons.blur_on,
                        label: "Размытие меню",
                        value: theme.messageMenuBlur,
                        min: 0.0,
                        max: 20.0,
                        divisions: 20,
                        onChanged: (value) => theme.setMessageMenuBlur(value),
                        displayValue: theme.messageMenuBlur.toStringAsFixed(1),
                      ),
                      _SliderTile(
                        icon: Icons.opacity,
                        label: "Непрозрачность сообщений",
                        value: 1.0 - theme.messageBubbleOpacity,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        onChanged: (value) =>
                            theme.setMessageBubbleOpacity(1.0 - value),
                        displayValue:
                            "${((1.0 - theme.messageBubbleOpacity) * 100).round()}%",
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  _ExpandableSection(
                    title: "Вид",
                    initiallyExpanded: false,
                    children: [
                      _SliderTile(
                        icon: Icons.rounded_corner,
                        label: "Скругление углов",
                        value: theme.messageBorderRadius,
                        min: 4.0,
                        max: 50.0,
                        divisions: 23,
                        onChanged: (value) =>
                            theme.setMessageBorderRadius(value),
                        displayValue: "${theme.messageBorderRadius.round()}px",
                      ),
                      const SizedBox(height: 16),
                      _CustomSettingTile(
                        icon: Icons.format_color_fill,
                        title: "Тип отображения",
                        child: IgnorePointer(
                          ignoring: isMaterialYou,
                          child: Opacity(
                            opacity: isMaterialYou ? 0.5 : 1.0,
                            child: DropdownButton<MessageBubbleType>(
                              value: theme.messageBubbleType,
                              underline: const SizedBox.shrink(),
                              onChanged: (value) {
                                if (value != null) {
                                  theme.setMessageBubbleType(value);
                                }
                              },
                              items: MessageBubbleType.values.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(type.displayName),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _CustomSettingTile(
                    icon: Icons.palette,
                    title: "Цвет моих сообщений",
                    child: IgnorePointer(
                      ignoring: isMaterialYou,
                      child: Opacity(
                        opacity: isMaterialYou ? 0.5 : 1.0,
                        child: GestureDetector(
                          onTap: () async {
                            final initial =
                                myBubbleColorToShow ?? myBubbleFallback;
                            _showColorPicker(
                              context,
                              initialColor: initial,
                              onColorChanged: (color) => myBubbleSetter(color),
                            );
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: myBubbleColorToShow ?? myBubbleFallback,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CustomSettingTile(
                    icon: Icons.palette_outlined,
                    title: "Цвет сообщений собеседника",
                    child: IgnorePointer(
                      ignoring: isMaterialYou,
                      child: Opacity(
                        opacity: isMaterialYou ? 0.5 : 1.0,
                        child: GestureDetector(
                          onTap: () async {
                            final initial =
                                theirBubbleColorToShow ?? theirBubbleFallback;
                            _showColorPicker(
                              context,
                              initialColor: initial,
                              onColorChanged: (color) =>
                                  theirBubbleSetter(color),
                            );
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color:
                                  theirBubbleColorToShow ?? theirBubbleFallback,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  _CustomSettingTile(
                    icon: Icons.reply,
                    title: "Автоцвет панели ответа",
                    subtitle: "",
                    child: Switch(
                      value: theme.useAutoReplyColor,
                      onChanged: (value) => theme.setUseAutoReplyColor(value),
                    ),
                  ),
                  if (!theme.useAutoReplyColor) ...[
                    const SizedBox(height: 16),
                    _ColorPickerTile(
                      title: "Цвет панели ответа",
                      subtitle: "Фиксированный цвет",
                      color: theme.customReplyColor ?? Colors.blue,
                      onColorChanged: (color) =>
                          theme.setCustomReplyColor(color),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ModernSection(
            title: "Всплывающие окна",
            children: [
              const SizedBox(height: 8),
              _ExpandableSection(
                title: "Настройки",
                initiallyExpanded: false,
                children: [
                  _SliderTile(
                    icon: Icons.opacity,
                    label: "Прозрачность фона (профиль)",
                    value: theme.profileDialogOpacity,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: (value) => theme.setProfileDialogOpacity(value),
                    displayValue:
                        "${(theme.profileDialogOpacity * 100).round()}%",
                  ),
                  _SliderTile(
                    icon: Icons.blur_on,
                    label: "Размытие фона (профиль)",
                    value: theme.profileDialogBlur,
                    min: 0.0,
                    max: 30.0,
                    divisions: 30,
                    onChanged: (value) => theme.setProfileDialogBlur(value),
                    displayValue: theme.profileDialogBlur.toStringAsFixed(1),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ModernSection(
            title: "Чаты",
            children: [
              const SizedBox(height: 8),
              _CustomSettingTile(
                icon: Icons.chat_outlined,
                title: "Превью в списке чатов",
                subtitle: "Отображение имен отправителей в превью сообщений",
                child: Builder(
                  builder: (context) {
                    final localColors = Theme.of(context).colorScheme;
                    final theme = context.watch<ThemeProvider>();
                    return DropdownButton<ChatPreviewMode>(
                      value: theme.chatPreviewMode,
                      onChanged: (ChatPreviewMode? value) {
                        if (value != null) {
                          theme.setChatPreviewMode(value);
                        }
                      },
                      items: ChatPreviewMode.values.map((mode) {
                        String text;
                        String subtitle;
                        switch (mode) {
                          case ChatPreviewMode.twoLine:
                            text = "Двустрочно";
                            subtitle = "Имя чата + Имя: сообщение";
                            break;
                          case ChatPreviewMode.threeLine:
                            text = "Трехстрочно";
                            subtitle = "Имя чата\nИмя отправителя\nСообщение";
                            break;
                          case ChatPreviewMode.noNicknames:
                            text = "Без имен";
                            subtitle = "Показывать только имя чата";
                            break;
                        }
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(
                            text,
                            style: TextStyle(color: localColors.onSurface),
                          ),
                        );
                      }).toList(),
                      underline: const SizedBox(),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: localColors.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ModernSection(
            title: "Режим ПК",
            children: [
              const SizedBox(height: 8),
              _CustomSettingTile(
                icon: Icons.desktop_windows,
                title: "Режим ПК",
                subtitle: "Не работает на телефонах",
                child: Switch(
                  value: theme.useDesktopLayout,
                  onChanged: (value) => theme.setUseDesktopLayout(value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ExpandableSection(
            title: "Кастомизация+",
            initiallyExpanded: false,
            children: [
              const SizedBox(height: 8),
              _CustomSettingTile(
                icon: Icons.format_color_fill,
                title: "Фон списка чатов",
                subtitle: "Выберите тип фона для списка чатов",
                child: DropdownButton<ChatsListBackgroundType>(
                  value: theme.chatsListBackgroundType,
                  underline: const SizedBox.shrink(),
                  onChanged: (value) {
                    if (value != null) theme.setChatsListBackgroundType(value);
                  },
                  items: ChatsListBackgroundType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                ),
              ),
              if (theme.chatsListBackgroundType ==
                  ChatsListBackgroundType.gradient) ...[
                const SizedBox(height: 16),
                _ColorPickerTile(
                  title: "Цвет 1",
                  subtitle: "Начальный цвет градиента",
                  color: theme.chatsListGradientColor1,
                  onColorChanged: (color) =>
                      theme.setChatsListGradientColor1(color),
                ),
                const SizedBox(height: 16),
                _ColorPickerTile(
                  title: "Цвет 2",
                  subtitle: "Конечный цвет градиента",
                  color: theme.chatsListGradientColor2,
                  onColorChanged: (color) =>
                      theme.setChatsListGradientColor2(color),
                ),
              ],
              if (theme.chatsListBackgroundType ==
                  ChatsListBackgroundType.image) ...[
                const Divider(height: 16),
                _ActionTile(
                  icon: Icons.photo_library_outlined,
                  title: "Выбрать изображение",
                  onTap: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) {
                      theme.setChatsListImagePath(image.path);
                    }
                  },
                ),
                if (theme.chatsListImagePath?.isNotEmpty == true) ...[
                  _ActionTile(
                    icon: Icons.delete_outline,
                    title: "Удалить изображение",
                    isDestructive: true,
                    onTap: () => theme.setChatsListImagePath(null),
                  ),
                ],
              ],
              const Divider(height: 24),
              _CustomSettingTile(
                icon: Icons.view_sidebar,
                title: "Фон боковой панели",
                subtitle: "Выберите тип фона для боковой панели",
                child: DropdownButton<DrawerBackgroundType>(
                  value: theme.drawerBackgroundType,
                  underline: const SizedBox.shrink(),
                  onChanged: (value) {
                    if (value != null) theme.setDrawerBackgroundType(value);
                  },
                  items: DrawerBackgroundType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                ),
              ),
              if (theme.drawerBackgroundType ==
                  DrawerBackgroundType.gradient) ...[
                const SizedBox(height: 16),
                _ColorPickerTile(
                  title: "Цвет 1",
                  subtitle: "Начальный цвет градиента",
                  color: theme.drawerGradientColor1,
                  onColorChanged: (color) =>
                      theme.setDrawerGradientColor1(color),
                ),
                const SizedBox(height: 16),
                _ColorPickerTile(
                  title: "Цвет 2",
                  subtitle: "Конечный цвет градиента",
                  color: theme.drawerGradientColor2,
                  onColorChanged: (color) =>
                      theme.setDrawerGradientColor2(color),
                ),
              ],
              if (theme.drawerBackgroundType == DrawerBackgroundType.image) ...[
                const Divider(height: 16),
                _ActionTile(
                  icon: Icons.photo_library_outlined,
                  title: "Выбрать изображение",
                  onTap: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) {
                      theme.setDrawerImagePath(image.path);
                    }
                  },
                ),
                if (theme.drawerImagePath?.isNotEmpty == true) ...[
                  _ActionTile(
                    icon: Icons.delete_outline,
                    title: "Удалить изображение",
                    isDestructive: true,
                    onTap: () => theme.setDrawerImagePath(null),
                  ),
                ],
              ],
              const Divider(height: 24),
              _CustomSettingTile(
                icon: Icons.person_add,
                title: "Градиент для кнопки добавления аккаунта",
                subtitle: "Применить градиент к кнопке в drawer",
                child: Switch(
                  value: theme.useGradientForAddAccountButton,
                  onChanged: (value) =>
                      theme.setUseGradientForAddAccountButton(value),
                ),
              ),
              if (theme.useGradientForAddAccountButton) ...[
                const SizedBox(height: 16),
                _ColorPickerTile(
                  title: "Цвет 1",
                  subtitle: "Начальный цвет градиента",
                  color: theme.addAccountButtonGradientColor1,
                  onColorChanged: (color) =>
                      theme.setAddAccountButtonGradientColor1(color),
                ),
                const SizedBox(height: 16),
                _ColorPickerTile(
                  title: "Цвет 2",
                  subtitle: "Конечный цвет градиента",
                  color: theme.addAccountButtonGradientColor2,
                  onColorChanged: (color) =>
                      theme.setAddAccountButtonGradientColor2(color),
                ),
              ],
              const Divider(height: 24),
              _CustomSettingTile(
                icon: Icons.view_headline,
                title: "Фон верхней панели",
                subtitle: "Выберите тип фона для AppBar (поиск, Сферум и т.д.)",
                child: DropdownButton<AppBarBackgroundType>(
                  value: theme.appBarBackgroundType,
                  underline: const SizedBox.shrink(),
                  onChanged: (value) {
                    if (value != null) theme.setAppBarBackgroundType(value);
                  },
                  items: AppBarBackgroundType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                ),
              ),
              if (theme.appBarBackgroundType ==
                  AppBarBackgroundType.gradient) ...[
                const SizedBox(height: 16),
                _ColorPickerTile(
                  title: "Цвет 1",
                  subtitle: "Начальный цвет градиента",
                  color: theme.appBarGradientColor1,
                  onColorChanged: (color) =>
                      theme.setAppBarGradientColor1(color),
                ),
                const SizedBox(height: 16),
                _ColorPickerTile(
                  title: "Цвет 2",
                  subtitle: "Конечный цвет градиента",
                  color: theme.appBarGradientColor2,
                  onColorChanged: (color) =>
                      theme.setAppBarGradientColor2(color),
                ),
              ],
              if (theme.appBarBackgroundType == AppBarBackgroundType.image) ...[
                const Divider(height: 16),
                _ActionTile(
                  icon: Icons.photo_library_outlined,
                  title: "Выбрать изображение",
                  onTap: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) {
                      theme.setAppBarImagePath(image.path);
                    }
                  },
                ),
                if (theme.appBarImagePath?.isNotEmpty == true) ...[
                  _ActionTile(
                    icon: Icons.delete_outline,
                    title: "Удалить изображение",
                    isDestructive: true,
                    onTap: () => theme.setAppBarImagePath(null),
                  ),
                ],
              ],
              const Divider(height: 24),
              _CustomSettingTile(
                icon: Icons.folder,
                title: "Фон панели папок",
                subtitle: "Выберите тип фона для панели с именами папок",
                child: DropdownButton<FolderTabsBackgroundType>(
                  value: theme.folderTabsBackgroundType,
                  underline: const SizedBox.shrink(),
                  onChanged: (value) {
                    if (value != null) theme.setFolderTabsBackgroundType(value);
                  },
                  items: FolderTabsBackgroundType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                ),
              ),
              if (theme.folderTabsBackgroundType ==
                  FolderTabsBackgroundType.gradient) ...[
                const SizedBox(height: 16),
                _ColorPickerTile(
                  title: "Цвет 1",
                  subtitle: "Начальный цвет градиента",
                  color: theme.folderTabsGradientColor1,
                  onColorChanged: (color) =>
                      theme.setFolderTabsGradientColor1(color),
                ),
                const SizedBox(height: 16),
                _ColorPickerTile(
                  title: "Цвет 2",
                  subtitle: "Конечный цвет градиента",
                  color: theme.folderTabsGradientColor2,
                  onColorChanged: (color) =>
                      theme.setFolderTabsGradientColor2(color),
                ),
              ],
              if (theme.folderTabsBackgroundType ==
                  FolderTabsBackgroundType.image) ...[
                const Divider(height: 16),
                _ActionTile(
                  icon: Icons.photo_library_outlined,
                  title: "Выбрать изображение",
                  onTap: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) {
                      theme.setFolderTabsImagePath(image.path);
                    }
                  },
                ),
                if (theme.folderTabsImagePath?.isNotEmpty == true) ...[
                  _ActionTile(
                    icon: Icons.delete_outline,
                    title: "Удалить изображение",
                    isDestructive: true,
                    onTap: () => theme.setFolderTabsImagePath(null),
                  ),
                ],
              ],
            ],
          ),
          const SizedBox(height: 16),
          _ModernSection(
            title: "Панели чата",
            children: [
              const SizedBox(height: 8),
              _CustomSettingTile(
                icon: Icons.tune,
                title: "Эффект стекла для панелей",
                subtitle: "Размытие и прозрачность",
                child: Switch(
                  value: theme.useGlassPanels,
                  onChanged: (value) => theme.setUseGlassPanels(value),
                ),
              ),
              const SizedBox(height: 8),
              _ExpandableSection(
                title: "Настройки",
                initiallyExpanded: false,
                children: [
                  _SliderTile(
                    label: "Непрозрачность верхней панели",
                    value: theme.topBarOpacity,
                    min: 0.1,
                    max: 1.0,
                    divisions: 18,
                    onChanged: (value) => theme.setTopBarOpacity(value),
                    displayValue: "${(theme.topBarOpacity * 100).round()}%",
                  ),
                  _SliderTile(
                    label: "Размытие верхней панели",
                    value: theme.topBarBlur,
                    min: 0.0,
                    max: 20.0,
                    divisions: 40,
                    onChanged: (value) => theme.setTopBarBlur(value),
                    displayValue: theme.topBarBlur.toStringAsFixed(1),
                  ),
                  const Divider(height: 24, indent: 16, endIndent: 16),
                  _SliderTile(
                    label: "Непрозрачность нижней панели",
                    value: theme.bottomBarOpacity,
                    min: 0.1,
                    max: 1.0,
                    divisions: 18,
                    onChanged: (value) => theme.setBottomBarOpacity(value),
                    displayValue: "${(theme.bottomBarOpacity * 100).round()}%",
                  ),
                  _SliderTile(
                    label: "Размытие нижней панели",
                    value: theme.bottomBarBlur,
                    min: 0.0,
                    max: 20.0,
                    divisions: 40,
                    onChanged: (value) => theme.setBottomBarBlur(value),
                    displayValue: theme.bottomBarBlur.toStringAsFixed(1),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeManagementSection extends StatelessWidget {
  const _ThemeManagementSection();

  void _showSaveThemeDialog(BuildContext context, ThemeProvider theme) {
    final controller = TextEditingController(
      text: "Копия ${theme.activeTheme.name}",
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Сохранить тему"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: "Название темы"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Отмена"),
            ),
            FilledButton(
              onPressed: () {
                theme.saveCurrentThemeAs(controller.text);
                Navigator.of(context).pop();
              },
              child: const Text("Сохранить"),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmDeleteDialog(
    BuildContext context,
    ThemeProvider theme,
    CustomThemePreset preset,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Удалить тему?"),
          content: Text("Вы уверены, что хотите удалить '${preset.name}'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Отмена"),
            ),
            FilledButton(
              onPressed: () {
                theme.deleteTheme(preset.id);
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text("Удалить"),
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(
    BuildContext context,
    ThemeProvider theme,
    CustomThemePreset preset,
  ) {
    final controller = TextEditingController(text: preset.name);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Переименовать тему"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: "Новое название"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Отмена"),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  theme.renameTheme(preset.id, controller.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text("Сохранить"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _doExport(
    BuildContext context,
    ThemeProvider theme,
    CustomThemePreset preset,
  ) async {
    try {
      final String jsonString = jsonEncode(preset.toJson());
      final String fileName =
          '${preset.name.replaceAll(RegExp(r'[\\/*?:"<>|]'), '_')}.ktheme';
      final Uint8List bytes = utf8.encode(jsonString);

      final bool isMobile = Platform.isAndroid || Platform.isIOS;

      if (isMobile) {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Сохранить тему...',
          fileName: fileName,
          allowedExtensions: ['ktheme'],
          type: FileType.custom,
          bytes: bytes,
        );

        if (outputFile != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Тема "${preset.name}" экспортирована.')),
          );
        } else if (outputFile == null && context.mounted) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(bytes);

          final result = await Share.shareXFiles([
            XFile(tempFile.path),
          ], text: 'Экспорт темы: ${preset.name}');

          if (context.mounted) {
            if (result.status == ShareResultStatus.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Тема "${preset.name}" экспортирована.'),
                ),
              );
            }
          }
        }
      } else {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Сохранить тему...',
          fileName: fileName,
          allowedExtensions: ['ktheme'],
          type: FileType.custom,
        );

        if (outputFile != null) {
          if (!outputFile.endsWith('.ktheme')) {
            outputFile += '.ktheme';
          }

          final file = File(outputFile);
          await file.writeAsBytes(bytes);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Тема "${preset.name}" экспортирована.')),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка экспорта: $e')));
      }
    }
  }

  Future<void> _doImport(BuildContext context, ThemeProvider theme) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ktheme'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();

        final bool success = await theme.importThemeFromJson(jsonString);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'Тема успешно импортирована!'
                    : 'Ошибка: Неверный формат файла темы.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка импорта: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = Theme.of(context).colorScheme;

    return _ModernSection(
      title: "Пресеты тем",
      children: [
        ...theme.savedThemes.map((preset) {
          final bool isActive = theme.activeTheme.id == preset.id;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: isActive
                ? colors.primaryContainer.withOpacity(0.3)
                : colors.surfaceContainerHighest.withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isActive
                    ? colors.primary.withOpacity(0.5)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: InkWell(
              onTap: () {
                if (!isActive) {
                  theme.applyTheme(preset.id);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      isActive
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isActive
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        preset.name,
                        style: TextStyle(
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 15,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (preset.id != 'default')
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: "Переименовать",
                            onPressed: () =>
                                _showRenameDialog(context, theme, preset),
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.file_upload_outlined,
                            size: 20,
                          ),
                          tooltip: "Экспорт",
                          onPressed: () => _doExport(context, theme, preset),
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                        if (preset.id != 'default')
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            tooltip: "Удалить",
                            onPressed: () => _showConfirmDeleteDialog(
                              context,
                              theme,
                              preset,
                            ),
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(8),
                            ),
                            color: colors.error,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text("Сохранить"),
                  onPressed: () => _showSaveThemeDialog(context, theme),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.file_download_outlined, size: 20),
                  label: const Text("Импорт"),
                  onPressed: () => _doImport(context, theme),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModernSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ModernSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colors.outlineVariant.withOpacity(0.2),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          color: colors.surfaceContainerHighest.withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _CustomSettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  const _CustomSettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: colors.onSurface,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ColorPickerTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final ValueChanged<Color> onColorChanged;

  const _ColorPickerTile({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _showColorPicker(
        context,
        initialColor: color,
        onColorChanged: onColorChanged,
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.color_lens_outlined,
                color: colors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.outline.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final IconData? icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String displayValue;

  const _SliderTile({
    this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.displayValue,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  displayValue,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class AppThemeSelector extends StatelessWidget {
  final AppTheme selectedTheme;
  final ValueChanged<AppTheme> onChanged;

  const AppThemeSelector({
    super.key,
    required this.selectedTheme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AppTheme>(
      segments: const [
        ButtonSegment<AppTheme>(
          value: AppTheme.light,
          icon: Icon(Icons.light_mode_outlined, size: 20),
          label: Text('Светлая'),
        ),
        ButtonSegment<AppTheme>(
          value: AppTheme.dark,
          icon: Icon(Icons.dark_mode_outlined, size: 20),
          label: Text('Тёмная'),
        ),
        ButtonSegment<AppTheme>(
          value: AppTheme.black,
          icon: Icon(Icons.dark_mode, size: 20),
          label: Text('OLED'),
        ),
      ],
      selected: {selectedTheme},
      onSelectionChanged: (Set<AppTheme> newSelection) {
        onChanged(newSelection.first);
      },
      multiSelectionEnabled: false,
    );
  }
}

class _MessagePreviewSection extends StatelessWidget {
  const _MessagePreviewSection();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = Theme.of(context).colorScheme;
    final mockMyMessage = Message(
      id: '1',
      senderId: 100,
      text: "Выглядит отлично! 🔥",
      time: DateTime.now().millisecondsSinceEpoch,
      attaches: const [],
    );
    final mockTheirMessage = Message(
      id: '2',
      senderId: 200,
      text: "Привет! Как тебе новый вид?",
      time: DateTime.now().millisecondsSinceEpoch,
      attaches: const [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 12.0),
          child: Text(
            "ПРЕДПРОСМОТР",
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.outlineVariant.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Stack(
              children: [
                const _ChatWallpaperPreview(),
                Column(
                  children: [
                    ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: theme.useGlassPanels ? theme.topBarBlur : 0,
                          sigmaY: theme.useGlassPanels ? theme.topBarBlur : 0,
                        ),
                        child: Container(
                          height: 40,
                          color: colors.surface.withOpacity(
                            theme.topBarOpacity,
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              CircleAvatar(
                                backgroundColor: colors.primaryContainer,
                                radius: 12,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: ChatMessageBubble(
                        message: mockTheirMessage,
                        isMe: false,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: ChatMessageBubble(
                        message: mockMyMessage,
                        isMe: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: theme.useGlassPanels
                              ? theme.bottomBarBlur
                              : 0,
                          sigmaY: theme.useGlassPanels
                              ? theme.bottomBarBlur
                              : 0,
                        ),
                        child: Container(
                          height: 40,
                          color: colors.surface.withOpacity(
                            theme.bottomBarOpacity,
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.send, color: colors.primary),
                              const SizedBox(width: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatWallpaperPreview extends StatelessWidget {
  const _ChatWallpaperPreview();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    if (!theme.useCustomChatWallpaper) {
      return Container(color: Theme.of(context).scaffoldBackgroundColor);
    }

    switch (theme.chatWallpaperType) {
      case ChatWallpaperType.solid:
        return Container(color: theme.chatWallpaperColor1);
      case ChatWallpaperType.gradient:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.chatWallpaperColor1, theme.chatWallpaperColor2],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        );
      case ChatWallpaperType.image:
        if (theme.chatWallpaperImagePath?.isNotEmpty == true) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(theme.chatWallpaperImagePath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.error)),
              ),
              if (theme.chatWallpaperImageBlur > 0)
                BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: theme.chatWallpaperImageBlur,
                    sigmaY: theme.chatWallpaperImageBlur,
                  ),
                  child: Container(color: Colors.black.withOpacity(0.05)),
                ),
            ],
          );
        } else {
          return Container(
            color: isDarkTheme ? Colors.grey[850] : Colors.grey[200],
            child: Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: isDarkTheme ? Colors.grey[600] : Colors.grey[400],
                size: 40,
              ),
            ),
          );
        }
      case ChatWallpaperType.video:
        if (Platform.operatingSystem == 'windows') {
          return Container(
            color: isDarkTheme ? Colors.grey[850] : Colors.grey[200],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    color: isDarkTheme ? Colors.grey[600] : Colors.grey[400],
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Видео-обои\nне поддерживаются на Windows',
                    style: TextStyle(
                      color: isDarkTheme ? Colors.grey[600] : Colors.grey[400],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        if (theme.chatWallpaperVideoPath?.isNotEmpty == true) {
          return _VideoWallpaper(path: theme.chatWallpaperVideoPath!);
        } else {
          return Container(
            color: isDarkTheme ? Colors.grey[850] : Colors.grey[200],
            child: Center(
              child: Icon(
                Icons.video_library_outlined,
                color: isDarkTheme ? Colors.grey[600] : Colors.grey[400],
                size: 40,
              ),
            ),
          );
        }
      default:
        return Container(color: Theme.of(context).colorScheme.surface);
    }
  }
}

class _VideoWallpaper extends StatefulWidget {
  final String path;

  const _VideoWallpaper({required this.path});

  @override
  State<_VideoWallpaper> createState() => _VideoWallpaperState();
}

class _VideoWallpaperState extends State<_VideoWallpaper> {
  VideoPlayerController? _controller;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final file = File(widget.path);
      if (!await file.exists()) {
        setState(() {
          _errorMessage = 'Video file not found';
        });
        print('ERROR: Video file does not exist: ${widget.path}');
        return;
      }

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();

      if (mounted) {
        _controller!.setVolume(0);
        _controller!.setLooping(true);
        _controller!.play();
        setState(() {});
        print('SUCCESS: Video initialized and playing');
      }
    } catch (e) {
      print('ERROR initializing video: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      print('ERROR building video widget: $_errorMessage');
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 40),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),

        Container(
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.3)),
        ),
      ],
    );
  }
}

class _ExpandableSection extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _ExpandableSection({
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        InkWell(
          onTap: _toggleExpanded,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 4.0,
            ),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _animation,
          child: Column(
            children: [const SizedBox(height: 8), ...widget.children],
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = isDestructive ? colors.error : colors.onSurface;
    final iconColor = isDestructive ? colors.error : colors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    (isDestructive
                            ? colors.errorContainer
                            : colors.primaryContainer)
                        .withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
