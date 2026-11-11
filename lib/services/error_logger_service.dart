import 'dart:async';

import 'package:livecoding/services/app_crash_monitor.dart';

class ErrorLogEntry {
  const ErrorLogEntry({
    required this.error,
    required this.stackTrace,
    required this.timestamp,
    this.reason,
    this.context = const {},
    this.fatal = false,
  });

  final Object error;
  final StackTrace stackTrace;
  final DateTime timestamp;
  final String? reason;
  final Map<String, Object?> context;
  final bool fatal;
}

abstract interface class ErrorLoggerService {
  void logError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    Map<String, Object?> context = const {},
    bool fatal = false,
  });

  void logBreadcrumb(
    String message, {
    Map<String, Object?> data = const {},
  });

  void setCustomKey(String key, Object value);

  void setUserIdentifier(String userId);

  void testCrash();
}

/// Error logger that stores entries in memory, prints diagnostics to an
/// optional sink, and optionally forwards all telemetry to [AppCrashMonitor].
class AppErrorLoggerService implements ErrorLoggerService {
  AppErrorLoggerService({
    void Function(String line)? onLog,
    DateTime Function()? clock,
    AppCrashMonitor? crashMonitor,
  })  : _onLog = onLog,
        _clock = clock ?? DateTime.now,
        _crashMonitor = crashMonitor;

  final void Function(String line)? _onLog;
  final DateTime Function() _clock;
  final AppCrashMonitor? _crashMonitor;
  final List<ErrorLogEntry> _entries = [];
  final List<String> _breadcrumbs = [];
  final Map<String, Object> _customKeys = {};
  String? _userId;

  List<ErrorLogEntry> get entries => List.unmodifiable(_entries);

  List<String> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  Map<String, Object> get customKeys => Map.unmodifiable(_customKeys);

  String? get userId => _userId;

  bool get hasCrashMonitor => _crashMonitor != null;

  @override
  void logError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    Map<String, Object?> context = const {},
    bool fatal = false,
  }) {
    final entry = ErrorLogEntry(
      error: error,
      stackTrace: stackTrace,
      timestamp: _clock(),
      reason: reason,
      context: Map.unmodifiable(context),
      fatal: fatal,
    );
    _entries.add(entry);
    final severity = fatal ? 'FATAL' : 'NON-FATAL';
    final reasonPart = reason == null ? '' : ' [$reason]';
    final ctxPart = context.isEmpty ? '' : ' context=$context';
    _onLog?.call('[$severity]$reasonPart $error$ctxPart');

    final crashReason = context.isEmpty
        ? reason
        : '${reason ?? 'Error'} | context=$context';
    if (_crashMonitor != null) {
      unawaited(
        _crashMonitor.recordError(
          error,
          stackTrace,
          reason: crashReason,
          fatal: fatal,
        ),
      );
    }
  }

  @override
  void logBreadcrumb(
    String message, {
    Map<String, Object?> data = const {},
  }) {
    final suffix = data.isEmpty ? '' : ' $data';
    final line = '$message$suffix';
    _breadcrumbs.add(line);
    _onLog?.call('[BREADCRUMB] $line');
    _crashMonitor?.log(line);
  }

  @override
  void setCustomKey(String key, Object value) {
    _customKeys[key] = value;
    _onLog?.call('[KEY] $key=$value');
    if (_crashMonitor != null) {
      unawaited(_crashMonitor.setCustomKey(key, value));
    }
  }

  @override
  void setUserIdentifier(String userId) {
    _userId = userId;
    _onLog?.call('[USER] $userId');
    if (_crashMonitor != null) {
      unawaited(_crashMonitor.setUserIdentifier(userId));
    }
  }

  @override
  void testCrash() {
    _crashMonitor?.testCrash();
  }

  void clear() {
    _entries.clear();
    _breadcrumbs.clear();
    _customKeys.clear();
    _userId = null;
  }
}
