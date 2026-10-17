import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../../core/utils/logger.dart';

class NetworkPhoto extends StatefulWidget {
  const NetworkPhoto({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    required this.memWidth,
    required this.memHeight,
    required this.fallback,
    this.logId,
  });

  static const List<Duration> retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 6),
    Duration(seconds: 20),
  ];

  final String url;
  final double width;
  final double height;
  final int memWidth;
  final int memHeight;
  final WidgetBuilder fallback;
  final Object? logId;

  static String describeError(Object error) => switch (error) {
    HttpExceptionWithStatus(:final statusCode) => 'HTTP $statusCode',
    HttpException(:final message) => 'HttpException: $message',
    _ => error.runtimeType.toString(),
  };

  @override
  State<NetworkPhoto> createState() => _NetworkPhotoState();
}

class _NetworkPhotoState extends State<NetworkPhoto> {
  int _attempt = 0;
  Timer? _retry;

  @override
  void didUpdateWidget(NetworkPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) return;
    _retry?.cancel();
    _retry = null;
    _attempt = 0;
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  void _failed(Object error) {
    if (_retry != null) return;
    final delays = NetworkPhoto.retryDelays;
    if (_attempt == 0 || _attempt == delays.length) {
      logger.w(
        'Фото ${widget.logId ?? '?'} не загрузилось '
        '(попытка ${_attempt + 1}): ${NetworkPhoto.describeError(error)}',
      );
    }
    if (_attempt >= delays.length) return;
    _retry = Timer(delays[_attempt], () {
      if (!mounted) return;
      setState(() {
        _retry = null;
        _attempt++;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      key: ValueKey(_attempt),
      imageUrl: widget.url,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.cover,
      memCacheWidth: widget.memWidth,
      memCacheHeight: widget.memHeight,
      fadeInDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      placeholder: (context, _) => widget.fallback(context),
      errorWidget: (context, _, error) => _ReportOnMount(
        onMount: () => _failed(error),
        child: widget.fallback(context),
      ),
    );
  }
}

class _ReportOnMount extends StatefulWidget {
  const _ReportOnMount({required this.onMount, required this.child});

  final VoidCallback onMount;
  final Widget child;

  @override
  State<_ReportOnMount> createState() => _ReportOnMountState();
}

class _ReportOnMountState extends State<_ReportOnMount> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
