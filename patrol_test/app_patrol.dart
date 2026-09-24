import 'package:collection_book/main.dart';
import 'package:patrol/patrol.dart';

Future<void> initializeCollectionBookForTest() {
  return initializeCollectionBookApp();
}

Future<void> pumpCollectionBook(PatrolIntegrationTester tester) async {
  await initializeCollectionBookForTest();
  await tester.pumpWidgetAndSettle(const CollectionBookApp());
}
