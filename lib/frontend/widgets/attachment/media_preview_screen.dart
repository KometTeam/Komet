import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/core/media/gallery_source.dart';
import 'package:komet/frontend/widgets/attachment/photo_editor.dart';
import 'package:komet/frontend/widgets/attachment/photo_hero.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';

import 'editor_common.dart';
import 'preview_chrome.dart';
import '../small_spinner.dart';

class MediaPreviewScreen extends StatefulWidget {
  final GalleryItem item;
  final PhotoHeroController hero;
  final String? title;
  final ValueListenable<Set<String>> selectedIds;
  final VoidCallback onToggleSelection;
  final VoidCallback onSend;
  final PhotoEditState? editState;
  final ValueChanged<PhotoEditState>? onEditChanged;
  final String initialCaption;
  final ValueChanged<String>? onCaptionChanged;
  final Set<String> tempFiles;

  const MediaPreviewScreen({
    super.key,
    required this.item,
    required this.hero,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onSend,
    required this.tempFiles,
    this.title,
    this.editState,
    this.onEditChanged,
    this.initialCaption = '',
    this.onCaptionChanged,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  late final TextEditingController _caption = TextEditingController(
    text: widget.initialCaption,
  );
  final TransformationController _zoom = TransformationController();
  final GlobalKey _stageKey = GlobalKey();
  File? _workingFile;
  File? _cropSource;
  CropState? _cropState;
  Size? _workingSize;
  PhotoHeroController? _activeHero;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_syncHero);
    _caption.addListener(() => widget.onCaptionChanged?.call(_caption.text));
    _cropState = widget.editState?.cropState;
    _cropSource = widget.editState?.cropSource;
    _resolveWorkingFile();
  }

  Future<void> _resolveWorkingFile() async {
    final initial = widget.editState?.working ?? widget.item.localFile;
    if (initial != null) {
      _setWorkingFile(initial);
      return;
    }
    final file = await widget.item.originFile();
    if (!mounted || file == null) return;
    setState(() => _setWorkingFile(file));
  }

  void _setWorkingFile(File file) {
    _workingFile = file;
    widget.hero.image.value = FileImage(file);
    _resolveWorkingSize(file);
  }

  Future<void> _resolveWorkingSize(File file) async {
    final dims = await imageFileDimensions(file);
    if (!mounted || dims == null || _workingFile?.path != file.path) return;
    _workingSize = Size(dims.$1.toDouble(), dims.$2.toDouble());
  }

  Rect? _stageOrigin() {
    if (_zoom.value.getMaxScaleOnAxis() > 1.01) return null;
    final box = photoHeroRect(_stageKey);
    final size = _workingSize;
    if (box == null || size == null) return null;
    return inscribeRect(size, box);
  }

  Future<void> _flight(File file) async {
    await _resolveWorkingSize(file);
    if (!mounted) return;
    final provider = FileImage(file);
    await precacheImage(provider, context);
    if (!mounted) return;
    _activeHero?.image.value = provider;
  }

  @override
  void dispose() {
    _caption.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _syncHero() =>
      widget.hero.enabled = _zoom.value.getMaxScaleOnAxis() <= 1.01;

  void _send() {
    Navigator.of(context).pop();
    widget.onSend();
  }

  Future<T?> _pushEditor<T>(Widget Function() builder) async {
    final file = _workingFile;
    if (file == null) return null;
    final hero = PhotoHeroController(
      origin: _stageOrigin,
      image: FileImage(file),
    );
    _activeHero = hero;
    try {
      return await Navigator.of(
        context,
      ).push<T>(PhotoHeroRoute<T>(hero: hero, builder: (_) => builder()));
    } finally {
      _activeHero = null;
    }
  }

  void _reportEdit() {
    widget.onEditChanged?.call(
      PhotoEditState(
        working: _workingFile,
        cropSource: _cropSource,
        cropState: _cropState,
      ),
    );
  }

  void _disposeTemp(File? file, Set<String> keep) {
    if (file == null || keep.contains(file.path)) return;
    if (!widget.tempFiles.remove(file.path)) return;
    file.delete().then((_) {}, onError: (_) {});
  }

  Future<void> _openCrop() async {
    if (_workingFile == null) return;
    final source = _cropSource ??=
        widget.item.localFile ?? await widget.item.originFile();
    if (source == null || !mounted) return;
    await _pushEditor<CropResult>(
      () => PhotoCropEditor(
        source: source,
        initialState: _cropState,
        onPreview: _applyCrop,
      ),
    );
  }

  Future<void> _applyCrop(CropResult result) async {
    if (!mounted) return;
    final old = _workingFile;
    _cropState = result.state;
    widget.tempFiles.add(result.file.path);
    setState(() => _setWorkingFile(result.file));
    _reportEdit();
    _disposeTemp(old, {result.file.path, _cropSource?.path ?? ''});
    await _flight(result.file);
  }

  Future<void> _openDraw() async {
    final file = _workingFile;
    if (file == null) return;
    final dims = await imageFileDimensions(file);
    if (!mounted) return;
    if (dims == null) {
      showCustomNotification(context, 'Не удалось открыть редактор');
      return;
    }
    await _pushEditor<File>(
      () => PhotoDrawEditor(
        source: file,
        imageWidth: dims.$1,
        imageHeight: dims.$2,
        onPreview: _applyBaked,
      ),
    );
  }

  Future<void> _openAdjust() async {
    final file = _workingFile;
    if (file == null) return;
    await _pushEditor<File>(
      () => PhotoAdjustEditor(source: file, onPreview: _applyBaked),
    );
  }

  Future<void> _applyBaked(File result) async {
    if (!mounted) return;
    final oldWorking = _workingFile;
    final oldCropSource = _cropSource;
    _cropSource = result;
    _cropState = null;
    widget.tempFiles.add(result.path);
    setState(() => _setWorkingFile(result));
    _reportEdit();
    _disposeTemp(oldWorking, {result.path});
    _disposeTemp(oldCropSource, {result.path, oldWorking?.path ?? ''});
    await _flight(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.title ?? '',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: PreviewSelectionToggle(
              selectedIds: widget.selectedIds,
              id: widget.item.id,
              onTap: widget.onToggleSelection,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PhotoHeroTarget(
              child: Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  transformationController: _zoom,
                  child: KeyedSubtree(key: _stageKey, child: _buildImage()),
                ),
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return ValueListenableBuilder<ImageProvider?>(
      valueListenable: widget.hero.image,
      builder: (context, provider, _) {
        if (provider == null) {
          return const SmallSpinner(size: 36, color: Colors.white24);
        }
        return Image(
          image: provider,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCaptionField(),
            const SizedBox(height: 10),
            _buildToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptionField() {
    return Container(
      decoration: BoxDecoration(
        color: kEditorBar,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _caption,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Добавить подпись...',
                hintStyle: TextStyle(color: Colors.white54, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<Set<String>>(
            valueListenable: widget.selectedIds,
            builder: (context, selected, _) {
              final count = selected.isEmpty ? 1 : selected.length;
              return PreviewCountBadge(count: count);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: kEditorBar,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                PreviewToolIcon(icon: Symbols.crop_rotate, onTap: _openCrop),
                PreviewToolIcon(icon: Symbols.brush, onTap: _openDraw),
                const PreviewFileToggle(),
                PreviewToolIcon(icon: Symbols.tune, onTap: _openAdjust),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        PreviewSendButton(onTap: _send),
      ],
    );
  }
}
