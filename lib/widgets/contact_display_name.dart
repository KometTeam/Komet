import 'package:flutter/material.dart';
import 'package:gwid/screens/edit_contact_screen.dart';
import 'package:gwid/app_sizes.dart';

class ContactDisplayName extends StatefulWidget {
  final int contactId;
  final String? originalFirstName;
  final String? originalLastName;
  final String? fallbackName;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const ContactDisplayName({
    super.key,
    required this.contactId,
    this.originalFirstName,
    this.originalLastName,
    this.fallbackName,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  State<ContactDisplayName> createState() => _ContactDisplayNameState();
}

class _ContactDisplayNameState extends State<ContactDisplayName> {
  String? _localFirstName;
  String? _localLastName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  @override
  void didUpdateWidget(ContactDisplayName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contactId != widget.contactId) {
      _loadLocalData();
    }
  }

  Future<void> _loadLocalData() async {
    setState(() {
      _isLoading = true;
    });

    final localData = await ContactLocalDataHelper.getContactData(
      widget.contactId,
    );

    if (mounted) {
      setState(() {
        _localFirstName = localData?['firstName'] as String?;
        _localLastName = localData?['lastName'] as String?;
        _isLoading = false;
      });
    }
  }

  String get _displayName {
    final firstName = _localFirstName ?? widget.originalFirstName ?? '';
    final lastName = _localLastName ?? widget.originalLastName ?? '';
    final fullName = '$firstName $lastName'.trim();

    if (fullName.isNotEmpty) {
      return fullName;
    }

    return widget.fallbackName ?? 'ID ${widget.contactId}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Text(
        widget.fallbackName ?? '...',
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    return Text(
      _displayName,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
