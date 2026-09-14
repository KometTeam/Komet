/// This is copied from Cargokit (which is the official way to use it currently)
/// Details: https://fzyzcjy.github.io/flutter_rust_bridge/manual/integrate/builtin

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import 'options.dart';

enum _HashEntryType {
  file,
  directory,
}

class _HashEntry {
  const _HashEntry({
    required this.relativePath,
    required this.type,
    this.file,
  });

  final String relativePath;
  final _HashEntryType type;
  final File? file;
}

class CrateHash {
  static const _textExtensions = {
    '.rs',
    '.toml',
    '.yaml',
    '.yml',
    '.dart',
    '.sh',
    '.swift',
    '.json',
    '.md',
    '.lock',
  };

  /// Computes a hash uniquely identifying crate content. This takes into account
  /// content all all .rs files inside the src directory, as well as Cargo.toml,
  /// Cargo.lock, build.rs and cargokit.yaml.
  ///
  /// [tempStorage] is retained for call compatibility but is no longer used;
  /// file content remains authoritative on every call.
  static String compute(String manifestDir, {String? tempStorage}) {
    return CrateHash._(
      manifestDir: manifestDir,
    )._compute();
  }

  CrateHash._({
    required this.manifestDir,
  });

  String _compute() {
    return _computeHash(_getInputs());
  }

  String _computeHash(List<_HashEntry> inputs) {
    final output = AccumulatorSink<Digest>();
    final input = sha256.startChunkedConversion(output);
    final data = ByteData(8);

    for (final hashInput in inputs) {
      _addFramedBytes(input, [hashInput.type.index], data);
      _addFramedBytes(input, utf8.encode(hashInput.relativePath), data);
      _addFramedBytes(
        input,
        hashInput.file == null ? const [] : _canonicalContent(hashInput.file!),
        data,
      );
    }

    input.close();
    final res = output.events.single;

    return res.toString();
  }

  static List<int> _canonicalContent(File file) {
    final bytes = file.readAsBytesSync();
    final extension = path.extension(file.path).toLowerCase();
    if (!_textExtensions.contains(extension)) {
      return bytes;
    }
    final text = utf8.decode(bytes);
    return utf8.encode(text.replaceAll('\r\n', '\n'));
  }

  static void _addUint64(
    ByteConversionSink input,
    ByteData data,
    int value,
  ) {
    data.setUint64(0, value);
    input.add(data.buffer.asUint8List());
  }

  static void _addFramedBytes(
    ByteConversionSink input,
    List<int> bytes,
    ByteData data,
  ) {
    _addUint64(input, data, bytes.length);
    input.add(bytes);
  }

