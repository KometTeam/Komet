import 'package:flutter_rust_bridge/flutter_rust_bridge.dart'
    show RustStreamSink;
import 'package:kolibri/kolibri.dart';

// #***! kolibri.openSessionWithWireLog не пробрасывает isPwa и headerUserAgent,
// а веб-хэндшейку они нужны. Делаем ровно то же, что обёртка, но от полного
// SessionOptions — так в одном месте собираются и андроид-, и веб-рукопожатие.
(KolibriSession, Stream<WireLogEvent>) openSessionFromOptions(
  SessionOptions options,
) {
  final sink = RustStreamSink<WireLogEvent>();
  final session = KolibriSession(options: options, wireLog: sink);
  return (session, sink.stream);
}
