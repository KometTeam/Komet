import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/media/gallery_source.dart';
import '../../../core/security/app_lock.dart';
import '../../../l10n/app_localizations.dart';
import '../custom_notification.dart';
import '../small_spinner.dart';
import 'attachment_sheet.dart';
import 'editor_common.dart';
import 'photo_editor.dart';

Future<File?> pickAvatarImage(BuildContext context) async {
  File? picked;
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
      final result = await openAvatarEditor(sheetContext, source);
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
  return openAvatarEditor(context, File(path));
}

Future<File?> openAvatarEditor(BuildContext context, File source) =>
    Navigator.of(context, rootNavigator: true).push<File>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AvatarEditor(source: source),
      ),
    );

class AvatarEditor extends StatefulWidget {
  final File source;

  const AvatarEditor({super.key, required this.source});

  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> {
  late File _source = widget.source;
  final List<File> _drawn = [];
  ui.Image? _image;
  CropState? _state;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _image?.dispose();
    for (final file in _drawn) {
      file.delete().then((_) {}, onError: (_) {});
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = await _source.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      final previous = _image;
      setState(() => _image = frame.image);
      previous?.dispose();
    } catch (_) {
      if (!mounted) return;
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.mediaPreviewEditorOpenFailed,
      );
      Navigator.of(context).pop();
    }
  }

  Future<Object?> _apply(
    CropState state,
    Size viewport,
    bool changed,
    bool identity,
  ) async {
    final image = _image;
    if (image == null) return null;
    return bakeCropToFile(image, state, viewport);
  }

  Future<void> _draw(CropState state) async {
    final source = _source;
    final dims = await imageFileDimensions(source);
    if (!mounted) return;
    if (dims == null) {
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.mediaPreviewEditorOpenFailed,
      );
      return;
    }
    final drawn = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoDrawEditor(
          source: source,
          imageWidth: dims.$1,
          imageHeight: dims.$2,
        ),
      ),
    );
    if (drawn == null || !mounted) return;
    _drawn.add(drawn);
    setState(() {
      _state = state;
      _source = drawn;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: SmallSpinner(size: 36, color: Colors.white)),
      );
    }
    return CropWorkspace(
      key: ValueKey(image),
      preset: CropPreset.avatar,
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      initialState: _state,
      onApply: _apply,
      onDraw: _draw,
      imageBuilder: (context, matrix) =>
          CustomPaint(painter: MatrixImagePainter(image, matrix)),
    );
  }
}
