import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';

import '../../../core/utils/haptics.dart';
import '../../../main.dart' show fileUploader, messagesModule, storiesModule;
import '../../widgets/custom_notification.dart';
import '../../widgets/primary_loading_button.dart';

const int _storyExpiration = 86400000;

class StoryComposerScreen extends StatefulWidget {
  final File file;
  final bool isVideo;
  final int? durationMs;

  const StoryComposerScreen({
    super.key,
    required this.file,
    this.isVideo = false,
    this.durationMs,
  });

  @override
  State<StoryComposerScreen> createState() => _StoryComposerScreenState();
}

class _StoryComposerScreenState extends State<StoryComposerScreen> {
  final ValueNotifier<bool> _publishing = ValueNotifier<bool>(false);
  int _audience = 1; // 1 = все, 2 = контакты
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.file(widget.file);
    _video = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _publishing.dispose();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_publishing.value) return;
    _publishing.value = true;
    try {
      if (widget.isVideo) {
        await _publishVideo();
      } else {
        await _publishPhoto();
      }
    } catch (e) {
      _fail(e.toString());
    }
  }

  Future<void> _publishPhoto() async {
    final url = await messagesModule.requestPhotoUploadUrl(type: 1);
    if (url == null || url.isEmpty) {
      _fail('Не удалось получить адрес загрузки');
      return;
    }
    final segments = widget.file.uri.pathSegments;
    final filename = segments.isNotEmpty ? segments.last : 'story.jpg';
    final token = await fileUploader.uploadPhoto(
      Uri.parse(url),
      widget.file,
      filename: filename.isEmpty ? 'story.jpg' : filename,
    );
    if (token == null || token.isEmpty) {
      _fail('Не удалось загрузить фото');
      return;
    }
    await storiesModule.publishPhoto(
      photoToken: token,
      settings: _audience,
      expiration: _storyExpiration,
    );
    _onPublished();
  }

  Future<void> _publishVideo() async {
    final info = await messagesModule.requestVideoUploadUrl(type: 3);
    if (info == null || info.url.isEmpty) {
      _fail('Не удалось получить адрес загрузки');
      return;
    }
    final upload = await fileUploader.uploadVideoWithToken(
      Uri.parse(info.url),
      widget.file,
    );
    if (!upload.ok) {
      _fail('Не удалось загрузить видео');
      return;
    }
    final uploadedToken = upload.token;
    final token = (uploadedToken != null && uploadedToken.isNotEmpty)
        ? uploadedToken
        : info.token;
    if (token.isEmpty) {
      _fail('Не удалось загрузить видео');
      return;
    }
    await storiesModule.publishVideo(
      videoToken: token,
      durationMs: widget.durationMs,
      settings: _audience,
      expiration: _storyExpiration,
    );
    _onPublished();
  }

  void _onPublished() {
    if (!mounted) return;
    Haptics.success();
    Navigator.of(context).pop();
    showCustomNotification(context, 'История опубликована');
    storiesModule.loadFeed();
  }

  void _fail(String message) {
    if (!mounted) {
      _publishing.value = false;
      return;
    }
    Haptics.error();
    _publishing.value = false;
    showCustomNotification(context, message);
  }

  Widget _buildPreview() {
    final Widget foreground;
    final Widget backdrop;
    if (widget.isVideo) {
      final c = _video;
      if (c == null || !c.value.isInitialized) {
        return const CircularProgressIndicator(color: Colors.white);
      }
      final size = c.value.size;
      foreground = Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
      );
      backdrop = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(c),
        ),
      );
    } else {
      foreground = Image.file(widget.file, fit: BoxFit.contain);
      backdrop = Image.file(widget.file, fit: BoxFit.cover);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: backdrop,
          ),
        ),
        const Positioned.fill(child: ColoredBox(color: Colors.black26)),
        foreground,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: _buildPreview()),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: IconButton(
                  icon: const Icon(Symbols.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AudienceToggle(
                      value: _audience,
                      onChanged: (v) {
                        Haptics.selection();
                        setState(() => _audience = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryLoadingButton(
                        loading: _publishing,
                        onPressed: _publish,
                        child: const Text(
                          'Опубликовать',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceToggle extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _AudienceToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, 1, Symbols.public, 'Все'),
          _segment(context, 2, Symbols.group, 'Контакты'),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, int v, IconData icon, String label) {
    final selected = value == v;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? cs.onPrimary : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? cs.onPrimary : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
