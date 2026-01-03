import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gwid/utils/theme_provider.dart';
import 'package:gwid/app_sizes.dart';

/// Builder для AppBar экрана чатов
class ChatsAppBarBuilder {
  static AppBar build(
    BuildContext context, {
    required bool isSearchExpanded,
    required String searchQuery,
    required Widget currentTitleWidget,
    required Widget searchField,
    required VoidCallback onBackPressed,
    required VoidCallback onClearSearch,
    required VoidCallback onSearchPressed,
    required VoidCallback onSearchLongPress,
    required VoidCallback onSferumPressed,
    required VoidCallback onDownloadsPressed,
    required VoidCallback onFilterPressed,
    required bool showSferumButton,
    required ThemeProvider themeProvider,
  }) {
    BoxDecoration? appBarDecoration;
    if (themeProvider.appBarBackgroundType == AppBarBackgroundType.gradient) {
      appBarDecoration = BoxDecoration(
        gradient: LinearGradient(
          colors: [
            themeProvider.appBarGradientColor1,
            themeProvider.appBarGradientColor2,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    } else if (themeProvider.appBarBackgroundType ==
            AppBarBackgroundType.image &&
        themeProvider.appBarImagePath != null &&
        themeProvider.appBarImagePath!.isNotEmpty) {
      appBarDecoration = BoxDecoration(
        image: DecorationImage(
          image: FileImage(File(themeProvider.appBarImagePath!)),
          fit: BoxFit.cover,
        ),
      );
    }

    return AppBar(
      titleSpacing: 4.0,
      flexibleSpace: appBarDecoration != null
          ? Container(decoration: appBarDecoration)
          : null,
      leading: isSearchExpanded
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBackPressed,
            )
          : Builder(
              builder: (context) {
                return IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Меню',
                );
              },
            ),
      title: isSearchExpanded
          ? searchField
          : Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    child: currentTitleWidget,
                  ),
                ),
              ],
            ),
      actions: isSearchExpanded
          ? [
              if (searchQuery.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  child: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: onClearSearch,
                  ),
                ),
              Container(
                margin: const EdgeInsets.only(left: 4),
                child: IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: onFilterPressed,
                ),
              ),
            ]
          : [
              if (showSferumButton)
                IconButton(
                  icon: Image.asset(
                    'assets/images/spermum.png',
                    width: 28,
                    height: 28,
                  ),
                  onPressed: onSferumPressed,
                  tooltip: 'Сферум',
                ),
              IconButton(
                icon: Icon(Icons.download, color: Colors.white),
                onPressed: onDownloadsPressed,
                tooltip: 'Загрузки',
              ),
              InkWell(
                onTap: onSearchPressed,
                onLongPress: onSearchLongPress,
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  child: const Icon(Icons.search),
                ),
              ),
              const SizedBox(width: 8),
            ],
    );
  }
}
