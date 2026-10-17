import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/logger.dart';
import 'call_bridge.dart';
import '../../frontend/widgets/custom_notification.dart';

Future<void> callContactViaPhone(BuildContext context, int phone) async {
  if (phone <= 0) return;
  bool opened = false;
  if (Platform.isAndroid || Platform.isIOS) {
    opened = await CallBridge.instance.callViaPhone(phone);
  }
  if (!opened) {
    final uri = Uri.parse('tel:+$phone');
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      logger.w('callContactViaPhone: $e');
    }
  }
  if (!opened && context.mounted) {
    showCustomNotification(context, 'Не удалось открыть приложение телефона');
  }
}
