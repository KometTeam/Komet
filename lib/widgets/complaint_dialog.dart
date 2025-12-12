import 'package:flutter/material.dart';
import 'package:gwid/models/complaint.dart';
import 'package:gwid/api/api_service.dart';
import 'dart:async';

class ComplaintDialog extends StatefulWidget {
  final String messageId;
  final int chatId;

  const ComplaintDialog({
    super.key,
    required this.messageId,
    required this.chatId,
  });

  @override
  State<ComplaintDialog> createState() => _ComplaintDialogState();
}

class _ComplaintDialogState extends State<ComplaintDialog> {
  ComplaintData? _complaintData;
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _loadComplaints();
    _listenForComplaintsData();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  void _loadComplaints() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    ApiService.instance.getComplaints();
  }

  void _listenForComplaintsData() {
    _messageSubscription = ApiService.instance.messages.listen((message) {
      if (message['type'] == 'complaints_data' && mounted) {
        setState(() {
          _complaintData = message['complaintData'] as ComplaintData?;
          _isLoading = false;
          _error = null;
        });
      }
    });
  }

  void _handleComplaintSelected(int typeId, int reasonId) {
    ApiService.instance.sendComplaint(
      widget.chatId,
      widget.messageId,
      typeId,
      reasonId,
    );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Жалоба отправлена'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Жалоба на сообщение'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ошибка: $_error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadComplaints,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              )
            : _complaintData == null
            ? const Center(child: Text('Нет данных о жалобах'))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _getAllReasons().length,
                itemBuilder: (context, index) {
                  final reasonData = _getAllReasons()[index];
                  return ListTile(
                    leading: Icon(
                      reasonData['icon'] as IconData,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(reasonData['title'] as String),
                    onTap: () => _handleComplaintSelected(
                      reasonData['typeId'] as int,
                      reasonData['reasonId'] as int,
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getAllReasons() {
    if (_complaintData == null) return [];

    final uniqueReasons = <int, Map<String, dynamic>>{};
    for (final complaintType in _complaintData!.complainTypes) {
      for (final reason in complaintType.reasons) {
        if (!uniqueReasons.containsKey(reason.reasonId)) {
          String title = reason.reasonTitle;
          
          if (reason.reasonId == 11) {
            
            title = 'Абзывательства матюки';
          }

          uniqueReasons[reason.reasonId] = {
            'title': title,
            'typeId': complaintType.typeId,
            'reasonId': reason.reasonId,
            'icon': _getReasonIcon(reason.reasonId),
          };
        }
      }
    }
    return uniqueReasons.values.toList();
  }

  IconData _getReasonIcon(int reasonId) {
    switch (reasonId) {
      case 7: 
        return Icons.more_horiz;
      case 8: 
        return Icons.warning;
      case 9: 
        return Icons.campaign;
      case 10: 
        return Icons.gavel;
      case 11: 
        return Icons.sentiment_very_dissatisfied;
      case 12: 
        return Icons.help_outline;
      default:
        return Icons.report_problem;
    }
  }
}
