import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart';
import 'package:http/http.dart';
import 'package:path/path.dart' as path;

import 'options.dart';
import 'precompiled_generation.dart';

typedef PrecompiledHttpSend = Future<StreamedResponse> Function(
    BaseRequest request);
typedef PrecompiledHttpExchange = ({
  PrecompiledHttpSend send,
  void Function() close,
});
typedef PrecompiledHttpExchangeFactory = PrecompiledHttpExchange Function();
typedef PrecompiledSleeper = Future<void> Function(Duration duration);
typedef PrecompiledWallClock = DateTime Function();
typedef PrecompiledMonotonicClock = Duration Function();
typedef PrecompiledFileRecorder = void Function(String event, String filePath);

class PrecompiledTransportException extends PrecompiledGenerationException {
  PrecompiledTransportException(super.message);
}

class PrecompiledTransportPolicy {
  const PrecompiledTransportPolicy({
    this.headerDeadline = const Duration(seconds: 15),
    this.idleDeadline = const Duration(seconds: 15),
    this.totalDeadline = const Duration(minutes: 5),
    this.baseBackoff = const Duration(milliseconds: 250),
    this.retryAfterCap = const Duration(seconds: 5),
    this.maxAttempts = 3,
    this.maxRedirects = 5,
  });

  final Duration headerDeadline;
  final Duration idleDeadline;
  final Duration totalDeadline;
  final Duration baseBackoff;
  final Duration retryAfterCap;
  final int maxAttempts;
  final int maxRedirects;
}

class PrecompiledAssetTransport {
  PrecompiledAssetTransport({
    PrecompiledHttpSend? send,
    Client? client,
    PrecompiledHttpExchangeFactory? exchangeFactory,
    this.policy = const PrecompiledTransportPolicy(),
    PrecompiledSleeper? sleeper,
    PrecompiledSleeper? deadlineSleeper,
    PrecompiledWallClock? wallClock,
    PrecompiledMonotonicClock? monotonicClock,
    PrecompiledFileRecorder? fileRecorder,
  })  : _exchangeFactory = exchangeFactory ??
            _newExchangeFactory(
              send: send,
              client: client,
            ),
        _deadlineSleeper = deadlineSleeper,
        sleeper = sleeper ?? Future<void>.delayed,
        wallClock = wallClock ?? DateTime.now,
        monotonicClock = monotonicClock ?? _newMonotonicClock(),
        fileRecorder = fileRecorder ?? _ignoreFileEvent {
    if (policy.maxAttempts < 1 || policy.maxRedirects < 0) {
      throw ArgumentError('Transport attempt and redirect limits are invalid.');
    }
    if (exchangeFactory != null && (send != null || client != null)) {
      throw ArgumentError(
          'An HTTP exchange factory cannot be combined with send or client.');
    }
  }

  final PrecompiledHttpExchangeFactory _exchangeFactory;
  final Set<_PrecompiledHttpExchangeLease> _activeExchanges = {};
  bool _closed = false;
  final PrecompiledSleeper? _deadlineSleeper;
  final PrecompiledTransportPolicy policy;
  final PrecompiledSleeper sleeper;
  final PrecompiledWallClock wallClock;
  final PrecompiledMonotonicClock monotonicClock;
  final PrecompiledFileRecorder fileRecorder;

  void close() {
    if (_closed) return;
    _closed = true;
    for (final exchange in _activeExchanges.toList()) {
      exchange.close();
    }
    _activeExchanges.clear();
  }

  Future<Uint8List?> getBytes(
    Uri uri, {
    required int limit,
    int? expectedLength,
    bool allowNotFound = false,
  }) async {
    _validateBounds(limit, expectedLength);
    final start = monotonicClock();
    return _attempt<Uint8List?>(uri, start, (response, closeExchange) async {
      final bytes = <int>[];
      await _consume(
        response,
        uri: uri,
        start: start,
        limit: limit,
        expectedLength: expectedLength,
        onChunk: bytes.addAll,
        closeExchange: closeExchange,
      );
      return Uint8List.fromList(bytes);
    }, allowNotFound: allowNotFound);
  }

  Future<void> downloadToFile(
    Uri uri,
    File destination, {
    required int limit,
    required int expectedLength,
    required String expectedSha256,
    required bool deleteOnFailure,
  }) async {
    _validateBounds(limit, expectedLength);
    var ownsDestination = false;
    var completed = false;
    try {
      destination.parent.createSync(recursive: true);
      await destination.create(exclusive: true);
      ownsDestination = true;
      final start = monotonicClock();
      await _attempt<void>(uri, start, (response, closeExchange) async {
        final outputFile = await destination.open(mode: FileMode.writeOnly);
        fileRecorder('open', destination.path);
        final digestOutput = AccumulatorSink<Digest>();
        final digestInput = sha256.startChunkedConversion(digestOutput);
        var digestClosed = false;
        try {
          await _consume(
            response,
            uri: uri,
            start: start,
            limit: limit,
            expectedLength: expectedLength,
            onChunk: (chunk) async {
              digestInput.add(chunk);
              await outputFile.writeFrom(chunk);
            },
            closeExchange: closeExchange,
          );
          digestInput.close();
          digestClosed = true;
          if (digestOutput.events.single.toString() != expectedSha256) {
            throw PrecompiledTransportException(
                'Downloaded asset digest does not match signed metadata.');
          }
          await outputFile.flush();
          fileRecorder('flush', destination.path);
        } finally {
          if (!digestClosed) digestInput.close();
          await outputFile.close();
          fileRecorder('close', destination.path);
        }
      });
      completed = true;
    } on PrecompiledTransportException {
      rethrow;
    } on FileSystemException catch (error) {
      throw PrecompiledTransportException(
          'Failed to stage downloaded asset: ${error.message}');
    } finally {
      if (deleteOnFailure && ownsDestination && !completed) {
        try {
          if (destination.existsSync()) destination.deleteSync();
        } on FileSystemException {
          // Preserve the primary verification or transport failure.
        }
      }
    }
  }

