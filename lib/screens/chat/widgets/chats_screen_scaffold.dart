import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gwid/utils/theme_provider.dart';
import 'package:gwid/app_sizes.dart';

class ChatsScreenScaffold extends StatelessWidget {
  final Widget bodyContent;
  final PreferredSizeWidget Function(BuildContext) buildAppBar;
  final Widget Function(BuildContext) buildAppDrawer;
  final VoidCallback? onAddPressed;

  const ChatsScreenScaffold({
    super.key,
    required this.bodyContent,
    required this.buildAppBar,
    required this.buildAppDrawer,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, _) {
        BoxDecoration? chatsListDecoration;
        if (theme.chatsListBackgroundType == ChatsListBackgroundType.gradient) {
          chatsListDecoration = BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.chatsListGradientColor1,
                theme.chatsListGradientColor2,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          );
        } else if (theme.chatsListBackgroundType ==
                ChatsListBackgroundType.image &&
            theme.chatsListImagePath != null &&
            theme.chatsListImagePath!.isNotEmpty) {
          chatsListDecoration = BoxDecoration(
            image: DecorationImage(
              image: FileImage(File(theme.chatsListImagePath!)),
              fit: BoxFit.cover,
            ),
          );
        }

        return Scaffold(
          appBar: buildAppBar(context),
          drawer: buildAppDrawer(context),
          body: chatsListDecoration != null
              ? Container(
                  decoration: chatsListDecoration,
                  child: Row(children: [Expanded(child: bodyContent)]),
                )
              : Row(children: [Expanded(child: bodyContent)]),
          floatingActionButton: onAddPressed != null
              ? FloatingActionButton(
                  onPressed: onAddPressed,
                  tooltip: 'Создать',
                  heroTag: 'create_menu',
                  child: const Icon(Icons.edit),
                )
              : null,
        );
      },
    );
  }
}
