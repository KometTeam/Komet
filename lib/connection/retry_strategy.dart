import 'dart:math';

enum ErrorType { network, server, authentication, protocol, unknown }

class ErrorInfo {
  final ErrorType type;
  final String message;
  final int? httpStatusCode;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ErrorInfo({
    required this.type,
    required this.message,
    this.httpStatusCode,
    required this.timestamp,
    this.metadata,
  });

  static ErrorType getErrorTypeFromHttpStatus(int statusCode) {
    if (statusCode >= 500) return ErrorType.server;
    if (statusCode == 401 || statusCode == 403) return ErrorType.authentication;
    if (statusCode >= 400) return ErrorType.protocol;
    return ErrorType.network;
  }

  static ErrorType getErrorTypeFromMessage(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('timeout') ||
        lowerMessage.contains('connection') ||
        lowerMessage.contains('network')) {
      return ErrorType.network;
    }

    if (lowerMessage.contains('unauthorized') ||
        lowerMessage.contains('forbidden') ||
        lowerMessage.contains('token')) {
      return ErrorType.authentication;
    }

    if (lowerMessage.contains('server') || lowerMessage.contains('internal')) {
      return ErrorType.server;
    }

    return ErrorType.unknown;
  }
}

class RetryStrategy {
  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final double jitterFactor;
  final Map<ErrorType, RetryConfig> errorConfigs;

  RetryStrategy({
    this.maxAttempts = 10,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
    this.jitterFactor = 0.1,
    Map<ErrorType, RetryConfig>? errorConfigs,
  }) : errorConfigs = errorConfigs ?? _defaultErrorConfigs;

  static final Map<ErrorType, RetryConfig> _defaultErrorConfigs = {
    ErrorType.network: RetryConfig(
      maxAttempts: 15,
      baseDelay: Duration(seconds: 2),
      maxDelay: Duration(minutes: 10),
      backoffMultiplier: 1.5,
    ),
    ErrorType.server: RetryConfig(
      maxAttempts: 8,
      baseDelay: Duration(seconds: 5),
      maxDelay: Duration(minutes: 3),
      backoffMultiplier: 2.0,
    ),
    ErrorType.authentication: RetryConfig(
      maxAttempts: 3,
      baseDelay: Duration(seconds: 1),
      maxDelay: Duration(seconds: 10),
      backoffMultiplier: 1.0,
    ),
    ErrorType.protocol: RetryConfig(
      maxAttempts: 5,
      baseDelay: Duration(seconds: 2),
      maxDelay: Duration(minutes: 2),
      backoffMultiplier: 1.5,
    ),
    ErrorType.unknown: RetryConfig(
      maxAttempts: 5,
      baseDelay: Duration(seconds: 3),
      maxDelay: Duration(minutes: 5),
      backoffMultiplier: 2.0,
    ),
  };

  Duration calculateDelay(int attempt, ErrorType errorType) {
    final config = errorConfigs[errorType] ?? errorConfigs[ErrorType.unknown]!;

    final exponentialDelay =
        config.baseDelay * pow(config.backoffMultiplier, attempt - 1);
    final cappedDelay = exponentialDelay > config.maxDelay
        ? config.maxDelay
        : exponentialDelay;

    final jitter =
        cappedDelay.inMilliseconds *
        jitterFactor *
        (Random().nextDouble() * 2 - 1);
    final finalDelay = Duration(
      milliseconds: (cappedDelay.inMilliseconds + jitter).round(),
    );

    return finalDelay;
  }

  bool shouldRetry(int attempt, ErrorType errorType) {
    final config = errorConfigs[errorType] ?? errorConfigs[ErrorType.unknown]!;
    return attempt <= config.maxAttempts;
  }

  RetryConfig getConfigForError(ErrorType errorType) {
    return errorConfigs[errorType] ?? errorConfigs[ErrorType.unknown]!;
  }
}

class RetryConfig {
  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final double backoffMultiplier;

  RetryConfig({
    required this.maxAttempts,
    required this.baseDelay,
    required this.maxDelay,
    required this.backoffMultiplier,
  });
}

