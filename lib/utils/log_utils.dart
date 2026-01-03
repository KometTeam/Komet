import 'package:gwid/consts.dart';

//Потому что заебало блять на пол консоли один запрос
String truncatePayloadForLog(String payload) {
  if (payload.length <= AppLimits.maxLogPayloadLength) {
    return payload;
  }
  return '${payload.substring(0, AppLimits.maxLogPayloadLength)}... (обрезано, длина: ${payload.length})';
}

String truncatePayloadObjectForLog(dynamic payload) {
  final payloadStr = payload.toString();
  return truncatePayloadForLog(payloadStr);
}
