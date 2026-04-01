import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

final logger = Logger(
  level: kReleaseMode ? Level.info : Level.all,
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
  ),
);
