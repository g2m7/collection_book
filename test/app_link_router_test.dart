import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:collection_book/main.dart';
import 'package:collection_book/screens/home_screen.dart';
import 'package:collection_book/screens/import_wizard_screen.dart';
import 'package:collection_book/services/app_language_service.dart';
import 'package:collection_book/services/database_service.dart';
import 'package:collection_book/services/app_link_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    await AppLanguageService.instance.init();
    await DatabaseService().database;
  });

  setUp(() {
    AppLanguageService.instance.resetToDefaults();
  });

  group('AppLinkRouter', () {
    test('accepts only exact cold and warm destination routes', () {
      const expected = <String, AppLinkDestination>{
        'https://cbk.sarbaa.com/import': AppLinkDestination.importWizard,
        '/import': AppLinkDestination.importWizard,
        'https://cbk.sarbaa.com/r/A00000': AppLinkDestination.referralOpen,
        'https://cbk.sarbaa.com/r/ZZZZZZ': AppLinkDestination.referralOpen,
        '/r/AB12CD': AppLinkDestination.referralOpen,
      };

      for (final MapEntry(key: route, value: destination) in expected.entries) {
        expect(AppLinkRouter.parse(route), destination, reason: route);
      }
    });

    test('rejects non-canonical full origins, ports, and userinfo', () {
      const rejected = <String>[
        'http://cbk.sarbaa.com/import',
        'HTTPS://cbk.sarbaa.com/import',
        'https://CBK.SARBAA.COM/import',
        'https://user@cbk.sarbaa.com/import',
        'https://cbk.sarbaa.com:443/import',
        'https://cbk.sarbaa.com:444/import',
        'https://cbk.sarbaa.com./import',
        'https://sarbaa.com/import',
        'https://cbk.sarbaa.com',
        'https://cbk.sarbaa.com/',
        '//cbk.sarbaa.com/import',
      ];

      for (final route in rejected) {
        expect(AppLinkRouter.parse(route), isNull, reason: route);
      }
    });

    test('rejects queries, fragments, and case changes on exact paths', () {
      const rejected = <String>[
        'https://cbk.sarbaa.com/import?source=test',
        'https://cbk.sarbaa.com/import#section',
        'https://cbk.sarbaa.com/import/',
        'https://cbk.sarbaa.com/Import',
        'https://cbk.sarbaa.com/imports',
        'https://cbk.sarbaa.com/import%2F',
        'https://cbk.sarbaa.com/%69mport',
        '/import?source=test',
        '/import#section',
        '/Import',
        '/import/',
        '//import',
      ];

      for (final route in rejected) {
        expect(AppLinkRouter.parse(route), isNull, reason: route);
      }
    });

    test('rejects malformed, encoded, and extra-segment referral paths', () {
      const rejected = <String>[
        'https://cbk.sarbaa.com/r/',
        'https://cbk.sarbaa.com/r/ABCDE',
        'https://cbk.sarbaa.com/r/AB12CDE',
        'https://cbk.sarbaa.com/r/ab12cd',
        'https://cbk.sarbaa.com/r/AB-2CD',
        'https://cbk.sarbaa.com/r/AB12CD/extra',
        'https://cbk.sarbaa.com/r//AB12CD',
        'https://cbk.sarbaa.com/referral/AB12CD',
        'https://cbk.sarbaa.com/r/AB%31%32CD',
        'https://cbk.sarbaa.com/r/AB%2F12CD',
        'https://cbk.sarbaa.com/r/AB12CD?source=test',
        'https://cbk.sarbaa.com/r/AB12CD#section',
        '/r/',
        '/r/ABCDE',
        '/r/AB12CDE',
        '/r/ab12cd',
        '/r/AB12CD/extra',
        '/r//AB12CD',
        '/referral/AB12CD',
        '/r/AB%31%32CD',
        '/r/AB%2F12CD',
        '/r/AB12CD?source=test',
        '/r/AB12CD#section',
      ];

      for (final route in rejected) {
        expect(AppLinkRouter.parse(route), isNull, reason: route);
      }
    });
  });

  group('AppLinkRouter.isPotentialAppLink', () {
    test('identifies rejected links that name the canonical host', () {
      const candidates = <String>[
        'https://cbk.sarbaa.com/r/ABCDE',
        'https://cbk.sarbaa.com/r/AB12CD?source=test',
        'https://cbk.sarbaa.com/r/AB12CD#section',
        'https://cbk.sarbaa.com/import?source=test',
        'https://cbk.sarbaa.com/import/',
        'https://cbk.sarbaa.com/import#section',
        'https://cbk.sarbaa.com/import%2F',
        'https://cbk.sarbaa.com',
        'https://cbk.sarbaa.com/',
        'https://cbk.sarbaa.com/anything-else',
        'https://CBK.SARBAA.COM/import',
        'http://cbk.sarbaa.com/import',
        'https://cbk.sarbaa.com:444/import',
      ];

      for (final route in candidates) {
        expect(AppLinkRouter.isPotentialAppLink(route), isTrue, reason: route);
      }
    });

    test('identifies warm import and referral path candidates', () {
      const candidates = <String>[
        '/import?source=test',
        '/import#section',
        '/import/',
        '/import/extra',
        '/r/',
        '/r/ABCDE',
        '/r/ab12cd',
        '/r/AB12CD/extra',
        '/r//AB12CD',
        '/r/AB12CD?source=test',
      ];

      for (final route in candidates) {
        expect(AppLinkRouter.isPotentialAppLink(route), isTrue, reason: route);
      }
    });

    test('does not identify internal, non-canonical, or partial routes', () {
      const rejected = <String>[
        '/',
        '',
        '/subscribers',
        '/settings',
        '/import-wizard',
        '/import-history',
        '/subscriber-detail',
        '/record-payment',
        '/add-subscriber',
        '/imports',
        '/referral/AB12CD',
        '/r',
        'https://sarbaa.com/import',
        'https://cbk.sarbaa.com.evil.example/import',
        'https://evil.example/r/ABCDE',
        '/import-wizardish',
      ];

      for (final route in rejected) {
        expect(AppLinkRouter.isPotentialAppLink(route), isFalse, reason: route);
      }
    });
  });

  group('App Link navigation', () {
    testWidgets('cold full import URI opens the import wizard', (tester) async {
      await _pumpApp(tester, initialRoute: 'https://cbk.sarbaa.com/import');

      expect(find.byType(ImportWizardScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('warm import path opens the import wizard', (tester) async {
      await _pumpApp(tester);
      expect(await _pushWarmRoute(tester, '/import'), isTrue);

      expect(find.byType(ImportWizardScreen), findsOneWidget);
    });

    testWidgets('cold valid referral URI safely opens home', (tester) async {
      await _pumpApp(tester, initialRoute: 'https://cbk.sarbaa.com/r/AB12CD');

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ImportWizardScreen), findsNothing);
      expect(_currentRouteName(tester), '/');
    });

    testWidgets('warm valid referral from a cold import route opens home', (
      tester,
    ) async {
      await _pumpApp(tester, initialRoute: 'https://cbk.sarbaa.com/import');
      expect(await _pushWarmRoute(tester, '/r/AB12CD'), isTrue);

      expect(find.text('Collection Book').hitTestable(), findsOneWidget);
      expect(_currentRouteName(tester), '/');
    });

    testWidgets('malformed cold external URI falls back to home', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialRoute: 'https://cbk.sarbaa.com/r/not-valid?source=test',
      );

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(_currentRouteName(tester), '/');
    });

    testWidgets(
      'malformed warm external path from the import root falls back to home',
      (tester) async {
        await _pumpApp(tester, initialRoute: 'https://cbk.sarbaa.com/import');
        expect(find.byType(ImportWizardScreen), findsOneWidget);

        expect(await _pushWarmRoute(tester, '/r/ABCDE'), isTrue);

        expect(find.text('Collection Book').hitTestable(), findsOneWidget);
        expect(find.byType(ImportWizardScreen).hitTestable(), findsNothing);
        expect(tester.takeException(), isNull);
        expect(_currentRouteName(tester), '/');
      },
    );

    testWidgets('unknown internal routes keep Flutter failure behavior', (
      tester,
    ) async {
      await _pumpApp(tester);

      await expectLater(
        _pushWarmRoute(tester, '/definitely-not-a-route'),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.message,
            'message',
            contains('Could not find a generator for route'),
          ),
        ),
      );

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(_currentRouteName(tester), '/');
    });
  });
}

