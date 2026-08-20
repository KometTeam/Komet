import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../frontend/widgets/custom_notification.dart';
import '../../frontend/widgets/max_link_handler.dart';

Future<void> openExternalUrl(BuildContext context, String url) async {
  if (await tryHandleMaxLink(context, url)) return;
  if (!context.mounted) return;

  final uri = Uri.tryParse(url);
  if (uri == null) {
    showCustomNotification(context, 'Некорректная ссылка');
    return;
  }
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    showCustomNotification(context, 'Не удалось открыть ссылку');
  }
}

Future<void> openLocationOnMap(
  BuildContext context,
  double latitude,
  double longitude, {
  double? zoom,
}) async {
  final z = (zoom ?? 15).round();
  for (final uri in _nativeMapUris(latitude, longitude, z)) {
    try {
      if (!await canLaunchUrl(uri)) continue;
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      continue;
    }
  }
  if (!context.mounted) return;
  await openExternalUrl(
    context,
    'https://yandex.ru/maps/?pt=$longitude,$latitude&z=$z&l=map',
  );
}

List<Uri> _nativeMapUris(double latitude, double longitude, int zoom) {
  if (Platform.isIOS) {
    return [
      Uri.parse(
        'yandexmaps://maps.yandex.ru/'
        '?ll=$longitude,$latitude&z=$zoom&pt=$longitude,$latitude',
      ),
      Uri.parse('maps://?ll=$latitude,$longitude&q=$latitude,$longitude'),
    ];
  }
  return [Uri.parse('geo:$latitude,$longitude?z=$zoom')];
}