  Future<T> _attempt<T>(
    Uri initialUri,
    Duration start,
    Future<T> Function(
      StreamedResponse response,
      void Function() closeExchange,
    ) consume, {
    bool allowNotFound = false,
  }) async {
    for (var attempt = 1; attempt <= policy.maxAttempts; attempt++) {
      try {
        return await _withExchange(
          (exchange) => _requestOnce(
            initialUri,
            start,
            exchange,
            consume,
            allowNotFound: allowNotFound,
          ),
        );
      } on _RetryableTransportException catch (error) {
        if (attempt == policy.maxAttempts) {
          throw PrecompiledTransportException(error.message);
        }
        await _sleepBeforeRetry(start, error.retryAfter ?? _backoff(attempt));
      } on SocketException catch (error) {
        if (attempt == policy.maxAttempts) {
          throw PrecompiledTransportException(
              'Network failure downloading $initialUri: $error');
        }
        await _sleepBeforeRetry(start, _backoff(attempt));
      } on HttpException catch (error) {
        if (attempt == policy.maxAttempts) {
          throw PrecompiledTransportException(
              'Network failure downloading $initialUri: $error');
        }
        await _sleepBeforeRetry(start, _backoff(attempt));
      } on ClientException catch (error) {
        if (attempt == policy.maxAttempts) {
          throw PrecompiledTransportException(
              'Network failure downloading $initialUri: $error');
        }
        await _sleepBeforeRetry(start, _backoff(attempt));
      } on TimeoutException catch (error) {
        if (attempt == policy.maxAttempts) {
          throw PrecompiledTransportException(
              'Network deadline downloading $initialUri: $error');
        }
        await _sleepBeforeRetry(start, _backoff(attempt));
      }
    }
    throw StateError('unreachable');
  }

  Future<T> _requestOnce<T>(
    Uri initialUri,
    Duration start,
    _PrecompiledHttpExchangeLease exchange,
    Future<T> Function(
      StreamedResponse response,
      void Function() closeExchange,
    ) consume, {
    required bool allowNotFound,
  }) async {
    var uri = initialUri;
    _validateHttpUri(uri);
    for (var redirects = 0;; redirects++) {
      _checkTotal(start);
      final request = Request('GET', uri)
        ..followRedirects = false
        ..maxRedirects = 0;
      final response = await _sendHeaders(
        exchange,
        request,
        _boundedDeadline(start, policy.headerDeadline),
        'HTTP header deadline exceeded for $uri.',
      );
      final status = response.statusCode;
      if (_redirectStatuses.contains(status)) {
        await _discard(response, start: start, closeExchange: exchange.close);
        if (redirects >= policy.maxRedirects) {
          throw PrecompiledTransportException(
              'Too many HTTP redirects downloading $initialUri.');
        }
        final location = response.headers['location'];
        if (location == null || location.isEmpty) {
          throw PrecompiledTransportException(
              'HTTP redirect from $uri has no location.');
        }
        final next = uri.resolve(location);
        _validateHttpUri(next);
        if (uri.scheme == 'https' && next.scheme != 'https') {
          throw PrecompiledTransportException(
              'Refusing HTTPS downgrade redirect from $uri.');
        }
        uri = next;
        continue;
      }
      if (_retryStatuses.contains(status)) {
        final retryAfter = _retryAfter(response.headers['retry-after']);
        await _discard(response, start: start, closeExchange: exchange.close);
        throw _RetryableTransportException(
          'Retryable HTTP status $status downloading $uri.',
          retryAfter,
        );
      }
      if (status == 404 && allowNotFound) {
        await _discard(response, start: start, closeExchange: exchange.close);
        return null as T;
      }
      if (status != 200) {
        await _discard(response, start: start, closeExchange: exchange.close);
        throw PrecompiledTransportException(
            'HTTP status $status downloading $uri.');
      }
      return consume(response, exchange.close);
    }
  }

