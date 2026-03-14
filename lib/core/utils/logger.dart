import 'package:logger/logger.dart';

final logger = Logger(
  // устанавливает минимальный уровень логов.
  // доступны уровни: all, trace, debug, info, warning, error, fatal, off
  level: Level.all,
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
  ),
);