class RetryManager {
  final RetryStrategy _strategy;
  final Map<String, RetrySession> _sessions = {};

  RetryManager({RetryStrategy? strategy})
    : _strategy = strategy ?? RetryStrategy();

  RetrySession startSession(String sessionId, ErrorType initialErrorType) {
    final session = RetrySession(
      id: sessionId,
      strategy: _strategy,
      initialErrorType: initialErrorType,
    );
    _sessions[sessionId] = session;
    return session;
  }

  RetrySession? getSession(String sessionId) {
    return _sessions[sessionId];
  }

  void endSession(String sessionId) {
    _sessions.remove(sessionId);
  }

  void clearSessions() {
    _sessions.clear();
  }

  Map<String, dynamic> getStatistics() {
    final totalSessions = _sessions.length;
    final activeSessions = _sessions.values.where((s) => s.isActive).length;
    final successfulSessions = _sessions.values
        .where((s) => s.isSuccessful)
        .length;
    final failedSessions = _sessions.values.where((s) => s.isFailed).length;

    return {
      'total_sessions': totalSessions,
      'active_sessions': activeSessions,
      'successful_sessions': successfulSessions,
      'failed_sessions': failedSessions,
      'success_rate': totalSessions > 0
          ? successfulSessions / totalSessions
          : 0.0,
    };
  }
}

class RetrySession {
  final String id;
  final RetryStrategy strategy;
  final ErrorType initialErrorType;
  final DateTime startTime;
  final List<RetryAttempt> attempts = [];

  RetrySession({
    required this.id,
    required this.strategy,
    required this.initialErrorType,
  }) : startTime = DateTime.now();

  void addAttempt(
    ErrorType errorType, {
    String? message,
    Map<String, dynamic>? metadata,
  }) {
    final attempt = RetryAttempt(
      number: attempts.length + 1,
      errorType: errorType,
      timestamp: DateTime.now(),
      message: message,
      metadata: metadata,
    );
    attempts.add(attempt);
  }

  Duration getNextDelay() {
    return strategy.calculateDelay(attempts.length + 1, currentErrorType);
  }

  bool canRetry() {
    return strategy.shouldRetry(attempts.length + 1, currentErrorType);
  }

  ErrorType get currentErrorType {
    if (attempts.isEmpty) return initialErrorType;
    return attempts.last.errorType;
  }

  int get attemptCount => attempts.length;

  bool get isActive => !isSuccessful && !isFailed && canRetry();

  bool get isSuccessful => attempts.isNotEmpty && attempts.last.isSuccessful;

  bool get isFailed => !canRetry() && !isSuccessful;

  Duration get duration => DateTime.now().difference(startTime);

  RetryAttempt? get lastAttempt => attempts.isNotEmpty ? attempts.last : null;

  Map<String, dynamic> getStatistics() {
    final errorTypes = attempts.map((a) => a.errorType.name).toList();
    final errorTypeCounts = <String, int>{};
    for (final type in errorTypes) {
      errorTypeCounts[type] = (errorTypeCounts[type] ?? 0) + 1;
    }

    return {
      'session_id': id,
      'start_time': startTime.toIso8601String(),
      'duration_seconds': duration.inSeconds,
      'attempt_count': attemptCount,
      'is_active': isActive,
      'is_successful': isSuccessful,
      'is_failed': isFailed,
      'error_types': errorTypeCounts,
      'last_attempt': lastAttempt?.toJson(),
    };
  }
}

class RetryAttempt {
  final int number;
  final ErrorType errorType;
  final DateTime timestamp;
  final String? message;
  final Map<String, dynamic>? metadata;
  final bool isSuccessful;

  RetryAttempt({
    required this.number,
    required this.errorType,
    required this.timestamp,
    this.message,
    this.metadata,
    this.isSuccessful = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'error_type': errorType.name,
      'timestamp': timestamp.toIso8601String(),
      'message': message,
      'metadata': metadata,
      'is_successful': isSuccessful,
    };
  }
}
