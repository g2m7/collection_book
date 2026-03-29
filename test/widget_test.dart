import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const RentLedgerApp());
    expect(find.text('Rent Ledger'), findsOneWidget);
  });
}
