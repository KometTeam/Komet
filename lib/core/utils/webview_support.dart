import 'package:flutter/foundation.dart';

bool get webViewSupported {
  if (kIsWeb) return true;
  return defaultTargetPlatform != TargetPlatform.linux;
}