  Future<void> _consume(
    StreamedResponse response, {
    required Uri uri,
    required Duration start,
    required int limit,
    required int? expectedLength,
    required FutureOr<void> Function(List<int> chunk) onChunk,
    required void Function() closeExchange,
  }) async {
    late int? declaredLength;
    try {
      declaredLength = _validateHeaders(response, uri, limit, expectedLength);
    } on Object catch (error, stackTrace) {
      await _discard(
        response,
        start: start,
        closeExchange: closeExchange,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
    final iterator = StreamIterator<List<int>>(response.stream);
    var received = 0;
    try {
      while (await _deadline(
        iterator.moveNext(),
        _boundedDeadline(start, policy.idleDeadline),
        'HTTP idle deadline exceeded for $uri.',
      )) {
        _checkTotal(start);
        final chunk = iterator.current;
        received += chunk.length;
        if (received > limit ||
            (declaredLength != null && received > declaredLength) ||
            (expectedLength != null && received > expectedLength)) {
          throw PrecompiledTransportException(
              'HTTP response body for $uri exceeds its allowed length.');
        }
        await onChunk(chunk);
      }
      _checkTotal(start);
      final requiredLength = expectedLength ?? declaredLength;
      if (requiredLength != null && received != requiredLength) {
        throw PrecompiledTransportException(
            'HTTP response body for $uri ended at $received bytes; expected $requiredLength.');
      }
    } finally {
      await _boundedCancellation(
        iterator.cancel(),
        start: start,
        closeExchange: closeExchange,
      );
    }
  }

  int? _validateHeaders(
    StreamedResponse response,
    Uri uri,
    int limit,
    int? expectedLength,
  ) {
    final contentLengthText = response.headers['content-length'];
    final transferEncoding = response.headers['transfer-encoding'];
    if (contentLengthText != null &&
        transferEncoding != null &&
        transferEncoding.toLowerCase().contains('chunked')) {
      throw PrecompiledTransportException(
          'HTTP response for $uri has conflicting length headers.');
    }
    final parsedHeader =
        contentLengthText == null ? null : int.tryParse(contentLengthText);
    if (contentLengthText != null && parsedHeader == null) {
      throw PrecompiledTransportException(
          'HTTP content length for $uri is invalid.');
    }
    if (parsedHeader != null &&
        response.contentLength != null &&
        parsedHeader != response.contentLength) {
      throw PrecompiledTransportException(
          'HTTP content length for $uri is inconsistent.');
    }
    final contentLength = parsedHeader ?? response.contentLength;
    if (contentLength == null) return null;
    if (contentLength < 0 ||
        contentLength > limit ||
        (expectedLength != null && contentLength != expectedLength)) {
      throw PrecompiledTransportException(
          'HTTP content length for $uri is invalid.');
    }
    return contentLength;
  }

  Future<T> _deadline<T>(
    Future<T> operation,
    Duration duration,
    String message, {
    void Function()? onTimeout,
  }) async {
    final completer = Completer<T>();
    final deadlineSleeper = _deadlineSleeper;
    Timer? timer;
    void timeout() {
      if (completer.isCompleted) return;
      onTimeout?.call();
      completer.completeError(TimeoutException(message));
    }

    if (deadlineSleeper == null) {
      timer = Timer(duration, timeout);
    } else {
      unawaited(deadlineSleeper(duration).then<void>((_) => timeout(),
          onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }));
    }
    unawaited(operation.then<void>((value) {
      if (!completer.isCompleted) completer.complete(value);
    }, onError: (Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }).whenComplete(() => timer?.cancel()));
    return completer.future;
  }

  Future<StreamedResponse> _sendHeaders(
    _PrecompiledHttpExchangeLease exchange,
    BaseRequest request,
    Duration duration,
    String message,
  ) {
    var timedOut = false;
    final operation = exchange.send(request);
    unawaited(operation.then<void>((response) async {
      if (timedOut) {
        await _discard(response, closeExchange: exchange.close);
      }
    }).catchError((Object _) {}));
    return _deadline(
      operation,
      duration,
      message,
      onTimeout: () {
        timedOut = true;
        exchange.close();
      },
    );
  }

  Future<T> _withExchange<T>(
      Future<T> Function(_PrecompiledHttpExchangeLease exchange) operation) {
    if (_closed) {
      throw StateError('Precompiled asset transport is closed.');
    }
    final exchange = _PrecompiledHttpExchangeLease(_exchangeFactory());
    _activeExchanges.add(exchange);
    return operation(exchange).whenComplete(() {
      exchange.close();
      _activeExchanges.remove(exchange);
    });
  }

  Future<void> _discard(
    StreamedResponse response, {
    Duration? start,
    void Function()? closeExchange,
  }) async {
    final subscription = response.stream.listen(null);
    await _boundedCancellation(
      subscription.cancel(),
      start: start ?? monotonicClock(),
      closeExchange: closeExchange,
    );
  }

  Future<void> _boundedCancellation(
    Future<void> cancellation, {
    required Duration start,
    void Function()? closeExchange,
  }) async {
    final remaining = policy.totalDeadline - (monotonicClock() - start);
    final duration = remaining <= Duration.zero
        ? Duration.zero
        : remaining < policy.idleDeadline
            ? remaining
            : policy.idleDeadline;
    try {
      await _deadline(
        cancellation,
        duration,
        'HTTP response cancellation deadline exceeded.',
        onTimeout: closeExchange,
      );
    } on Object {
      closeExchange?.call();
      // Cancellation is cleanup; preserve the primary transport outcome.
    }
  }

  Future<void> _sleepBeforeRetry(Duration start, Duration requested) async {
    _checkTotal(start);
    final delay =
        requested > policy.retryAfterCap ? policy.retryAfterCap : requested;
    final remaining = policy.totalDeadline - (monotonicClock() - start);
    if (delay >= remaining) {
      throw PrecompiledTransportException(
          'HTTP total deadline exceeded while waiting to retry.');
    }
    try {
      await _deadline(
        sleeper(delay),
        remaining,
        'HTTP total deadline exceeded while waiting to retry.',
      );
    } on TimeoutException catch (error) {
      throw PrecompiledTransportException(error.message ?? error.toString());
    }
    _checkTotal(start);
  }

  Duration _backoff(int attempt) {
    final multiplier = 1 << (attempt - 1);
    return policy.baseBackoff * multiplier;
  }

  Duration? _retryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds != null && seconds >= 0) return Duration(seconds: seconds);
    final date = DateTime.tryParse(value);
    if (date == null) return null;
    final delay = date.toUtc().difference(wallClock().toUtc());
    return delay.isNegative ? Duration.zero : delay;
  }

  void _checkTotal(Duration start) {
    if (monotonicClock() - start >= policy.totalDeadline) {
      throw PrecompiledTransportException('HTTP total deadline exceeded.');
    }
  }

  Duration _boundedDeadline(Duration start, Duration requested) {
    final remaining = policy.totalDeadline - (monotonicClock() - start);
    if (remaining <= Duration.zero) {
      throw PrecompiledTransportException('HTTP total deadline exceeded.');
    }
    return remaining < requested ? remaining : requested;
  }

  static void _validateHttpUri(Uri uri) {
    if ((uri.scheme != 'http' && uri.scheme != 'https') || !uri.hasAuthority) {
      throw PrecompiledTransportException(
          'Precompiled asset URL must use HTTP or HTTPS.');
    }
  }

  static void _validateBounds(int limit, int? expectedLength) {
    if (limit < 0 ||
        expectedLength != null &&
            (expectedLength < 0 || expectedLength > limit)) {
      throw ArgumentError('Invalid response size bounds.');
    }
  }

  static PrecompiledMonotonicClock _newMonotonicClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  static PrecompiledHttpExchangeFactory _newExchangeFactory({
    required PrecompiledHttpSend? send,
    required Client? client,
  }) {
    if (send != null) {
      return () => (send: send, close: () {});
    }
    if (client != null) {
      return () => (send: client.send, close: () {});
    }
    return () {
      final ownedClient = Client();
      return (send: ownedClient.send, close: ownedClient.close);
    };
  }
}

