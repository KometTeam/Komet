import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gwid/services/contact_local_names_service.dart';
import 'package:gwid/app_sizes.dart';

class ContactNameWidget extends StatefulWidget {
  final int contactId;
  final String? originalName;
  final String? originalFirstName;
  final String? originalLastName;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const ContactNameWidget({
    super.key,
    required this.contactId,
    this.originalName,
    this.originalFirstName,
    this.originalLastName,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  State<ContactNameWidget> createState() => _ContactNameWidgetState();
}

class _ContactNameWidgetState extends State<ContactNameWidget> {
  late String _displayName;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _updateDisplayName();

    _subscription = ContactLocalNamesService().changes.listen((contactId) {
      if (contactId == widget.contactId && mounted) {
        _updateDisplayName();
      }
    });
  }

  @override
  void didUpdateWidget(ContactNameWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contactId != widget.contactId ||
        oldWidget.originalName != widget.originalName ||
        oldWidget.originalFirstName != widget.originalFirstName ||
        oldWidget.originalLastName != widget.originalLastName) {
      _updateDisplayName();
    }
  }

  void _updateDisplayName() {
    setState(() {
      _displayName = ContactLocalNamesService().getDisplayName(
        contactId: widget.contactId,
        originalName: widget.originalName,
        originalFirstName: widget.originalFirstName,
        originalLastName: widget.originalLastName,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayName,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

String getContactDisplayName({
  required int contactId,
  String? originalName,
  String? originalFirstName,
  String? originalLastName,
}) {
  return ContactLocalNamesService().getDisplayName(
    contactId: contactId,
    originalName: originalName,
    originalFirstName: originalFirstName,
    originalLastName: originalLastName,
  );
}
