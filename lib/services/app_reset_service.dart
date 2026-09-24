import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'app_mode_service.dart';
import 'database_service.dart';
import 'receipt_settings_service.dart';

typedef AppPreferencesSnapshot = Map<String, Object>;
typedef LoadAppPreferences = Future<Map<String, Object?>> Function();
typedef ClearAppPreferences = Future<bool> Function();
typedef RestoreAppPreferences =
    Future<bool> Function(AppPreferencesSnapshot snapshot);
typedef ResetDatabase = Future<void> Function();
typedef SuspendAnalyticsForReset = Future<void> Function();
typedef ResumeAnalyticsAfterReset = Future<void> Function();

/// Coordinates the app-owned reset contract without touching OS or external data.
class AppResetService {
  static final AppResetService _instance = AppResetService._();
  factory AppResetService() => _instance;

  AppResetService._({
    ResetDatabase? resetDatabase,
    LoadAppPreferences? loadPreferences,
    ClearAppPreferences? clearPreferences,
    RestoreAppPreferences? restorePreferences,
    AppModeService? modeService,
    ReceiptSettingsService? receiptSettingsService,
    AnalyticsService? analyticsService,
  }) : _resetDatabase =
           resetDatabase ?? (() => DatabaseService().resetAllData()),
       _loadPreferences = loadPreferences ?? _snapshotPreferences,
       _clearPreferences =
           clearPreferences ??
           (() async => (await SharedPreferences.getInstance()).clear()),
       _restorePreferences = restorePreferences ?? _restorePreferenceSnapshot,
       _modeService = modeService ?? AppModeService(),
       _receiptSettingsService =
           receiptSettingsService ?? ReceiptSettingsService(),
       _suspendAnalytics =
           (analyticsService?.suspendForReset ??
           AnalyticsService().suspendForReset),
       _resumeAnalytics =
           (analyticsService?.resumeAfterReset ??
           AnalyticsService().resumeAfterReset);

  @visibleForTesting
  AppResetService.forTesting({
    required ResetDatabase resetDatabase,
    required LoadAppPreferences loadPreferences,
    required ClearAppPreferences clearPreferences,
    required RestoreAppPreferences restorePreferences,
    required AppModeService modeService,
    required ReceiptSettingsService receiptSettingsService,
    required SuspendAnalyticsForReset suspendAnalytics,
    required ResumeAnalyticsAfterReset resumeAnalytics,
  }) : _resetDatabase = resetDatabase,
       _loadPreferences = loadPreferences,
       _clearPreferences = clearPreferences,
       _restorePreferences = restorePreferences,
       _modeService = modeService,
       _receiptSettingsService = receiptSettingsService,
       _suspendAnalytics = suspendAnalytics,
       _resumeAnalytics = resumeAnalytics;

  final ResetDatabase _resetDatabase;
  final LoadAppPreferences _loadPreferences;
  final ClearAppPreferences _clearPreferences;
  final RestoreAppPreferences _restorePreferences;
  final AppModeService _modeService;
  final ReceiptSettingsService _receiptSettingsService;
  final SuspendAnalyticsForReset _suspendAnalytics;
  final ResumeAnalyticsAfterReset _resumeAnalytics;

  Future<void> reset() async {
    await _suspendAnalytics();
    try {
      final loaded = await _loadPreferences();
      final snapshot = <String, Object>{};
      for (final entry in loaded.entries) {
        final value = entry.value;
        if (value is List<String>) {
          snapshot[entry.key] = List<String>.from(value);
        } else if (value is bool ||
            value is double ||
            value is int ||
            value is String) {
          snapshot[entry.key] = value!;
        } else if (value != null) {
          throw StateError(
            'Unsupported SharedPreferences value for ${entry.key}.',
          );
        }
      }

      try {
        final cleared = await _clearPreferences();
        final remaining = await _loadPreferences();
        if (!cleared || remaining.isNotEmpty) {
          throw StateError('App preferences could not be cleared.');
        }
      } catch (error) {
        await _restoreOrThrow(snapshot, error);
      }

      try {
        await _resetDatabase();
      } catch (error) {
        await _restoreOrThrow(snapshot, error);
      }

      _modeService.resetToDefaults();
      _receiptSettingsService.resetToDefaults();
    } finally {
      await _resumeAnalytics();
    }
  }

  Future<void> _restoreOrThrow(
    AppPreferencesSnapshot snapshot,
    Object resetError,
  ) async {
    try {
      final restored = await _restorePreferences(snapshot);
      if (!restored) throw StateError('SharedPreferences reported failure.');
    } catch (restorationError) {
      throw StateError(
        'Reset failed ($resetError), and restoring preferences also failed '
        '($restorationError).',
      );
    }
    throw StateError('Reset failed ($resetError); preferences were restored.');
  }

  static Future<Map<String, Object?>> _snapshotPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    return {for (final key in preferences.getKeys()) key: preferences.get(key)};
  }

  static Future<bool> _restorePreferenceSnapshot(
    AppPreferencesSnapshot snapshot,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    var restored = true;
    for (final entry in snapshot.entries) {
      final value = entry.value;
      final bool didRestore;
      switch (value) {
        case bool():
          didRestore = await preferences.setBool(entry.key, value);
        case double():
          didRestore = await preferences.setDouble(entry.key, value);
        case int():
          didRestore = await preferences.setInt(entry.key, value);
        case String():
          didRestore = await preferences.setString(entry.key, value);
        case List<String>():
          didRestore = await preferences.setStringList(entry.key, value);
        default:
          didRestore = false;
      }
      restored = restored && didRestore;
    }
    return restored;
  }
}