class _PrecompiledHttpExchangeLease {
  _PrecompiledHttpExchangeLease(this._exchange);

  final PrecompiledHttpExchange _exchange;
  bool _closed = false;

  Future<StreamedResponse> send(BaseRequest request) => _exchange.send(request);

  void close() {
    if (_closed) return;
    _closed = true;
    _exchange.close();
  }
}

class _RetryableTransportException implements Exception {
  _RetryableTransportException(this.message, this.retryAfter);

  final String message;
  final Duration? retryAfter;
}

const _retryStatuses = {408, 429, 500, 502, 503, 504};
const _redirectStatuses = {301, 302, 303, 307, 308};

typedef PrecompiledRename = void Function(String source, String destination);
typedef PrecompiledRenameErrorClassifier = bool Function(
    FileSystemException error);
typedef PrecompiledStagingId = String Function();
typedef PrecompiledCacheLogger = void Function(String message);

class PrecompiledAssetStorePolicy {
  const PrecompiledAssetStorePolicy({
    this.manifestLimit = 1024 * 1024,
    this.perAssetLimit = 512 * 1024 * 1024,
    this.aggregateAssetLimit = 1024 * 1024 * 1024,
    this.lockTimeout = const Duration(seconds: 30),
    this.lockPollInterval = const Duration(milliseconds: 50),
    this.renameAttempts = 3,
    this.renameRetryDelay = const Duration(milliseconds: 50),
  });

  final int manifestLimit;
  final int perAssetLimit;
  final int aggregateAssetLimit;
  final Duration lockTimeout;
  final Duration lockPollInterval;
  final int renameAttempts;
  final Duration renameRetryDelay;
}

class PrecompiledAssetSnapshot {
  PrecompiledAssetSnapshot({
    required this.directory,
    required this.requestKey,
    required Set<String> assetNames,
  }) : assetNames = Set.unmodifiable(assetNames);

  final String directory;
  final String requestKey;
  final Set<String> assetNames;

  String pathFor(String name) {
    if (!assetNames.contains(name)) {
      throw ArgumentError.value(name, 'name', 'Asset is not in this snapshot.');
    }
    return path.join(directory, name);
  }
}

class PrecompiledCacheMetrics {
  const PrecompiledCacheMetrics({
    required this.snapshotCount,
    required this.totalBytes,
    required this.oldestMtime,
  });

  final int snapshotCount;
  final int totalBytes;
  final DateTime? oldestMtime;
}

class PrecompiledAssetStore {
  PrecompiledAssetStore({
    required String cacheRoot,
    required this.uriPrefix,
    required this.publicKey,
    required this.recipe,
    required Set<String> expectedAssetNames,
    required Set<String> expectedCompositeChecksums,
    required this.transport,
    this.policy = const PrecompiledAssetStorePolicy(),
    PrecompiledSleeper? sleeper,
    PrecompiledMonotonicClock? monotonicClock,
    PrecompiledStagingId? stagingId,
    PrecompiledRename? rename,
    PrecompiledRenameErrorClassifier? transientRenameError,
    PrecompiledCacheLogger? logger,
    PrecompiledFileRecorder? fileRecorder,
  })  : cacheRoot = _canonicalizeRoot(cacheRoot),
        expectedAssetNames = Set.unmodifiable(expectedAssetNames),
        expectedCompositeChecksums =
            Set.unmodifiable(expectedCompositeChecksums),
        sleeper = sleeper ?? Future<void>.delayed,
        monotonicClock =
            monotonicClock ?? PrecompiledAssetTransport._newMonotonicClock(),
        stagingId = stagingId ?? _defaultStagingId,
        rename = rename ?? _defaultRename,
        transientRenameError =
            transientRenameError ?? _defaultTransientRenameError,
        logger = logger ?? _ignoreLog,
        fileRecorder = fileRecorder ?? _ignoreFileEvent {
    if (policy.manifestLimit < 1 ||
        policy.perAssetLimit < 1 ||
        policy.aggregateAssetLimit < 1 ||
        policy.renameAttempts < 1) {
      throw ArgumentError('Asset store limits are invalid.');
    }
  }

  final String cacheRoot;
  final Uri uriPrefix;
  final PublicKey publicKey;
  final PrecompiledBuildRecipe recipe;
  final Set<String> expectedAssetNames;
  final Set<String> expectedCompositeChecksums;
  final PrecompiledAssetTransport transport;
  final PrecompiledAssetStorePolicy policy;
  final PrecompiledSleeper sleeper;
  final PrecompiledMonotonicClock monotonicClock;
  final PrecompiledStagingId stagingId;
  final PrecompiledRename rename;
  final PrecompiledRenameErrorClassifier transientRenameError;
  final PrecompiledCacheLogger logger;
  final PrecompiledFileRecorder fileRecorder;

  static String requestKey(Iterable<String> expandedAssetNames) {
    final names = expandedAssetNames.toSet().toList()..sort();
    return sha256.convert(utf8.encode(jsonEncode(names))).toString();
  }

