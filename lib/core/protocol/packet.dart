// #***! cmd в заголовке 0 запрос 1 ок 2 не найдено 3 ошибка
/// Типы команд в протоколе
abstract class CmdType {
  static const int request =
      0; // запрос клиента / пуш от сервера (направление определяет смысл)
  static const int push = 0; // пуш от сервера (имеет смысл только для incoming)

  static const int ok = 1; // ответ: ок
  static const int notFound = 2; // ответ: не найдено
  static const int error = 3; // ответ: ошибка
}

// #***! распакованный пакет, остальное в расте
/// Распакованный пакет.
///
/// Провод (фрейминг, MsgPack, сжатие) живёт в Rust-ядре kolibri; здесь пакет —
/// это уже декодированный [payload] (Map/List/скаляр, бинарь — Uint8List) плюс
/// метаданные заголовка.
class Packet {
  int api;
  int cmd;
  int seq;
  int opcode;
  dynamic payload;

  Packet({
    this.api = 10,
    this.cmd = 0,
    this.seq = 0,
    this.opcode = 0,
    this.payload,
  });

  bool get isOk => cmd == CmdType.ok;
  bool get isError => cmd == CmdType.error;
  bool get isPush => cmd == CmdType.push;

  @override
  String toString() =>
      'Packet(ver=$api cmd=$cmd seq=$seq opcode=$opcode payload=$payload)';
}

// #***! ошибка от сервера, errorKey машинный код
class PacketError implements Exception {
  final String message;
  final String? errorKey;
  const PacketError(this.message, {this.errorKey});
  @override
  String toString() => message;
}

// #***! токен отклонён, надо перелогиниться
class SessionExpiredException extends PacketError {
  const SessionExpiredException(super.message);
}

// #***! пробовать ли ещё, not.ready это временно
bool isPermanentSendFailure(Object error) {
  if (error is! PacketError) return false;
  if (error is SessionExpiredException) return false;
  return !(error.errorKey?.contains('not.ready') ?? false);
}

// #***! достаём текст ошибки из payload
String messageFromErrorPayload(dynamic payload) {
  if (payload is Map) {
    final msg = payload['message'];
    if (msg == 'FAIL_WRONG_PASSWORD' || msg == 'FAIL_LOGIN_TOKEN') {
      return 'Ваш токен был отклонён сервером, хм... Попробуйте войти ещё раз.';
    }
    for (final key in ['localizedMessage', 'title', 'message']) {
      final v = payload[key];
      if (v is! String) continue;
      final text = v.trim();
      if (text.isEmpty || _isRawServerTemplate(text)) continue;
      return text;
    }
    return 'Неизвестная ошибка';
  }
  if (payload == null) return 'Неизвестная ошибка';
  final s = payload.toString();
  return s.isNotEmpty ? s : 'Неизвестная ошибка';
}

// #***! сырой шаблон Key: юзеру не показываем
bool _isRawServerTemplate(String text) =>
    text.startsWith('Key: ') || text.startsWith('key: ');

// #***! протухла ли авторизация
bool isSessionExpiredPayload(dynamic payload) {
  return payload is Map &&
      (payload['message'] == 'FAIL_LOGIN_TOKEN' ||
          payload['message'] == 'FAIL_WRONG_PASSWORD');
}

// #***! ошибка превращается в исключение
void throwIfPacketError(Packet packet) {
  if (!packet.isError) return;
  final payload = packet.payload;
  if (isSessionExpiredPayload(payload)) {
    throw SessionExpiredException(messageFromErrorPayload(payload));
  }
  throw PacketError(messageFromErrorPayload(payload));
}

// #***! сессия отвалилась, ловим по тексту кода то нет
bool isSessionStateError(Object error) {
  if (error is SessionExpiredException) return true;
  final text = error.toString().toLowerCase();
  return text.contains('состояние сессии') ||
      text.contains('сессия не найдена') ||
      text.contains('авторизационная сессия') ||
      text.contains('сессия не онлайн');
}

// #***! потеряна авторизационная сессия
bool isAuthSessionLostError(Object error) {
  if (error is SessionExpiredException) return true;
  final text = error.toString().toLowerCase();
  return text.contains('сессия не найдена') ||
      text.contains('авторизационная сессия');
}
