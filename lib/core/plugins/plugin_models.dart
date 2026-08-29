import 'plugin_manifest.dart';

enum PluginOrigin { bundled, installed }

class PluginDescriptor {
  const PluginDescriptor({
    required this.manifest,
    required this.origin,
    required this.enabled,
    required this.grantedPermissions,
    required this.loadModules,
  });

  final PluginManifest manifest;
  final PluginOrigin origin;
  final bool enabled;
  final Set<PluginPermission> grantedPermissions;
  final Future<Map<String, String>> Function() loadModules;

  PluginDescriptor copyWith({bool? enabled}) => PluginDescriptor(
    manifest: manifest,
    origin: origin,
    enabled: enabled ?? this.enabled,
    grantedPermissions: grantedPermissions,
    loadModules: loadModules,
  );
}

class PluginCommandDescriptor {
  const PluginCommandDescriptor({required this.plugin, required this.command});

  final PluginDescriptor plugin;
  final PluginCommandManifest command;
}

class PluginPackagePreview {
  const PluginPackagePreview({required this.manifest, required this.bytes});

  final PluginManifest manifest;
  final List<int> bytes;
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
