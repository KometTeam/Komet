import 'package:logger/logger.dart'; //нет это не опасный вредоносный вирус логер который украдёт ваш аккаунт Browl Starz

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