  Future<PrecompiledAssetSnapshot?> snapshot({
    required String generationHash,
    required Set<String> requestedAssetNames,
  }) async {
    if (!_sha256Hex.hasMatch(generationHash)) {
      throw PrecompiledGenerationException('Malformed generation hash.');
    }
    if (requestedAssetNames.isEmpty) {
      throw ArgumentError.value(
          requestedAssetNames, 'requestedAssetNames', 'Must not be empty.');
    }
    final remote = await _fetchManifest(generationHash);
    if (remote == null) return null;

    final generationDirectory = path.join(cacheRoot, 'v2', generationHash);
    _ensureManagedDirectory(path.join(cacheRoot, 'v2'));
    _ensureManagedDirectory(generationDirectory);
    final locksDirectory = path.join(generationDirectory, 'locks');
    _ensureManagedDirectory(locksDirectory);

    await _withLock(
      path.join(locksDirectory, 'generation.lock'),
      () => _establishAnchor(generationDirectory, remote),
    );

    final expanded = _expandedAssets(remote.manifest, requestedAssetNames);
    final key = requestKey(expanded);
    final snapshotsDirectory = path.join(generationDirectory, 'snapshots');
    _ensureManagedDirectory(snapshotsDirectory);
    final result = await _withLock(
      path.join(locksDirectory, 'request-$key.lock'),
      () async {
        await _validateAnchor(generationDirectory, remote);
        return _establishSnapshot(
          generationDirectory: generationDirectory,
          snapshotsDirectory: snapshotsDirectory,
          remote: remote,
          expanded: expanded,
          key: key,
        );
      },
    );
    metrics(generationHash: generationHash, requestKey: key);
    return result;
  }

  bool hasAnyState(String generationHash) {
    final v2Root = path.join(cacheRoot, 'v2');
    final v2Type = FileSystemEntity.typeSync(v2Root, followLinks: false);
    if (v2Type != FileSystemEntityType.notFound &&
        v2Type != FileSystemEntityType.directory) {
      return true;
    }
    final v2Generation = path.join(cacheRoot, 'v2', generationHash);
    if (FileSystemEntity.typeSync(v2Generation, followLinks: false) !=
        FileSystemEntityType.notFound) {
      return true;
    }
    for (final entity in Directory(cacheRoot).listSync(followLinks: false)) {
      final name = path.basename(entity.path);
      if (name == generationHash ||
          name.startsWith('$generationHash.staging-') ||
          name.startsWith('$generationHash.previous-')) {
        return true;
      }
    }
    return false;
  }

