import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/config/app_shape.dart';
import '../../l10n/app_localizations.dart';

String _resourceLabel(AppLocalizations l10n, PermissionResourceType type) {
  if (type == PermissionResourceType.CAMERA) {
    return l10n.webviewPermissionCamera;
  }
  if (type == PermissionResourceType.MICROPHONE) {
    return l10n.webviewPermissionMicrophone;
  }
  if (type == PermissionResourceType.CAMERA_AND_MICROPHONE) {
    return l10n.webviewPermissionCameraAndMicrophone;
  }
  if (type == PermissionResourceType.GEOLOCATION) {
    return l10n.webviewPermissionGeolocation;
  }
  return l10n.webviewPermissionOther;
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

  final l10n = AppLocalizations.of(context)!;
  final labels = <String>{
    for (final r in request.resources) _resourceLabel(l10n, r),
  }.join(', ');
  final host = request.origin.host.isNotEmpty
      ? request.origin.host
      : l10n.webviewPermissionWebPage;

  final granted = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: AppShape.dialogBorder,
      title: Text(l10n.webviewPermissionTitle),
      content: Text(l10n.webviewPermissionMessage(host, labels)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.webviewPermissionDeny),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.attachSheetAllow),
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