String? _currentRouteName(WidgetTester tester) {
  return ModalRoute.of(tester.element(find.byType(HomeScreen)))?.settings.name;
}

Future<void> _pumpApp(WidgetTester tester, {String? initialRoute}) async {
  if (initialRoute != null) {
    tester.platformDispatcher.defaultRouteNameTestValue = initialRoute;
  }
  await tester.pumpWidget(const CollectionBookApp());
  await tester.pump(const Duration(milliseconds: 350));
  await _drainDatabase(tester);
}

/// Pushes a warm route and returns the framework's success-envelope value, or
/// throws the framework's `PlatformException` when it rejects the route.
Future<Object?> _pushWarmRoute(WidgetTester tester, String route) async {
  final message = const JSONMethodCodec().encodeMethodCall(
    MethodCall('pushRouteInformation', <String, Object?>{'location': route}),
  );
  final response = await tester.binding.defaultBinaryMessenger
      .handlePlatformMessage('flutter/navigation', message, (_) {});
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await _drainDatabase(tester);
  await tester.pump();
  await _drainDatabase(tester);
  return response == null
      ? null
      : const JSONMethodCodec().decodeEnvelope(response);
}

Future<void> _drainDatabase(WidgetTester tester) async {
  await tester.runAsync(() async {
    final database = await DatabaseService().database;
    for (var query = 0; query < 4; query++) {
      await database.query('areas');
    }
  });
}