  PrecompiledCacheMetrics metrics({
    required String generationHash,
    required String requestKey,
  }) {
    final generationDirectory = path.join(cacheRoot, 'v2', generationHash);
    final snapshotsDirectory = path.join(generationDirectory, 'snapshots');
    var snapshotCount = 0;
    var totalBytes = 0;
    DateTime? oldest;
    final roots = <Directory>[
      Directory(path.join(generationDirectory, 'anchor')),
    ];
    if (Directory(snapshotsDirectory).existsSync()) {
      for (final entity
          in Directory(snapshotsDirectory).listSync(followLinks: false)) {
        final name = path.basename(entity.path);
        if (_sha256Hex.hasMatch(name) &&
            FileSystemEntity.typeSync(entity.path, followLinks: false) ==
                FileSystemEntityType.directory) {
          snapshotCount++;
          roots.add(Directory(entity.path));
        }
      }
    }
    for (final root in roots) {
      if (!root.existsSync()) continue;
      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (FileSystemEntity.typeSync(entity.path, followLinks: false) !=
            FileSystemEntityType.file) {
          continue;
        }
        final stat = entity.statSync();
        totalBytes += stat.size;
        if (oldest == null || stat.modified.isBefore(oldest)) {
          oldest = stat.modified;
        }
      }
    }
    final result = PrecompiledCacheMetrics(
      snapshotCount: snapshotCount,
      totalBytes: totalBytes,
      oldestMtime: oldest,
    );
    logger(
      'precompiled-cache generation=$generationHash request=$requestKey '
      'snapshots=$snapshotCount bytes=$totalBytes '
      'oldest_mtime=${oldest?.toUtc().toIso8601String() ?? 'none'}',
    );
    return result;
  }

  Future<_RemoteManifest?> _fetchManifest(String generationHash) async {
    final generationBase = _generationBase(generationHash);
    final manifestUri =
        generationBase.resolve(precompiledGenerationManifestFileName);
    final manifestBytes = await transport.getBytes(
      manifestUri,
      limit: policy.manifestLimit,
      allowNotFound: true,
    );
    if (manifestBytes == null) return null;
    final signatureBytes = await transport.getBytes(
      generationBase.resolve(precompiledGenerationManifestSignatureFileName),
      limit: 64,
      expectedLength: 64,
    );
    final manifest = PrecompiledGenerationManifest.parse(manifestBytes);
    manifest.verifySignature(publicKey, signatureBytes!);
    manifest.validateFor(
      generationHash: generationHash,
      recipe: recipe,
      expectedAssetNames: expectedAssetNames,
    );
    final actualComposites = manifest.compositeChecksums
        .map((binding) => '${binding.archive}\u0000${binding.checksum}')
        .toSet();
    if (!_sameSet(actualComposites, expectedCompositeChecksums)) {
      throw PrecompiledGenerationException(
          'Manifest composite checksum relationships do not match configuration.');
    }
    return _RemoteManifest(manifest, manifestBytes, signatureBytes);
  }

  Future<void> _establishAnchor(
      String generationDirectory, _RemoteManifest remote) async {
    final anchor = path.join(generationDirectory, 'anchor');
    final type = FileSystemEntity.typeSync(anchor, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await _validateAnchor(generationDirectory, remote);
      return;
    }
    if (type != FileSystemEntityType.notFound) {
      throw PrecompiledGenerationException(
          'Manifest anchor has an unsafe type.');
    }
    String? staging;
    var ownsStaging = false;
    try {
      staging = Directory(generationDirectory)
          .createTempSync('anchor.staging-${stagingId()}-')
          .path;
      ownsStaging = true;
      await _writeExclusiveFlushed(
        path.join(staging, precompiledGenerationManifestFileName),
        remote.bytes,
      );
      await _writeExclusiveFlushed(
        path.join(staging, precompiledGenerationManifestSignatureFileName),
        remote.signature,
      );
      await _publishDirectory(staging, anchor);
      ownsStaging = false;
    } finally {
      if (ownsStaging && staging != null && Directory(staging).existsSync()) {
        Directory(staging).deleteSync(recursive: true);
      }
    }
  }

  Future<void> _validateAnchor(
      String generationDirectory, _RemoteManifest remote) async {
    final anchor = path.join(generationDirectory, 'anchor');
    _requireDirectory(anchor, 'Manifest anchor');
    final expectedFiles = {
      precompiledGenerationManifestFileName,
      precompiledGenerationManifestSignatureFileName,
    };
    final entries = Directory(anchor).listSync(followLinks: false);
    if (entries.length != expectedFiles.length ||
        entries.any((entry) =>
            !expectedFiles.contains(path.basename(entry.path)) ||
            FileSystemEntity.typeSync(entry.path, followLinks: false) !=
                FileSystemEntityType.file)) {
      throw PrecompiledGenerationException(
          'Manifest anchor inventory is incomplete or unexpected.');
    }
    final bytes = await _readRegularBounded(
      path.join(anchor, precompiledGenerationManifestFileName),
      policy.manifestLimit,
      'Manifest anchor',
    );
    final signature = await _readRegularBounded(
      path.join(anchor, precompiledGenerationManifestSignatureFileName),
      64,
      'Manifest anchor signature',
      exactLength: 64,
    );
    if (!_sameBytes(bytes, remote.bytes) ||
        !_sameBytes(signature, remote.signature)) {
      throw PrecompiledGenerationException(
          'Manifest anchor differs from the signed remote generation.');
    }
    final anchored = PrecompiledGenerationManifest.parse(bytes);
    anchored.verifySignature(publicKey, signature);
    anchored.validateFor(
      generationHash: remote.manifest.generationHash,
      recipe: recipe,
      expectedAssetNames: expectedAssetNames,
    );
  }

  Set<String> _expandedAssets(
    PrecompiledGenerationManifest manifest,
    Set<String> requested,
  ) {
    final expanded = <String>{};
    for (final name in requested) {
      if (manifest.asset(name) == null) {
        throw PrecompiledGenerationException(
            'Requested asset "$name" is absent from the manifest.');
      }
      expanded.add(name);
    }
    for (final binding in manifest.compositeChecksums) {
      if (expanded.contains(binding.archive) ||
          expanded.contains(binding.checksum)) {
        expanded
          ..add(binding.archive)
          ..add(binding.checksum);
      }
    }
    return expanded;
  }

  Future<PrecompiledAssetSnapshot> _establishSnapshot({
    required String generationDirectory,
    required String snapshotsDirectory,
    required _RemoteManifest remote,
    required Set<String> expanded,
    required String key,
  }) async {
    final destination = path.join(snapshotsDirectory, key);
    final type = FileSystemEntity.typeSync(destination, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await _validateSnapshot(destination, remote.manifest, expanded);
      return PrecompiledAssetSnapshot(
        directory: destination,
        requestKey: key,
        assetNames: expanded,
      );
    }
    if (type != FileSystemEntityType.notFound) {
      throw PrecompiledGenerationException('Snapshot has an unsafe type.');
    }
    var aggregate = 0;
    for (final name in expanded) {
      final asset = remote.manifest.asset(name)!;
      if (asset.length > policy.perAssetLimit) {
        throw PrecompiledGenerationException(
            'Asset "$name" exceeds the per-asset limit.');
      }
      aggregate += asset.length;
      if (aggregate > policy.aggregateAssetLimit) {
        throw PrecompiledGenerationException(
            'Requested assets exceed the aggregate limit.');
      }
    }
    String? staging;
    var ownsStaging = false;
    try {
      staging = Directory(snapshotsDirectory)
          .createTempSync('$key.staging-${stagingId()}-')
          .path;
      ownsStaging = true;
      final names = expanded.toList()..sort();
      final generationBase = _generationBase(remote.manifest.generationHash);
      for (final name in names) {
        final asset = remote.manifest.asset(name)!;
        final signature = await transport.getBytes(
          generationBase.resolve('$name.sig'),
          limit: 64,
          expectedLength: 64,
        );
        remote.manifest.verifyAssetMetadataSignature(
          name: name,
          signature: signature!,
          publicKey: publicKey,
        );
        final assetPath = path.join(staging, name);
        _ensureAssetParent(staging, assetPath);
        await transport.downloadToFile(
          generationBase.resolve(name),
          File(assetPath),
          limit: policy.perAssetLimit,
          expectedLength: asset.length,
          expectedSha256: asset.sha256,
          deleteOnFailure: true,
        );
        await _writeExclusiveFlushed('$assetPath.sig', signature);
      }
      _validateCompositeContents(staging, remote.manifest, expanded);
      await _publishDirectory(staging, destination);
      ownsStaging = false;
    } finally {
      if (ownsStaging && staging != null && Directory(staging).existsSync()) {
        Directory(staging).deleteSync(recursive: true);
      }
    }
    await _validateSnapshot(destination, remote.manifest, expanded);
    return PrecompiledAssetSnapshot(
      directory: destination,
      requestKey: key,
      assetNames: expanded,
    );
  }

  Future<void> _validateSnapshot(
    String directory,
    PrecompiledGenerationManifest manifest,
    Set<String> expanded,
  ) async {
    _requireDirectory(directory, 'Snapshot');
    final expectedFiles = <String>{
      for (final name in expanded) ...{name, '$name.sig'},
    };
    final expectedDirectories = <String>{};
    for (final file in expectedFiles) {
      var parent = path.posix.dirname(file);
      while (parent != '.') {
        expectedDirectories.add(parent);
        parent = path.posix.dirname(parent);
      }
    }
    final actualFiles = <String>{};
    final actualDirectories = <String>{};
    for (final entity
        in Directory(directory).listSync(recursive: true, followLinks: false)) {
      final relative = path.relative(entity.path, from: directory);
      final normalized = path.posix.joinAll(path.split(relative));
      final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
      if (type == FileSystemEntityType.file) {
        actualFiles.add(normalized);
      } else if (type == FileSystemEntityType.directory) {
        actualDirectories.add(normalized);
      } else {
        throw PrecompiledGenerationException(
            'Snapshot contains a link or unsafe filesystem entry.');
      }
    }
    if (!_sameSet(actualFiles, expectedFiles) ||
        !_sameSet(actualDirectories, expectedDirectories)) {
      throw PrecompiledGenerationException(
          'Snapshot inventory is incomplete or unexpected.');
    }
    for (final name in expanded) {
      final asset = manifest.asset(name)!;
      final signature = await _readRegularBounded(
        path.join(directory, '$name.sig'),
        64,
        'Asset signature',
        exactLength: 64,
      );
      manifest.verifyAssetMetadataSignature(
        name: name,
        signature: signature,
        publicKey: publicKey,
      );
      final file = path.join(directory, name);
      final digest = await _digestRegularFile(
        file,
        expectedLength: asset.length,
        limit: policy.perAssetLimit,
      );
      if (digest != asset.sha256) {
        throw PrecompiledGenerationException(
            'Cached asset "$name" has been modified.');
      }
    }
    _validateCompositeContents(directory, manifest, expanded);
  }

  void _validateCompositeContents(
    String directory,
    PrecompiledGenerationManifest manifest,
    Set<String> expanded,
  ) {
    for (final binding in manifest.compositeChecksums) {
      if (!expanded.contains(binding.archive)) continue;
      final archive = manifest.asset(binding.archive)!;
      final expected = ascii.encode('${archive.sha256}\n');
      final actual =
          File(path.join(directory, binding.checksum)).readAsBytesSync();
      if (!_sameBytes(actual, expected)) {
        throw PrecompiledGenerationException(
            'Composite checksum contents do not match signed metadata.');
      }
    }
  }

  Future<T> _withLock<T>(String lockPath, Future<T> Function() action) async {
    final start = monotonicClock();
    final inProcess = _InProcessLockRequest.acquire(lockPath);
    var inProcessAcquired = false;
    try {
      while (!inProcess.isAcquired) {
        final elapsed = monotonicClock() - start;
        if (elapsed >= policy.lockTimeout) {
          throw PrecompiledGenerationException(
              'Timed out waiting for immutable cache lock.');
        }
        final remaining = policy.lockTimeout - elapsed;
        final delay = policy.lockPollInterval < remaining
            ? policy.lockPollInterval
            : remaining;
        await Future.any<void>([inProcess.acquired, sleeper(delay)]);
      }
      inProcessAcquired = true;
      if (monotonicClock() - start >= policy.lockTimeout) {
        throw PrecompiledGenerationException(
            'Timed out waiting for immutable cache lock.');
      }
      return await _withOsLock(lockPath, start, action);
    } finally {
      if (inProcessAcquired) {
        inProcess.release();
      } else {
        inProcess.cancel();
      }
    }
  }

  Future<T> _withOsLock<T>(
    String lockPath,
    Duration start,
    Future<T> Function() action,
  ) async {
    final type = FileSystemEntity.typeSync(lockPath, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      try {
        File(lockPath).createSync(exclusive: true);
      } on FileSystemException {
        if (FileSystemEntity.typeSync(lockPath, followLinks: false) !=
            FileSystemEntityType.file) {
          throw PrecompiledGenerationException(
              'Cache lock has an unsafe type.');
        }
      }
    } else if (type != FileSystemEntityType.file) {
      throw PrecompiledGenerationException('Cache lock has an unsafe type.');
    }
    if (FileSystemEntity.typeSync(lockPath, followLinks: false) !=
        FileSystemEntityType.file) {
      throw PrecompiledGenerationException('Cache lock has an unsafe type.');
    }
    final lock = File(lockPath).openSync(mode: FileMode.append);
    var acquired = false;
    try {
      while (!acquired) {
        try {
          lock.lockSync(FileLock.exclusive);
          acquired = true;
        } on FileSystemException catch (error) {
          if (!_isLockContention(error)) {
            throw PrecompiledGenerationException(
                'Failed to acquire immutable cache lock: ${error.message}');
          }
          if (monotonicClock() - start >= policy.lockTimeout) {
            throw PrecompiledGenerationException(
                'Timed out waiting for immutable cache lock.');
          }
          await sleeper(policy.lockPollInterval);
        }
      }
      return await action();
    } finally {
      if (acquired) lock.unlockSync();
      lock.closeSync();
    }
  }

  Future<void> _publishDirectory(String source, String destination) async {
    if (path.dirname(source) != path.dirname(destination)) {
      throw PrecompiledGenerationException(
          'Immutable cache publication must use the same parent directory.');
    }
    for (var attempt = 1; attempt <= policy.renameAttempts; attempt++) {
      if (FileSystemEntity.typeSync(destination, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw PrecompiledGenerationException(
            'Immutable cache destination already exists.');
      }
      try {
        rename(source, destination);
        return;
      } on FileSystemException catch (error) {
        if (attempt == policy.renameAttempts || !transientRenameError(error)) {
          throw PrecompiledGenerationException(
              'Failed to publish immutable cache directory: ${error.message}');
        }
        await sleeper(policy.renameRetryDelay);
      }
    }
  }

  Future<void> _writeExclusiveFlushed(String filePath, List<int> bytes) async {
    final file = File(filePath);
    await file.create(exclusive: true);
    final output = await file.open(mode: FileMode.writeOnly);
    fileRecorder('open', filePath);
    try {
      await output.writeFrom(bytes);
      await output.flush();
      fileRecorder('flush', filePath);
    } finally {
      await output.close();
      fileRecorder('close', filePath);
    }
  }

  static Future<Uint8List> _readRegularBounded(
    String filePath,
    int limit,
    String description, {
    int? exactLength,
  }) async {
    if (FileSystemEntity.typeSync(filePath, followLinks: false) !=
        FileSystemEntityType.file) {
      throw PrecompiledGenerationException(
          '$description is not a regular file.');
    }
    final stat = File(filePath).statSync();
    if (stat.size > limit || exactLength != null && stat.size != exactLength) {
      throw PrecompiledGenerationException(
          '$description has an invalid length.');
    }
    final bytes = await File(filePath).readAsBytes();
    if (bytes.length > limit ||
        exactLength != null && bytes.length != exactLength) {
      throw PrecompiledGenerationException(
          '$description has an invalid length.');
    }
    return bytes;
  }

  static Future<String> _digestRegularFile(
    String filePath, {
    required int expectedLength,
    required int limit,
  }) async {
    if (FileSystemEntity.typeSync(filePath, followLinks: false) !=
        FileSystemEntityType.file) {
      throw PrecompiledGenerationException(
          'Cached asset is not a regular file.');
    }
    final stat = File(filePath).statSync();
    if (stat.size != expectedLength || stat.size > limit) {
      throw PrecompiledGenerationException(
          'Cached asset has an invalid length.');
    }
    final output = AccumulatorSink<Digest>();
    final input = sha256.startChunkedConversion(output);
    var length = 0;
    await for (final chunk in File(filePath).openRead()) {
      length += chunk.length;
      if (length > expectedLength || length > limit) {
        throw PrecompiledGenerationException('Cached asset exceeds its limit.');
      }
      input.add(chunk);
    }
    input.close();
    if (length != expectedLength) {
      throw PrecompiledGenerationException('Cached asset ended unexpectedly.');
    }
    return output.events.single.toString();
  }

  static void _ensureManagedDirectory(String directoryPath) {
    final type = FileSystemEntity.typeSync(directoryPath, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      try {
        Directory(directoryPath).createSync();
      } on FileSystemException {
        if (FileSystemEntity.typeSync(directoryPath, followLinks: false) !=
            FileSystemEntityType.directory) {
          throw PrecompiledGenerationException(
              'Managed cache path has an unsafe type: $directoryPath');
        }
      }
    } else if (type != FileSystemEntityType.directory) {
      throw PrecompiledGenerationException(
          'Managed cache path has an unsafe type: $directoryPath');
    }
  }

  static void _requireDirectory(String directoryPath, String description) {
    if (FileSystemEntity.typeSync(directoryPath, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw PrecompiledGenerationException('$description is not a directory.');
    }
  }

  static void _ensureAssetParent(String staging, String filePath) {
    final parent = path.dirname(filePath);
    if (!path.isWithin(staging, filePath)) {
      throw PrecompiledGenerationException('Asset path escapes staging.');
    }
    if (parent != staging) {
      var current = staging;
      for (final component
          in path.relative(parent, from: staging).split(path.separator)) {
        current = path.join(current, component);
        _ensureManagedDirectory(current);
      }
    }
  }

  static String _canonicalizeRoot(String root) {
    final directory = Directory(root);
    directory.createSync(recursive: true);
    return directory.resolveSymbolicLinksSync();
  }

  Uri _generationBase(String generationHash) =>
      Uri.parse('${uriPrefix.toString()}$generationHash/');

  static String _defaultStagingId() =>
      '$pid-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

  static void _defaultRename(String source, String destination) =>
      Directory(source).renameSync(destination);

  static bool _defaultTransientRenameError(FileSystemException error) {
    if (!Platform.isWindows) return false;
    return const {32, 33}.contains(error.osError?.errorCode);
  }

  static bool _isLockContention(FileSystemException error) {
    final code = error.osError?.errorCode;
    if (Platform.isWindows) return const {32, 33}.contains(code);
    return const {11, 13, 35}.contains(code);
  }

  static void _ignoreLog(String _) {}
}

void _ignoreFileEvent(String _, String __) {}

class _RemoteManifest {
  const _RemoteManifest(this.manifest, this.bytes, this.signature);

  final PrecompiledGenerationManifest manifest;
  final Uint8List bytes;
  final Uint8List signature;
}

bool _sameSet<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

// Build-tool stores in one Dart isolate share this registry. Dart isolates do
// not share memory; cross-process and cross-isolate exclusion remains the OS lock.
final _inProcessLocks = <String, _InProcessLock>{};

class _InProcessLock {
  _InProcessLock(this.key);

  final String key;
  final List<_InProcessLockRequest> waiters = [];
  var held = false;
  var references = 0;

  _InProcessLockRequest request() {
    references++;
    final request = _InProcessLockRequest._(this);
    if (held) {
      waiters.add(request);
    } else {
      held = true;
      request._grant();
    }
    return request;
  }

  void cancel(_InProcessLockRequest request) {
    if (request.isAcquired || request.isFinished) return;
    if (waiters.remove(request)) {
      request._finish();
      references--;
      _removeIfUnused();
    }
  }

  void release(_InProcessLockRequest request) {
    if (!request.isAcquired || request.isFinished) return;
    request._finish();
    references--;
    if (waiters.isEmpty) {
      held = false;
      _removeIfUnused();
    } else {
      waiters.removeAt(0)._grant();
    }
  }

  void _removeIfUnused() {
    if (references == 0 && identical(_inProcessLocks[key], this)) {
      _inProcessLocks.remove(key);
    }
  }
}

class _InProcessLockRequest {
  _InProcessLockRequest._(this._lock);

  final _InProcessLock _lock;
  final Completer<void> _acquired = Completer<void>();
  var isAcquired = false;
  var isFinished = false;

  static _InProcessLockRequest acquire(String key) =>
      _inProcessLocks.putIfAbsent(key, () => _InProcessLock(key)).request();

  Future<void> get acquired => _acquired.future;

  void _grant() {
    isAcquired = true;
    _acquired.complete();
  }

  void _finish() => isFinished = true;

  void cancel() => _lock.cancel(this);

  void release() => _lock.release(this);
}

final _sha256Hex = RegExp(r'^[0-9a-f]{64}$');
