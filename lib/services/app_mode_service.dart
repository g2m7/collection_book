import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ServiceMode { tv, fiber }

extension ServiceModeX on ServiceMode {
  String get key => name; // 'tv' or 'fiber'
  String get label => this == ServiceMode.tv ? 'Cable TV' : 'Internet';
  String get shortLabel => this == ServiceMode.tv ? 'TV' : 'Fiber';
  IconData get icon => this == ServiceMode.tv
      ? PhosphorIcons.televisionSimple(PhosphorIconsStyle.bold)
      : PhosphorIcons.globeHemisphereWest(PhosphorIconsStyle.bold);
}

class AppModeService {
  static final AppModeService _instance = AppModeService._();
  factory AppModeService() => _instance;
  AppModeService._();

  static const _prefKey = 'service_mode';

  final ValueNotifier<ServiceMode> modeNotifier = ValueNotifier(ServiceMode.tv);

  ServiceMode get mode => modeNotifier.value;

  /// Restores the default in-memory value after an all-app-data reset.
  void resetToDefaults() {
    modeNotifier.value = ServiceMode.tv;
  }

  /// Clears only the in-memory singleton value for restart-style tests.
  @visibleForTesting
  void resetInMemoryForTesting() => resetToDefaults();

  /// Call once at app start to restore persisted mode.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    modeNotifier.value = saved == ServiceMode.fiber.key
        ? ServiceMode.fiber
        : ServiceMode.tv;
  }

  Future<void> setMode(ServiceMode mode) async {
    modeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode.key);
  }

  Future<void> toggle() async {
    await setMode(mode == ServiceMode.tv ? ServiceMode.fiber : ServiceMode.tv);
  }
}
