import 'plugin_manifest.dart';

enum PluginOrigin { bundled, installed }

enum PluginSignatureStatus { unsigned, verified, bundled }

class PluginDescriptor {
  const PluginDescriptor({
    required this.manifest,
    required this.origin,
    required this.enabled,
    required this.grantedPermissions,
    required this.loadModules,
    required this.signatureStatus,
    this.signerFingerprint,
  });

  final PluginManifest manifest;
  final PluginOrigin origin;
  final bool enabled;
  final Set<PluginPermission> grantedPermissions;
  final Future<Map<String, String>> Function() loadModules;
  final PluginSignatureStatus signatureStatus;
  final String? signerFingerprint;

  PluginDescriptor copyWith({bool? enabled}) => PluginDescriptor(
    manifest: manifest,
    origin: origin,
    enabled: enabled ?? this.enabled,
    grantedPermissions: grantedPermissions,
    loadModules: loadModules,
    signatureStatus: signatureStatus,
    signerFingerprint: signerFingerprint,
  );
}

class PluginCommandDescriptor {
  const PluginCommandDescriptor({required this.plugin, required this.command});

  final PluginDescriptor plugin;
  final PluginCommandManifest command;
}

class PluginPackagePreview {
  const PluginPackagePreview({
    required this.manifest,
    required this.bytes,
    required this.signatureStatus,
    this.signerFingerprint,
  });

  final PluginManifest manifest;
  final List<int> bytes;
  final PluginSignatureStatus signatureStatus;
  final String? signerFingerprint;
}

class PluginUpdateInfo {
  const PluginUpdateInfo({
    required this.plugin,
    required this.version,
    required this.packageUrl,
    required this.size,
    required this.sha256,
  });

  final PluginDescriptor plugin;
  final String version;
  final Uri packageUrl;
  final int size;
  final String sha256;
}
