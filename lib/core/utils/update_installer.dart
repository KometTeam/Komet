import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'update_checker.dart';

// #***! чем кончилась установка
enum UpdateInstallStatus {
  done,
  noAsset,
  downloadFailed,
  corrupted,
  installFailed,
}

class UpdateInstallResult {
  final UpdateInstallStatus status;
  final String? error;

  const UpdateInstallResult(this.status, {this.error});

  bool get ok => status == UpdateInstallStatus.done;
}

// #***! приёмник для потокового sha256, хэшируем прямо при скачивании
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

// #***! скачивание и установка APK, только андроид
abstract class UpdateInstaller {
  static bool get isSupported => Platform.isAndroid;

  // #***! весь путь, выбрать скачать проверить отдать установщику
  static Future<UpdateInstallResult> downloadAndInstall(
    AppUpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final asset = await resolveApk(info);
    if (asset == null) {
      return const UpdateInstallResult(UpdateInstallStatus.noAsset);
    }

    File file;
    try {
      file = await _download(asset, info.tag, onProgress);
    } on _ChecksumMismatch catch (e) {
      return UpdateInstallResult(
        UpdateInstallStatus.corrupted,
        error: e.toString(),
      );
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

  // #***! APK под ABI устройства и флейвор, иначе универсальный
  static Future<UpdateAsset?> resolveApk(AppUpdateInfo info) async {
    if (!Platform.isAndroid || info.assets.isEmpty) return null;

    final packageInfo = await PackageInfo.fromPlatform();
    final flavor = packageInfo.packageName == 'ru.oneme.app' ? 'oneme' : 'komet';

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final abis = androidInfo.supportedAbis;

    for (final abi in abis) {
      final asset = info.assetWithSuffix('-$flavor-$abi.apk');
      if (asset != null) return asset;
    }
    return info.assetWithSuffix('-$flavor-universal.apk');
  }

  // #***! качаем в .part и переименовываем после проверки
  static Future<File> _download(
    UpdateAsset asset,
    String tag,
    void Function(double progress)? onProgress,
  ) async {
    final dir = await getTemporaryDirectory();
    final safeTag = tag.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${dir.path}/komet-update-$safeTag.apk');
    final part = File('${file.path}.part');

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(asset.url));
      request.headers.set(HttpHeaders.userAgentHeader, 'KometUpdateInstaller');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException(
          'HTTP ${response.statusCode}',
          uri: Uri.parse(asset.url),
        );
      }

      // #***! хэш на лету чтоб не читать файл второй раз
      final total = response.contentLength > 0
          ? response.contentLength
          : asset.size;
      var received = 0;
      final digestSink = _DigestSink();
      final hasher = sha256.startChunkedConversion(digestSink);
      final sink = part.openWrite();
      await for (final chunk in response) {
        received += chunk.length;
        hasher.add(chunk);
        sink.add(chunk);
        if (onProgress != null && total > 0) {
          onProgress(received / total);
        }
      }
      await sink.close();
      hasher.close();

      // #***! размер или sha не сошлись, файл битый установщику не отдаём
      if (asset.size > 0 && received != asset.size) {
        throw _ChecksumMismatch('size ${asset.size}', 'size $received');
      }
      final actual = digestSink.value?.toString() ?? '';
      if (asset.sha256.isNotEmpty && actual != asset.sha256) {
        throw _ChecksumMismatch(asset.sha256, actual);
      }

      if (await file.exists()) await file.delete();
      await part.rename(file.path);
      return file;
    // #***! при любой ошибке недокачанное удаляем
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

class _ChecksumMismatch implements Exception {
  final String expected;
  final String actual;

  const _ChecksumMismatch(this.expected, this.actual);

  @override
  String toString() => 'Update payload mismatch: expected $expected, got $actual';
}
