import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:collection_book/main.dart';
import 'package:collection_book/services/app_language_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    await AppLanguageService.instance.init();
  });

  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const CollectionBookApp());
    expect(find.text('Collection Book'), findsOneWidget);
  });

  testWidgets('language switches immediately and persists', (tester) async {
    await tester.pumpWidget(const CollectionBookApp());
    await AppLanguageService.instance.setLocale(const Locale('hi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(AppLanguageService.instance.tr('app_name'), 'कलेक्शन बुक');
    expect(find.text('कलेक्शन बुक'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString(
        AppLanguageService.preferenceKey,
      ),
      'hi',
    );
  });
}
