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
  final geo = Uri.parse('geo:$latitude,$longitude?z=$z');
  if (await canLaunchUrl(geo)) {
    final ok = await launchUrl(geo, mode: LaunchMode.externalApplication);
    if (ok) return;
  }
  if (!context.mounted) return;
  await openExternalUrl(
    context,
    'https://yandex.ru/maps/?pt=$longitude,$latitude&z=$z&l=map',
  );
}
