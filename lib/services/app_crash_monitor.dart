import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AppCrashMonitor {
  AppCrashMonitor._internal();
  static final AppCrashMonitor instance = AppCrashMonitor._internal();

  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Logs custom events to build a chronological timeline (breadcrumbs) before a crash.
  void log(String message) {
    if (kDebugMode) {
      print('📝 [Crashlytics Log]: $message');
    }
    _crashlytics.log(message);
  }

  /// Sets a user identifier to help track crashes to specific users.
  Future<void> setUserIdentifier(String userId) async {
    await _crashlytics.setUserIdentifier(userId);
  }

  /// Sets custom key-value pairs to record the application state (e.g., role, current_screen).
  Future<void> setCustomKey(String key, Object value) async {
    await _crashlytics.setCustomKey(key, value);
  }

  /// Records handled exceptions in try-catch blocks without crashing the application.
  Future<void> recordError(
    dynamic error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    if (reason != null) {
      _crashlytics.log('Error reason: $reason');
    }
    await _crashlytics.recordError(error, stackTrace, reason: reason, fatal: fatal);
  }

  /// Triggers a fatal crash for testing Crashlytics integration.
  void testCrash() {
    log('Manual test crash triggered');
    _crashlytics.crash();
  }
}