import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

String _resourceLabel(PermissionResourceType type) {
  if (type == PermissionResourceType.CAMERA) return 'камера';
  if (type == PermissionResourceType.MICROPHONE) return 'микрофон';
  if (type == PermissionResourceType.CAMERA_AND_MICROPHONE) {
    return 'камера и микрофон';
  }
  if (type == PermissionResourceType.GEOLOCATION) return 'геолокация';
  return 'дополнительный доступ';
}

Future<PermissionResponse> askWebViewPermission(
  BuildContext context,
  PermissionRequest request,
) async {
  PermissionResponse deny() => PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.DENY,
      );

  if (!context.mounted) return deny();

  final labels = <String>{
    for (final r in request.resources) _resourceLabel(r),
  }.join(', ');
  final host = request.origin.host.isNotEmpty
      ? request.origin.host
      : 'Веб-страница';

  final granted = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Запрос доступа'),
      content: Text('$host запрашивает доступ к: $labels.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Запретить'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Разрешить'),
        ),
      ],
    ),
  );

  return PermissionResponse(
    resources: request.resources,
    action: granted == true
        ? PermissionResponseAction.GRANT
        : PermissionResponseAction.DENY,
  );
}
