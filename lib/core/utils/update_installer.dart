import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'update_checker.dart';

enum UpdateInstallStatus { done, noAsset, downloadFailed, installFailed }

class UpdateInstallResult {
  final UpdateInstallStatus status;
  final String? error;

  const UpdateInstallResult(this.status, {this.error});

  bool get ok => status == UpdateInstallStatus.done;
}

abstract class UpdateInstaller {
  static bool get isSupported => Platform.isAndroid;

  static Future<UpdateInstallResult> downloadAndInstall(
    AppUpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final url = await resolveApkUrl(info);
    if (url == null) {
      return const UpdateInstallResult(UpdateInstallStatus.noAsset);
    }

    File file;
    try {
      file = await _download(url, info.tag, onProgress);
    } catch (e) {
      return UpdateInstallResult(
        UpdateInstallStatus.downloadFailed,
        error: e.toString(),
      );
    }

    final opened = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (opened.type != ResultType.done) {
      return UpdateInstallResult(
        UpdateInstallStatus.installFailed,
        error: opened.message,
      );
    }
    return const UpdateInstallResult(UpdateInstallStatus.done);
  }

  static Future<String?> resolveApkUrl(AppUpdateInfo info) async {
    if (!Platform.isAndroid || info.assets.isEmpty) return null;

    final packageInfo = await PackageInfo.fromPlatform();
    final flavor = packageInfo.packageName == 'ru.oneme.app' ? 'oneme' : 'komet';

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final abis = androidInfo.supportedAbis;

    for (final abi in abis) {
      final url = _findAsset(info.assets, '-$flavor-$abi.apk');
      if (url != null) return url;
    }
    return _findAsset(info.assets, '-$flavor-universal.apk');
  }

  static String? _findAsset(Map<String, String> assets, String suffix) {
    for (final entry in assets.entries) {
      if (entry.key.endsWith(suffix)) return entry.value;
    }
    return null;
  }

  static Future<File> _download(
    String url,
    String tag,
    void Function(double progress)? onProgress,
  ) async {
    final dir = await getTemporaryDirectory();
    final safeTag = tag.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${dir.path}/komet-update-$safeTag.apk');
    final part = File('${file.path}.part');

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'KometUpdateInstaller');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }

      final total = response.contentLength;
      var received = 0;
      final sink = part.openWrite();
      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        if (onProgress != null && total > 0) {
          onProgress(received / total);
        }
      }
      await sink.close();
      if (await file.exists()) await file.delete();
      await part.rename(file.path);
      return file;
    } catch (e) {
      if (await part.exists()) {
        try {
          await part.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      client.close();
    }
  }
}
