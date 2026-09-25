import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the active app language and resolves the bundled translation maps.
///
/// English is always loaded first. A missing key in a regional catalog therefore
/// falls back to English deterministically, while every supported locale still
/// contributes its translated copy when present.
class AppLanguageService {
  AppLanguageService._({
    AssetBundle? assetBundle,
    Future<SharedPreferences> Function()? preferences,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _preferences = preferences ?? SharedPreferences.getInstance;

  static final AppLanguageService instance = AppLanguageService._();

  static const String preferenceKey = 'app_language';
  static const String _legacyReceiptLanguageKey = 'receipt_language';
  static const Map<String, String> _legacyLanguageCodes = {
    'english': 'en',
    'hindi': 'hi',
    'marathi': 'mr',
    'bengali': 'bn',
    'tamil': 'ta',
  };
  static const Locale englishLocale = Locale('en');
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('hi'),
    Locale('mr'),
    Locale('bn'),
    Locale('ta'),
  ];
  static const Map<String, String> languageNames = {
    'en': 'English',
    'hi': 'हिन्दी',
    'mr': 'मराठी',
    'bn': 'বাংলা',
    'ta': 'தமிழ்',
  };

  final AssetBundle _assetBundle;
  final Future<SharedPreferences> Function() _preferences;
  final ValueNotifier<Locale> localeNotifier = ValueNotifier(englishLocale);
  final Map<String, Map<String, String>> _catalogs = {};
  bool _initialized = false;

  Locale get locale => localeNotifier.value;
  String get languageCode => locale.languageCode;

  Future<void> init() async {
    if (_initialized) return;
    for (final locale in supportedLocales) {
      final code = locale.languageCode;
      final value = await _assetBundle.loadString('assets/i18n/$code.json');
      final decoded = jsonDecode(value) as Map<String, dynamic>;
      _catalogs[code] = decoded.map(
        (key, translation) => MapEntry(key, translation.toString()),
      );
    }
    final preferences = await _preferences();
    final saved = preferences.getString(preferenceKey);
    if (saved is String) {
      // An explicit app-language value takes precedence, even when unsupported.
      localeNotifier.value = _localeFromCode(saved);
    } else {
      final legacyCode = preferences.getString(_legacyReceiptLanguageKey);
      final migratedCode = legacyCode == null
          ? null
          : _legacyLanguageCodes[legacyCode];
      localeNotifier.value = _localeFromCode(migratedCode);
      if (migratedCode != null) {
        await preferences.setString(preferenceKey, migratedCode);
      }
    }
    _initialized = true;
  }

  Future<void> setLocale(Locale locale) async {
    final normalized = _localeFromCode(locale.languageCode);
    localeNotifier.value = normalized;
    final preferences = await _preferences();
    await preferences.setString(preferenceKey, normalized.languageCode);
  }

  String tr(String key, [Map<String, Object?> args = const {}]) {
    final selected = _catalogs[languageCode]?[key];
    final english = _catalogs['en']?[key];
    final template = selected ?? english;
    if (template == null) return key;
    return _interpolate(template, args);
  }

  String trFor(
    Locale locale,
    String key, [
    Map<String, Object?> args = const {},
  ]) {
    final selected = _catalogs[locale.languageCode]?[key];
    final english = _catalogs['en']?[key];
    return _interpolate(selected ?? english ?? key, args);
  }

  String interpolate(String template, Map<String, Object?> args) {
    return _interpolate(template, args);
  }

  /// Keeps import diagnostics deterministic in storage while presenting the
  /// known user-facing reasons in the selected UI language.
  String importReason(String reason) {
    const keys = <String, String>{
      'Empty row (no name or identifier)': 'import_reason_empty',
      'Missing subscriber name': 'import_reason_missing_name',
      'Missing both name and ID (vc_number)': 'import_reason_missing_id_tv',
      'Missing both name and ID (account_id/username/phone)':
          'import_reason_missing_id_fiber',
      'Missing strong identifier': 'import_reason_strong_id',
      'Identifier exists in opposite service': 'import_reason_opposite_service',
      'No name provided for new subscriber': 'import_reason_new_name',
      'No name for new subscriber': 'import_reason_new_name',
    };
    final key = keys[reason];
    return key == null ? reason : tr(key);
  }

  String importStatus(String status) {
    final key = switch (status) {
      'success' => 'import_status_success',
      'partial' => 'import_status_partial',
      'failed' => 'import_status_failed',
      _ => null,
    };
    return key == null ? status : tr(key);
  }

  String importField(String targetField) {
    final key = switch (targetField) {
      'subscriber_name' => 'name',
      'vc_number' => 'vc_number',
      'subscriber identifier' => 'import_field_subscriber_identifier',
      'monthly_amount' => 'monthly_rent',
      'area' => 'area',
      _ => null,
    };
    return key == null ? targetField : tr(key);
  }

  String importSourceColumn(String sourceColumn) {
    const suffix = ' (auto-detected)';
    if (!sourceColumn.endsWith(suffix)) return sourceColumn;
    final source = sourceColumn.substring(
      0,
      sourceColumn.length - suffix.length,
    );
    return '$source (${tr('import_field_auto_detected')})';
  }

  @visibleForTesting
  Map<String, Map<String, String>> get catalogsForTesting =>
      Map.unmodifiable(_catalogs);

  void resetToDefaults() {
    localeNotifier.value = englishLocale;
  }

  @visibleForTesting
  void resetInMemoryForTesting() {
    _catalogs.clear();
    _initialized = false;
    localeNotifier.value = englishLocale;
  }

  static Locale _localeFromCode(String? code) {
    return supportedLocales.firstWhere(
      (locale) => locale.languageCode == code,
      orElse: () => englishLocale,
    );
  }

  static String _interpolate(String template, Map<String, Object?> args) {
    return template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) {
      final value = args[match.group(1)];
      return value == null ? match.group(0)! : value.toString();
    });
  }
}

/// Makes translated strings depend on the active locale without rebuilding the
/// MaterialApp navigator (and therefore without discarding the current route).
class AppLanguageScope extends InheritedWidget {
  const AppLanguageScope({
    required this.locale,
    required super.child,
    super.key,
  });

  final Locale locale;

  static Locale of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope != null, 'No AppLanguageScope found in this context.');
    return scope?.locale ?? AppLanguageService.englishLocale;
  }

  @override
  bool updateShouldNotify(AppLanguageScope oldWidget) {
    return oldWidget.locale != locale;
  }
}

extension AppLocalizations on BuildContext {
  String tr(String key, [Map<String, Object?> args = const {}]) {
    AppLanguageScope.of(this);
    return AppLanguageService.instance.tr(key, args);
  }

  String monthName(int month, {bool short = false}) {
    if (month < 1 || month > 12) return tr('unknown_month');
    return tr('${short ? 'month_short' : 'month_long'}_$month');
  }
}
