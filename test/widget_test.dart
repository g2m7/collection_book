import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:collection_book/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const CollectionBookApp());
    expect(find.text('Collection Book'), findsOneWidget);
  });
}
