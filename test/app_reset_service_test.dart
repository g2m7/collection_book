import 'package:collection_book/services/app_mode_service.dart';
import 'package:collection_book/services/app_language_service.dart';
import 'package:collection_book/services/app_reset_service.dart';
import 'package:collection_book/services/receipt_settings_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppModeService modeService;
  late ReceiptSettingsService receiptSettings;

  setUp(() {
    modeService = AppModeService();
    receiptSettings = ReceiptSettingsService();
    modeService.resetToDefaults();
    AppLanguageService.instance.resetToDefaults();
    receiptSettings.resetToDefaults();
  });

  tearDown(() {
    modeService.resetToDefaults();
    AppLanguageService.instance.resetToDefaults();
    receiptSettings.resetToDefaults();
  });

  AppResetService service({
    required Map<String, Object?> preferences,
    required Future<void> Function() resetDatabase,
    Future<bool> Function()? clearPreferences,
    Future<bool> Function(AppPreferencesSnapshot)? restorePreferences,
    void Function(bool suspended)? observeAnalytics,
  }) {
    return AppResetService.forTesting(
      loadPreferences: () async => Map.of(preferences),
      clearPreferences:
          clearPreferences ??
          () async {
            final cleared = preferences.isNotEmpty;
            preferences.clear();
            return cleared;
          },
      restorePreferences:
          restorePreferences ??
          (snapshot) async {
            preferences
              ..clear()
              ..addAll(snapshot);
            return true;
          },
      resetDatabase: resetDatabase,
      modeService: modeService,
      receiptSettingsService: receiptSettings,
      suspendAnalytics: () async {
        expect(preferences, isNotEmpty, reason: 'reset must start fenced');
        observeAnalytics?.call(true);
      },
      resumeAnalytics: () async => observeAnalytics?.call(false),
    );
  }

  test(
    'clears supported preferences before database, then singleton defaults',
    () async {
      final preferences = <String, Object?>{
        'service_mode': 'fiber',
        'app_language': 'hi',
        'receipt_language': 'hindi',
        'receipt_business_name': 'Old Business',
        'receipt_referral_code': 'ABC234',
        'analytics_client_id_v1': 'anon_0123456789abcdef0123456789abcdef',
        'bool': true,
        'int': 42,
        'double': 1.5,
        'strings': <String>['one', 'two'],
      };
      modeService.modeNotifier.value = ServiceMode.fiber;
      AppLanguageService.instance.localeNotifier.value = const Locale('hi');
      receiptSettings.languageNotifier.value = ReceiptLanguage.hindi;
      receiptSettings.businessNameNotifier.value = 'Old Business';
      var databaseReset = false;
      final analyticsStates = <bool>[];

      await service(
        preferences: preferences,
        resetDatabase: () async {
          expect(preferences, isEmpty);
          databaseReset = true;
        },
        observeAnalytics: analyticsStates.add,
      ).reset();

      expect(databaseReset, isTrue);
      expect(preferences, isEmpty);
      expect(modeService.mode, ServiceMode.tv);
      expect(AppLanguageService.instance.languageCode, 'en');
      expect(receiptSettings.language, ReceiptLanguage.english);
      expect(
        receiptSettings.businessNameNotifier.value,
        ReceiptSettingsService.defaultBusinessName,
      );
      expect(analyticsStates, [true, false]);
    },
  );

  test(
    'restores preferences and leaves memory unchanged when clear fails',
    () async {
      final preferences = <String, Object?>{
        'service_mode': 'fiber',
        'app_language': 'hi',
        'receipt_language': 'hindi',
      };
      modeService.modeNotifier.value = ServiceMode.fiber;
      AppLanguageService.instance.localeNotifier.value = const Locale('hi');
      receiptSettings.languageNotifier.value = ReceiptLanguage.hindi;
      final analyticsStates = <bool>[];

      await expectLater(
        service(
          preferences: preferences,
          clearPreferences: () async => false,
          resetDatabase: () async => fail('database must not reset'),
          observeAnalytics: analyticsStates.add,
        ).reset(),
        throwsA(isA<StateError>()),
      );

      expect(preferences['service_mode'], 'fiber');
      expect(preferences['receipt_language'], 'hindi');
      expect(modeService.mode, ServiceMode.fiber);
      expect(AppLanguageService.instance.languageCode, 'hi');
      expect(receiptSettings.language, ReceiptLanguage.hindi);
      expect(analyticsStates, [true, false]);
    },
  );

  test('restores preferences when clear only partially succeeds', () async {
    final preferences = <String, Object?>{'service_mode': 'fiber'};

    await expectLater(
      service(
        preferences: preferences,
        clearPreferences: () async {
          preferences['leftover'] = true;
          return true;
        },
        resetDatabase: () async => fail('database must not reset'),
      ).reset(),
      throwsA(isA<StateError>()),
    );

    expect(preferences, {'service_mode': 'fiber'});
  });

  test('restores preferences when database reset throws', () async {
    final preferences = <String, Object?>{
      'service_mode': 'fiber',
      'receipt_referral_code': 'ABC234',
    };

    await expectLater(
      service(
        preferences: preferences,
        resetDatabase: () async => throw StateError('database unavailable'),
      ).reset(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('preferences were restored'),
        ),
      ),
    );
    expect(preferences['service_mode'], 'fiber');
    expect(preferences['receipt_referral_code'], 'ABC234');
  });

  test(
    'surfaces preference restoration failure without reporting success',
    () async {
      await expectLater(
        service(
          preferences: <String, Object?>{'service_mode': 'fiber'},
          resetDatabase: () async => throw StateError('database unavailable'),
          restorePreferences: (_) async => false,
        ).reset(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('restoring preferences also failed'),
          ),
        ),
      );
    },
  );
}
