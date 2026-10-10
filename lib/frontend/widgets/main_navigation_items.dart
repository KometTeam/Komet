import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/app_animations.dart';
import 'sliding_pill_nav.dart';

const mainNavigationItems = [
  PillNavItem(icon: Symbols.chat_bubble, label: 'Чаты'),
  PillNavItem(icon: Symbols.call, label: 'Звонки'),
  PillNavItem(icon: Symbols.person_pin, label: 'Контакты'),
  PillNavItem(
    icon: Symbols.settings,
    label: 'Настройки',
    longPressable: true,
    animationAsset: AppAnimations.settings,
  ),
];
