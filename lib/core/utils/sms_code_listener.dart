import 'dart:io';
import 'package:smart_auth/smart_auth.dart';

typedef SmsCodeCallback = void Function(String code);

class SmsCodeListener {
  static const String _matcher = r'\d{6}';

  final SmartAuth _smartAuth = SmartAuth.instance;
  bool _listening = false;
  bool _disposed = false;

  bool get _supported => Platform.isAndroid;

  Future<void> start(SmsCodeCallback onCode) async {
    if (!_supported || _listening || _disposed) return;
    _listening = true;

    final result = await _smartAuth.getSmsWithUserConsentApi(matcher: _matcher);

    _listening = false;
    if (_disposed) return;

    final code = result.hasData ? result.requireData.code : null;
    if (code != null) onCode(code);
  }

  Future<void> cancel() async {
    if (!_supported) return;
    await _smartAuth.removeUserConsentApiListener();
    _listening = false;
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}
