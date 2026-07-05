import 'package:flutter/material.dart';

extension AppColorTokens on ColorScheme {
  Color get mutedText => onSurfaceVariant.withValues(alpha: 0.6);
}

const int kAvatarThumbSize = 144;

const Color kReadReceiptBlue = Color(0xFF4FC3F7);
const Color kOnlineGreen = Color(0xFF34C759);
const Color kEditorAccent = Color(0xFF2F8FFF);
