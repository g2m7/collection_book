import 'package:collection_book/app_keys.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:collection_book/services/app_mode_service.dart';

import 'app_patrol.dart';

void main() {
  patrolTest(
    'clean launch reaches every empty-data screen and persists receipt settings',
    ($) async {
      await pumpCollectionBook($);

      expect($(AppKeys.homeMonthLabel), findsOneWidget);
      expect(
        $(
          'No Cable TV subscribers yet.\nAdd subscribers and assign them to areas.',
        ),
        findsOneWidget,
      );

      final currentDate = DateTime.now();
      final nextMonth = currentDate.month == 12
          ? 'Jan ${currentDate.year + 1}'
          : '${_shortMonth(currentDate.month + 1)} ${currentDate.year}';
      await $(AppKeys.homeNextMonth).tap();
      await $.pumpAndSettle();
      expect($(nextMonth), findsOneWidget);

      await $(AppKeys.homeSubscribers).tap();
      await $.pumpAndSettle();
      expect($('No subscribers match filters'), findsOneWidget);
      await $(AppKeys.subscriberListAdd).tap();
      await $.pumpAndSettle();
      expect($(AppKeys.subscriberName), findsOneWidget);
      await $(find.byTooltip('Back')).tap();
      await $.pumpAndSettle();
      await $(find.byTooltip('Back')).tap();
      await $.pumpAndSettle();

      await $(AppKeys.homeRecordPayment).tap();
      await $.pumpAndSettle();
      expect($(AppKeys.paymentAmount), findsOneWidget);
      await $(find.byTooltip('Back')).tap();
      await $.pumpAndSettle();

      await $(AppKeys.homeSettings).tap();
      await $.pumpAndSettle();
      await $(AppKeys.settingsReceiptLanguage).tap();
      await $.pumpAndSettle();
      await $(AppKeys.receiptLanguageHindi).tap();
      await $.pumpAndSettle();
      expect($('Hindi'), findsOneWidget);

      await $(AppKeys.settingsBusinessName).tap();
      await $.pumpAndSettle();
      await $(AppKeys.receiptBusinessNameField).enterText('Test Cable');
      await $(AppKeys.receiptBusinessNameSave).tap();
      await $.pumpAndSettle();
      expect($('Test Cable'), findsOneWidget);

      await $(AppKeys.settingsModeFiber).tap();
      await $.pumpAndSettle();
      expect($('Internet'), findsWidgets);
      await $(find.byTooltip('Back')).tap();
      await $.pumpAndSettle();
      expect($('Fiber'), findsOneWidget);

      await $(AppKeys.homeSettings).tap();
      await $.pumpAndSettle();
      await $(AppKeys.settingsImportTv).scrollTo();
      await $(AppKeys.settingsImportTv).tap();
      await $.pumpAndSettle();
      expect($(AppKeys.importTv), findsOneWidget);
      await $(AppKeys.importStartMonth).tap();
      await $(_longMonth(DateTime.now().month)).tap();
      await $(AppKeys.importStartYear).tap();
      await $(DateTime.now().year.toString()).tap();
      await $(AppKeys.importContinue).tap();
      await $.pumpAndSettle();
      expect($(AppKeys.importPickFile), findsOneWidget);
      await $(find.byTooltip('Back')).tap();
      await $.pumpAndSettle();

      await $(AppKeys.settingsImportHistory).scrollTo();
      await $(AppKeys.settingsImportHistory).tap();
      await $.pumpAndSettle();
      expect($(AppKeys.importHistoryEmpty), findsOneWidget);
      await $(find.byTooltip('Back')).tap();
      await $.pumpAndSettle();

      await $(AppKeys.settingsAddArea).scrollTo();
      await $(AppKeys.settingsAddArea).tap();
      await $.pumpAndSettle();
      await $(AppKeys.areaNameField).enterText('North');
      await $(AppKeys.areaNameSave).tap();
      await $.pumpAndSettle();
      expect($('North'), findsOneWidget);

      await $(AppKeys.settingsBackup).scrollTo();
      await $(AppKeys.settingsBackup).tap();
      await $.pumpAndSettle();
      expect(find.textContaining('Last:'), findsOneWidget);

      await $(AppKeys.settingsReset).scrollTo();
      await $(AppKeys.settingsReset).tap();
      await $.pumpAndSettle();
      expect($('Reset App?'), findsOneWidget);
      await $('Cancel').tap();
      await $.pumpAndSettle();
    },
  );

  patrolTest(
    'TV subscriber validation, edit, payment, and dashboard persistence',
    ($) async {
      await pumpCollectionBook($);
      await $(AppKeys.homeSubscribers).tap();
      await $.pumpAndSettle();
      await $(AppKeys.subscriberListAdd).tap();
      await $.pumpAndSettle();

      final form = $.tester.state<FormState>(
        find.byKey(AppKeys.subscriberForm),
      );
      expect(form.validate(), isFalse);
      await $.pumpAndSettle();
      expect($('Name is required'), findsOneWidget);

      await $(AppKeys.subscriberName).scrollTo();
      await $(AppKeys.subscriberName).enterText('Asha Subscriber');
      await $(AppKeys.subscriberIdentifier).enterText('VC-1001');
      await $(AppKeys.subscriberPhone).enterText('9876543210');
      await $(AppKeys.subscriberRent).enterText('750');
      await $(AppKeys.subscriberSave).scrollTo();
      await $(AppKeys.subscriberSave).tap();
      await $.pumpAndSettle();
      expect($('Asha Subscriber'), findsOneWidget);

      await $(AppKeys.subscriberListSearch).enterText('Asha');
      await $.pumpAndSettle();
      expect($('Asha Subscriber'), findsOneWidget);
      await $(AppKeys.subscriberListSearch).enterText('Missing customer');
      await $.pumpAndSettle();
      expect($('Asha Subscriber'), findsNothing);
      expect($('No subscribers match filters'), findsOneWidget);
      await $(AppKeys.subscriberListClearSearch).tap();
      await $.pumpAndSettle();
      expect($('Asha Subscriber'), findsOneWidget);

      await $('Asha Subscriber').tap();
      await $.pumpAndSettle();
      expect($(AppKeys.subscriberDetailEdit), findsOneWidget);
      expect($('VC-1001'), findsOneWidget);
      expect($('9876543210'), findsOneWidget);

      await $(AppKeys.subscriberDetailEdit).tap();
      await $.pumpAndSettle();
      await $(AppKeys.subscriberName).enterText('Asha Kumar');
      await $(AppKeys.subscriberSave).scrollTo();
      await $(AppKeys.subscriberSave).tap();
      await $.pumpAndSettle();
      expect($('Asha Kumar'), findsWidgets);

      await $(AppKeys.subscriberDetailRecordPayment).tap();
      await $.pumpAndSettle();
      expect($(AppKeys.paymentAmount), findsOneWidget);
      await $(AppKeys.paymentSave).scrollTo();
      await $(AppKeys.paymentSave).tap();
      await $.pumpAndSettle();
      expect($('₹750'), findsWidgets);
      expect($(AppKeys.subscriberDetailSendReceipt), findsOneWidget);

      await $(find.byTooltip('Back')).tap();
      await $.pumpAndSettle();
      expect($('Asha Kumar'), findsOneWidget);
      await $(AppKeys.subscriberFilterPaid).tap();
      await $.pumpAndSettle();
      expect($('Asha Kumar'), findsOneWidget);
      await $(AppKeys.subscriberFilterUnpaid).tap();
      await $.pumpAndSettle();
      expect($('Asha Kumar'), findsNothing);
      expect($('No subscribers match filters'), findsOneWidget);
      await $(AppKeys.subscriberFilterAll).tap();
      await $.pumpAndSettle();
      expect($('Asha Kumar'), findsOneWidget);
      await $(find.byTooltip('Back')).tap();
      await $.pumpAndSettle();
      expect($('₹750'), findsWidgets);
    },
  );

  patrolTest(
    'Fiber data stays isolated and persisted mode survives reinitialization',
    ($) async {
      await pumpCollectionBook($);
      await $(AppKeys.homeModeToggle).tap();
      await $.pumpAndSettle();
      expect($('Fiber'), findsOneWidget);

      await $(AppKeys.homeSubscribers).tap();
      await $.pumpAndSettle();
      await $(AppKeys.subscriberListAdd).tap();
      await $.pumpAndSettle();
      expect($('Account ID'), findsOneWidget);
      await $(AppKeys.subscriberName).enterText('Fiber Customer');
      await $(AppKeys.subscriberIdentifier).enterText('NET-2001');
      await $(AppKeys.subscriberUsername).enterText('fiber-user');
      await $(AppKeys.subscriberRent).enterText('900');
      await $(AppKeys.subscriberSave).scrollTo();
      await $(AppKeys.subscriberSave).tap();
      await $.pumpAndSettle();
      expect($('Fiber Customer'), findsOneWidget);

      await $(find.byTooltip('Back')).tap();
      await $.pumpAndSettle();
      await $(AppKeys.homeModeToggle).tap();
      await $.pumpAndSettle();
      await $(AppKeys.homeSubscribers).tap();
      await $.pumpAndSettle();
      expect($('Fiber Customer'), findsNothing);
      expect($('No subscribers match filters'), findsOneWidget);
      await $(find.byTooltip('Back')).tap();
      await $.pumpAndSettle();
      await $(AppKeys.homeModeToggle).tap();
      await $.pumpAndSettle();
      expect($('Fiber'), findsOneWidget);

      await $.pumpWidget(const SizedBox.shrink());
      // Patrol tests live outside analyzer's conventional test/ path.
      // ignore: invalid_use_of_visible_for_testing_member
      AppModeService().resetInMemoryForTesting();
      await pumpCollectionBook($);
      expect($('Fiber'), findsOneWidget);
      await $(AppKeys.homeSubscribers).tap();
      await $.pumpAndSettle();
      expect($('Fiber Customer'), findsOneWidget);
    },
  );
}

String _shortMonth(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}

String _longMonth(int month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return months[month - 1];
}
