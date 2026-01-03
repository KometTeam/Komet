import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gwid/services/contact_local_names_service.dart';
import 'package:gwid/app_sizes.dart';

class ContactAvatarWidget extends StatefulWidget {
  final int contactId;
  final String? originalAvatarUrl;
  final double radius;
  final String? fallbackText;
  final Color? backgroundColor;
  final Color? textColor;

  const ContactAvatarWidget({
    super.key,
    required this.contactId,
    this.originalAvatarUrl,
    this.radius = 24,
    this.fallbackText,
    this.backgroundColor,
    this.textColor,
  });

  @override
  State<ContactAvatarWidget> createState() => _ContactAvatarWidgetState();
}

class _ContactAvatarWidgetState extends State<ContactAvatarWidget> {
  String? _localAvatarPath;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _loadLocalAvatar();

    _subscription = ContactLocalNamesService().changes.listen((contactId) {
      if (contactId == widget.contactId && mounted) {
        _loadLocalAvatar();
      }
    });
  }

  @override
  void didUpdateWidget(ContactAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contactId != widget.contactId ||
        oldWidget.originalAvatarUrl != widget.originalAvatarUrl) {
      _loadLocalAvatar();
    }
  }

  void _loadLocalAvatar() {
    final localPath = ContactLocalNamesService().getContactAvatarPath(
      widget.contactId,
    );
    if (localPath != null) {
      final file = File(localPath);
      if (file.existsSync()) {
        setState(() {
          _localAvatarPath = localPath;
        });
        return;
      }
    }

    if (mounted) {
      setState(() {
        _localAvatarPath = null;
      });
    }
  }

  ImageProvider? _getAvatarImage() {
    if (_localAvatarPath != null) {
      return FileImage(File(_localAvatarPath!));
    } else if (widget.originalAvatarUrl != null) {
      if (widget.originalAvatarUrl!.startsWith('file://')) {
        final path = widget.originalAvatarUrl!.replaceFirst('file://', '');
        return FileImage(File(path));
      }
      return NetworkImage(widget.originalAvatarUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarImage = _getAvatarImage();

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor:
          widget.backgroundColor ?? theme.colorScheme.secondaryContainer,
      backgroundImage: avatarImage,
      child: avatarImage == null
          ? Text(
              widget.fallbackText ?? '?',
              style: TextStyle(
                color:
                    widget.textColor ?? theme.colorScheme.onSecondaryContainer,
                fontSize: widget.radius * 0.8,
              ),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

ImageProvider? getContactAvatarImage({
  required int contactId,
  String? originalAvatarUrl,
}) {
  final localPath = ContactLocalNamesService().getContactAvatarPath(contactId);

  if (localPath != null) {
    final file = File(localPath);
    if (file.existsSync()) {
      return FileImage(file);
    }
  }

  if (originalAvatarUrl != null) {
    if (originalAvatarUrl.startsWith('file://')) {
      final path = originalAvatarUrl.replaceFirst('file://', '');
      return FileImage(File(path));
    }
    return NetworkImage(originalAvatarUrl);
  }

  return null;
}
