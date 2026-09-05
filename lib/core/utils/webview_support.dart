import 'package:flutter/foundation.dart';

// #***! на линуксе вебвью нет, экраны мини аппок прячем
bool get webViewSupported {
  if (kIsWeb) return true;
  return defaultTargetPlatform != TargetPlatform.linux;
}
