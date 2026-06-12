import 'package:logger/logger.dart';

class FileLogOutput extends LogOutput {
  FileLogOutput._();

  static final FileLogOutput instance = FileLogOutput._();

  String? get path => null;

  Future<void> start() async {}

  @override
  void output(OutputEvent event) {}
}