  List<_HashEntry> _getInputs() {
    final manifestPath = path.normalize(path.absolute(manifestDir));
    _rejectAbsoluteSymlinkComponents(manifestPath, 'Crate manifest path');
    final precompiled = CargokitCrateOptions.load(manifestDir: manifestPath)
        .precompiledBinaries;
    final configuredWorkspaceRoot = path.normalize(path.absolute(path.join(
      manifestPath,
      precompiled?.workspaceRoot ?? '.',
    )));
    _rejectAbsoluteSymlinkComponents(
      configuredWorkspaceRoot,
      'Workspace root',
    );

    final workspaceRoot =
        Directory(configuredWorkspaceRoot).resolveSymbolicLinksSync();
    final resolvedManifest = Directory(manifestPath).resolveSymbolicLinksSync();
    if (workspaceRoot != resolvedManifest &&
        !path.isWithin(workspaceRoot, resolvedManifest)) {
      throw FileSystemException(
        'Workspace root must contain the crate manifest.',
        configuredWorkspaceRoot,
      );
    }

    final inputs = <String, _HashEntry>{};

    void addFile(File file) {
      final absolute = path.normalize(path.absolute(file.path));
      if (absolute != workspaceRoot &&
          !path.isWithin(workspaceRoot, absolute)) {
        throw FileSystemException(
          'Hash input escapes the workspace root.',
          absolute,
        );
      }
      final relative = _normalizedRelativePath(absolute, workspaceRoot);
      inputs[relative] = _HashEntry(
        relativePath: relative,
        type: _HashEntryType.file,
        file: file,
      );
    }

    void addDirectory(Directory directory) {
      final absolute = path.normalize(path.absolute(directory.path));
      if (absolute != workspaceRoot &&
          !path.isWithin(workspaceRoot, absolute)) {
        throw FileSystemException(
          'Hash input escapes the workspace root.',
          absolute,
        );
      }
      final relative = _normalizedRelativePath(absolute, workspaceRoot);
      inputs[relative] = _HashEntry(
        relativePath: relative,
        type: _HashEntryType.directory,
      );
    }

    void addEntity(FileSystemEntity entity) {
      final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw FileSystemException(
          'Symbolic links are not allowed in generation hash inputs.',
          entity.path,
        );
      }
      if (type == FileSystemEntityType.file) {
        addFile(File(entity.path));
        return;
      }
      if (type == FileSystemEntityType.directory) {
        addDirectory(Directory(entity.path));
        final children = Directory(entity.path).listSync(followLinks: false)
          ..sort((left, right) => left.path.compareTo(right.path));
        for (final child in children) {
          addEntity(child);
        }
        return;
      }
      if (type == FileSystemEntityType.notFound) {
        throw FileSystemException(
            'Generation hash input does not exist.', entity.path);
      }
      throw FileSystemException(
        'Unsupported generation hash input type.',
        entity.path,
      );
    }

    final src = Directory(path.join(resolvedManifest, 'src'));
    addEntity(src);

    void addOptionalManifestFile(String relative) {
      final filePath = path.join(resolvedManifest, relative);
      final type = FileSystemEntity.typeSync(filePath, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        return;
      }
      addEntity(File(filePath));
    }

    addOptionalManifestFile('Cargo.toml');
    addOptionalManifestFile('Cargo.lock');
    addOptionalManifestFile('build.rs');
    addOptionalManifestFile('cargokit.yaml');

    for (final declaredInput in precompiled?.hashInputs ?? const <String>[]) {
      final absolute = path.normalize(path.joinAll([
        workspaceRoot,
        ...path.posix.split(declaredInput),
      ]));
      if (absolute != workspaceRoot &&
          !path.isWithin(workspaceRoot, absolute)) {
        throw FileSystemException(
          'Declared hash input escapes the workspace root.',
          declaredInput,
        );
      }
      _rejectSymlinkComponents(workspaceRoot, absolute);
      addEntity(FileSystemEntity.isDirectorySync(absolute)
          ? Directory(absolute)
          : File(absolute));
    }

    final result = inputs.values.toList()
      ..sort((left, right) => left.relativePath.compareTo(right.relativePath));
    return result;
  }

  static String _normalizedRelativePath(String absolute, String root) {
    final relative = path.relative(absolute, from: root);
    return path.posix.joinAll(path.split(relative));
  }

  static void _rejectSymlinkComponents(String root, String target) {
    var current = root;
    for (final component in path.split(path.relative(target, from: root))) {
      current = path.join(current, component);
      _rejectLink(current, 'Generation hash input');
    }
  }

  static void _rejectAbsoluteSymlinkComponents(
    String target,
    String description,
  ) {
    final root = path.rootPrefix(target);
    var current = root;
    final relative = path.relative(target, from: root);
    if (relative == '.') {
      _rejectLink(current, description);
      return;
    }
    for (final component in path.split(relative)) {
      current = path.join(current, component);
      _rejectLink(current, description);
    }
  }

  static void _rejectLink(String entityPath, String description) {
    if (FileSystemEntity.typeSync(entityPath, followLinks: false) ==
        FileSystemEntityType.link) {
      throw FileSystemException(
        '$description must not contain symbolic links.',
        entityPath,
      );
    }
  }

  List<File> getFiles() {
    return _getInputs()
        .map((input) => input.file)
        .whereType<File>()
        .toList(growable: false);
  }

  final String manifestDir;
}
