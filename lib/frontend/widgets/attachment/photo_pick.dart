import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/media/gallery_source.dart';
import '../../../core/security/app_lock.dart';
import '../../../l10n/app_localizations.dart';
import '../custom_notification.dart';
import 'attachment_sheet.dart';

typedef PickedImage = ({File file, GalleryItem? item});

Future<PickedImage?> pickPhoto(BuildContext context) =>
    pickImageWith(context, (_, file, item) async => (file: file, item: item));

Future<T?> pickImageWith<T>(
  BuildContext context,
  Future<T?> Function(BuildContext context, File source, GalleryItem? item)
  accept,
) async {
  T? picked;
  var fromFiles = false;
  await showAttachmentSheet(
    context,
    onPickPhoto: (sheetContext, item) async {
      final source = item.localFile ?? await item.originFile();
      if (!sheetContext.mounted) return;
      if (source == null) {
        showCustomNotification(
          sheetContext,
          AppLocalizations.of(sheetContext)!.mediaPreviewEditorOpenFailed,
        );
        return;
      }
      final result = await accept(sheetContext, source, item);
      if (result == null || !sheetContext.mounted) return;
      picked = result;
      Navigator.of(sheetContext).pop();
    },
    onPickFile: () => fromFiles = true,
  );
  if (picked != null || !fromFiles || !context.mounted) return picked;
  final files = await AppLock.instance.external(
    () => FilePicker.platform.pickFiles(type: FileType.image),
  );
  final path = files?.files.firstOrNull?.path;
  if (path == null || !context.mounted) return null;
  return accept(context, File(path), null);
}
