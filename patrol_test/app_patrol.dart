import 'package:collection_book/main.dart';
import 'package:patrol/patrol.dart';

Future<void> pumpCollectionBook(PatrolIntegrationTester tester) async {
  await initializeCollectionBookApp();
  await tester.pumpWidgetAndSettle(const CollectionBookApp());
}
