import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/media/gallery_source.dart';
import '../../../l10n/app_localizations.dart';
import '../custom_notification.dart';
import '../small_spinner.dart';
import 'editor_common.dart';
import 'photo_editor.dart';
import 'photo_pick.dart';

Future<File?> pickAvatarImage(BuildContext context) => pickImageWith(
  context,
  (context, source, _) => openAvatarEditor(context, source),
);

Future<File?> openAvatarEditor(BuildContext context, File source) =>
    _openCropDrawEditor(context, source, CropPreset.avatar);

Future<File?> openPhotoEditor(BuildContext context, File source) =>
    _openCropDrawEditor(context, source, CropPreset.free);

Future<File?> _openCropDrawEditor(
  BuildContext context,
  File source,
  CropPreset preset,
) => Navigator.of(context, rootNavigator: true).push<File>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => CropDrawEditor(source: source, preset: preset),
  ),
);

class CropDrawEditor extends StatefulWidget {
  final File source;
  final CropPreset preset;

  const CropDrawEditor({
    super.key,
    required this.source,
    this.preset = CropPreset.avatar,
  });

  @override
  State<CropDrawEditor> createState() => _CropDrawEditorState();
}

class _CropDrawEditorState extends State<CropDrawEditor> {
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
    if (image == null || (!changed && _drawn.isEmpty)) return null;
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
      preset: widget.preset,
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      initialState: _state,
      onApply: _apply,
      onDraw: _draw,
      imageBuilder: (context, matrix) =>
          CustomPaint(painter: MatrixImagePainter(image, matrix)),
    );
  }
}
