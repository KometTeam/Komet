import 'dart:io';

import '../utils/logger.dart';

const List<String> _schemes = ['komet', 'max'];

abstract class DesktopUrlScheme {
  static Future<void> register() async {
    try {
      if (Platform.isWindows) {
        await _registerWindows();
      } else if (Platform.isLinux) {
        await _registerLinux();
      }
    } catch (e) {
      logger.w('DesktopUrlScheme: регистрация не удалась: $e');
    }
  }

  static Future<void> _registerWindows() async {
    final exe = Platform.resolvedExecutable;
    for (final scheme in _schemes) {
      final capitalized = '${scheme[0].toUpperCase()}${scheme.substring(1)}';
      final base = 'HKCU\\Software\\Classes\\$scheme';

      await _run('reg', ['add', base, '/ve', '/d', 'URL:$capitalized', '/f']);
      await _run('reg', ['add', base, '/v', 'URL Protocol', '/d', '', '/f']);
      await _run('reg', [
        'add',
        '$base\\shell\\open\\command',
        '/ve',
        '/d',
        '"$exe" "%1"',
        '/f',
      ]);
    }
  }

  static Future<void> _registerLinux() async {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return;

    final exe = Platform.resolvedExecutable;
    final appsDir = Directory('$home/.local/share/applications');
    await appsDir.create(recursive: true);

    const fileName = 'komet-url-handler.desktop';
    final mimeTypes = _schemes.map((s) => 'x-scheme-handler/$s').join(';');
    final desktop = '[Desktop Entry]\n'
        'Type=Application\n'
        'Name=Komet\n'
        'Exec="$exe" %u\n'
        'Terminal=false\n'
        'NoDisplay=true\n'
        'MimeType=$mimeTypes;\n';

    final file = File('${appsDir.path}/$fileName');
    if (!file.existsSync() || await file.readAsString() != desktop) {
      await file.writeAsString(desktop);
    }

    for (final scheme in _schemes) {
      await _run('xdg-mime', ['default', fileName, 'x-scheme-handler/$scheme']);
    }
    await _run('update-desktop-database', [appsDir.path]);
  }

  static Future<void> _run(String executable, List<String> args) async {
    try {
      await Process.run(executable, args);
    } catch (_) {}
  }
}
