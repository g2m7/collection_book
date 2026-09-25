import 'package:collection_book/app_keys.dart';
import 'package:collection_book/models/area.dart';
import 'package:collection_book/models/import_result.dart';
import 'package:collection_book/models/import_run.dart';
import 'package:collection_book/models/payment.dart';
import 'package:collection_book/main.dart';
import 'package:collection_book/models/subscriber.dart';
import 'package:collection_book/services/app_mode_service.dart';
import 'package:collection_book/services/app_language_service.dart';
import 'package:collection_book/services/backup_service.dart';
import 'package:collection_book/services/database_service.dart';
import 'package:collection_book/services/receipt_settings_service.dart';
import 'package:collection_book/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_patrol.dart';

void main() {
  setUp(() {
    AppLanguageService.instance.resetToDefaults();
    AppModeService().resetToDefaults();
    ReceiptSettingsService().resetToDefaults();
  });

  patrolTest(
    'dashboard KPIs, month boundaries, and area deep link are data-driven',
    ($) async {
      await initializeCollectionBookForTest();
      final db = DatabaseService();
      final now = DateTime.now();
      final ids = await _seedDashboardSubscribers(db);
      final summary = await db.getDashboardSummary(
        now.year,
        now.month,
        serviceType: 'tv',
      );
      expect(summary['subscriber_count'], 3);
      expect(summary['paid_count'], 2);
      expect(summary['unpaid_count'], 1);
      expect(summary['total_dues'], closeTo(now.month * 700 - 250, 0.001));
      await $.pumpWidgetAndSettle(const CollectionBookApp());

      expect($('Outstanding Dues'), findsOneWidget);
      expect($('Collected'), findsOneWidget);
      expect($('Pending'), findsOneWidget);
      expect($('3 subscribers'), findsOneWidget);
      expect($('1 unpaid'), findsOneWidget);
      expect(find.byKey(AppKeys.homeAreaCard(ids.northId)), findsOneWidget);
      expect(find.byKey(AppKeys.homeAreaCard(ids.southId)), findsOneWidget);
      expect($('North'), findsOneWidget);
      expect($('South'), findsOneWidget);

      for (var i = 0; i < now.month - 1; i++) {
        await $(AppKeys.homePreviousMonth).tap();
        await $.pumpAndSettle();
      }
      expect($('Jan ${now.year}'), findsOneWidget);
      expect(
        $.tester
            .widget<IconButton>(find.byKey(AppKeys.homePreviousMonth))
            .onPressed,
        isNull,
      );

      await $(AppKeys.homeNextMonth).tap();
      await $.pumpAndSettle();
      expect($('Feb ${now.year}'), findsOneWidget);
      for (var i = 1; i < 12; i++) {
        await $(AppKeys.homeNextMonth).tap();
        await $.pumpAndSettle();
      }
      expect($('Jan ${now.year + 1}'), findsOneWidget);
      await $(AppKeys.homeMonthLabel).tap();
      await $.pumpAndSettle();
      expect($('${_shortMonth(now.month)} ${now.year}'), findsOneWidget);

      await $(AppKeys.homeAreaCard(ids.northId)).tap();
      await $.pumpAndSettle();
      expect($('2 shown'), findsOneWidget);
      expect($('Alpha Subscriber'), findsOneWidget);
      expect($('Bravo Subscriber'), findsOneWidget);
      expect($('Charlie Advance'), findsNothing);
    },
  );

  patrolTest('TV form validates and persists every common subscriber field', (
    $,
  ) async {
    await pumpCollectionBook($);
    await DatabaseService().insertArea(const Area(name: 'Form Area'));
    await $(AppKeys.homeSubscribers).tap();
    await $.pumpAndSettle();
    await $(AppKeys.subscriberListAdd).tap();
    await $.pumpAndSettle();

    final form = $.tester.state<FormState>(find.byKey(AppKeys.subscriberForm));
    expect(form.validate(), isFalse);
    await $.pumpAndSettle();
    expect($('Name is required'), findsOneWidget);

    await $(AppKeys.subscriberName).enterText('Asha Subscriber');
    await $(AppKeys.subscriberArea).tap();
    await $('Form Area').tap();
    await $.pumpAndSettle();
    await $(AppKeys.subscriberIdentifier).enterText('VC-1001');
    await $(AppKeys.subscriberAlias).enterText('Asha Home');
    await $(AppKeys.subscriberPhone).scrollTo();
    await $(AppKeys.subscriberPhone).enterText('1234');
    expect(form.validate(), isFalse);
    await $.pumpAndSettle();
    expect($('Enter a valid Indian mobile number'), findsOneWidget);

    await $(AppKeys.subscriberPhone).scrollTo();
    await $(AppKeys.subscriberPhone).enterText('9876543210');
    await $(AppKeys.subscriberPreviousDue).scrollTo();
    await $(AppKeys.subscriberPreviousDue).enterText('125');
    await $(AppKeys.subscriberRent).scrollTo();
    await $(AppKeys.subscriberRent).enterText('');
    expect(form.validate(), isFalse);
    await $.pumpAndSettle();
    expect($('Enter rent amount'), findsOneWidget);

    await $(AppKeys.subscriberRent).scrollTo();
    await $(AppKeys.subscriberRent).enterText('750');
    await $(AppKeys.subscriberStartMonth).scrollTo();
    await $(AppKeys.subscriberStartMonth).tap();
    await $('January').tap();
    await $.pumpAndSettle();
    await $(AppKeys.subscriberActive).scrollTo();
    await $(AppKeys.subscriberActive).tap();
    await $(AppKeys.subscriberSave).tap();
    await $.pumpAndSettle();

    expect($('Asha Subscriber'), findsOneWidget);
    expect($('Asha Home'), findsOneWidget);
    expect($('Form Area'), findsWidgets);
    expect($('Inactive'), findsWidgets);
    expect($('Prev: ₹125'), findsOneWidget);

    await $('Asha Subscriber').tap();
    await $.pumpAndSettle();
    expect($('VC-1001'), findsOneWidget);
    expect($('9876543210'), findsOneWidget);
    expect($('₹750'), findsWidgets);
    expect($('₹125'), findsOneWidget);
    expect($('Inactive'), findsOneWidget);

    await $(AppKeys.subscriberDetailEdit).tap();
    await $.pumpAndSettle();
    await $(AppKeys.subscriberName).scrollTo();
    await $(AppKeys.subscriberName).enterText('Asha Kumar');
    await $(AppKeys.subscriberAlias).scrollTo();
    await $(AppKeys.subscriberAlias).enterText('Kumar Home');
    await $(AppKeys.subscriberIdentifier).scrollTo();
    await $(AppKeys.subscriberIdentifier).enterText('VC-2002');
    await $(AppKeys.subscriberPhone).scrollTo();
    await $(AppKeys.subscriberPhone).enterText('9123456780');
    await $(AppKeys.subscriberRent).scrollTo();
    await $(AppKeys.subscriberRent).enterText('800');
    await $(AppKeys.subscriberPreviousDue).scrollTo();
    await $(AppKeys.subscriberPreviousDue).enterText('200');
    await $(AppKeys.subscriberStartMonth).scrollTo();
    await $(AppKeys.subscriberStartMonth).tap();
    await $('February').tap();
    await $.pumpAndSettle();
    await $(AppKeys.subscriberActive).scrollTo();
    await $(AppKeys.subscriberActive).tap();
    await $(AppKeys.subscriberSave).scrollTo();
    await $(AppKeys.subscriberSave).tap();
    await $.pumpAndSettle();

    expect($('Asha Kumar'), findsWidgets);
    expect($('Kumar Home'), findsOneWidget);
    expect($('VC-2002'), findsOneWidget);
    expect($('9123456780'), findsOneWidget);
    expect($('₹800'), findsWidgets);
    expect($('₹200'), findsOneWidget);
    expect($('Active'), findsOneWidget);
  });

  patrolTest(
    'fiber form exposes service fields and persisted isolation survives reinit',
    ($) async {
      final db = DatabaseService();
      await pumpCollectionBook($);
      expect(
        _primaryColor($),
        AppTheme.themeFor(ServiceMode.tv).colorScheme.primary,
      );
      await db.insertSubscriber(
        Subscriber(
          name: 'TV Neighbor',
          vcNumber: 'VC-NEIGHBOR',
          monthlyRent: 300,
          serviceType: 'tv',
          startYear: DateTime.now().year,
          startMonth: 1,
        ),
      );
      await $(AppKeys.homeModeToggle).tap();
      await $.pumpAndSettle();
      expect($('Fiber'), findsOneWidget);
      expect(
        _primaryColor($),
        AppTheme.themeFor(ServiceMode.fiber).colorScheme.primary,
      );
      await $(AppKeys.homeSubscribers).tap();
      await $.pumpAndSettle();
      await $(AppKeys.subscriberListAdd).tap();
      await $.pumpAndSettle();

      expect($('Account ID'), findsOneWidget);
      expect($('VC Number'), findsNothing);
      await $(AppKeys.subscriberServiceTv).scrollTo();
      await $(AppKeys.subscriberServiceTv).tap();
      await $.pumpAndSettle();
      await $.tester.drag(find.byType(ListView), const Offset(0, 1000));
      await $.pumpAndSettle();
      expect($('VC Number'), findsOneWidget);
      expect($('Account ID'), findsNothing);
      await $(AppKeys.subscriberServiceFiber).scrollTo();
      await $(AppKeys.subscriberServiceFiber).tap();
      await $.pumpAndSettle();
      await $.tester.drag(find.byType(ListView), const Offset(0, 1000));
      await $.pumpAndSettle();

      await $(AppKeys.subscriberName).enterText('Fiber Customer');
      await $(AppKeys.subscriberAlias).enterText('Broadband Home');
      await $(AppKeys.subscriberIdentifier).enterText('NET-2001');
      await $(AppKeys.subscriberUsername).enterText('fiber-user');
      await $(AppKeys.subscriberPhone).enterText('9988776655');
      await $(AppKeys.subscriberRent).enterText('900');
      await $(AppKeys.subscriberPreviousDue).scrollTo();
      await $(AppKeys.subscriberPreviousDue).enterText('75');
      await $(AppKeys.subscriberStartMonth).tap();
      await $('January').tap();
      await $.pumpAndSettle();
      await $(AppKeys.subscriberSave).scrollTo();
      await $(AppKeys.subscriberSave).tap();
      await $.pumpAndSettle();
      expect($('Fiber Customer'), findsOneWidget);
      expect($('Broadband Home'), findsOneWidget);
      final created = (await db.getSubscribers(serviceType: 'fiber')).single;
      expect(created.name, 'Fiber Customer');
      expect(created.aliasName, 'Broadband Home');
      expect(created.vcNumber, isNull);
      expect(created.accountId, 'NET-2001');
      expect(created.username, 'fiber-user');
      expect(created.phone, '9988776655');
      expect(created.monthlyRent, 900);
      expect(created.previousDue, 75);
      expect(created.startYear, DateTime.now().year);
      expect(created.startMonth, 1);
      expect(created.serviceType, 'fiber');

      await $('Fiber Customer').tap();
      await $.pumpAndSettle();
      expect($('₹900'), findsWidgets);
      expect($('₹75'), findsOneWidget);
      await $(AppKeys.subscriberDetailEdit).tap();
      await $.pumpAndSettle();
      await $(AppKeys.subscriberName).scrollTo();
      await $(AppKeys.subscriberName).enterText('Fiber Updated');
      await $(AppKeys.subscriberAlias).scrollTo();
      await $(AppKeys.subscriberAlias).enterText('Updated Home');
      await $(AppKeys.subscriberIdentifier).scrollTo();
      await $(AppKeys.subscriberIdentifier).enterText('NET-3003');
      await $(AppKeys.subscriberUsername).scrollTo();
      await $(AppKeys.subscriberUsername).enterText('updated-user');
      await $(AppKeys.subscriberPhone).scrollTo();
      await $(AppKeys.subscriberPhone).enterText('9000000000');
      await $(AppKeys.subscriberRent).scrollTo();
      await $(AppKeys.subscriberRent).enterText('950');
      await $(AppKeys.subscriberPreviousDue).scrollTo();
      await $(AppKeys.subscriberPreviousDue).enterText('25');
      await $(AppKeys.subscriberStartMonth).scrollTo();
      await $(AppKeys.subscriberStartMonth).tap();
      await $('February').tap();
      await $.pumpAndSettle();
      await $(AppKeys.subscriberSave).scrollTo();
      await $(AppKeys.subscriberSave).tap();
      await $.pumpAndSettle();
      expect($('Fiber Updated'), findsWidgets);
      final edited = await db.getSubscriber(created.id!);
      expect(edited?.name, 'Fiber Updated');
      expect(edited?.aliasName, 'Updated Home');
      expect(edited?.accountId, 'NET-3003');
      expect(edited?.username, 'updated-user');
      expect(edited?.phone, '9000000000');
      expect(edited?.monthlyRent, 950);
      expect(edited?.previousDue, 25);
      expect(edited?.startMonth, 2);
      expect(edited?.serviceType, 'fiber');

      await $.tester.pageBack();
      await $.pumpAndSettle();
      await $.tester.pageBack();
      await $.pumpAndSettle();
      await $(AppKeys.homeModeToggle).tap();
      await $.pumpAndSettle();
      expect($('TV'), findsOneWidget);
      await $(AppKeys.homeSubscribers).tap();
      await $.pumpAndSettle();
      expect($('TV Neighbor'), findsOneWidget);
      expect($('Fiber Updated'), findsNothing);

      await $.tester.pageBack();
      await $.pumpAndSettle();
      await $(AppKeys.homeModeToggle).tap();
      await $.pumpAndSettle();
      await $.pumpWidget(const SizedBox.shrink());
      // Patrol tests live outside analyzer's conventional test/ path.
      // ignore: invalid_use_of_visible_for_testing_member
      AppModeService().resetInMemoryForTesting();
      await pumpCollectionBook($);
      expect($('Fiber'), findsOneWidget);
      await $(AppKeys.homeSubscribers).tap();
      await $.pumpAndSettle();
      expect($('Fiber Updated'), findsOneWidget);
    },
  );

  patrolTest(
    'search, combined filters, area grouping, and every sort mode work together',
    ($) async {
      await initializeCollectionBookForTest();
      final db = DatabaseService();
      final ids = await _seedFilterSubscribers(db);
      final seeded = await db.getSubscribers(serviceType: 'tv');
      final balances = {
        for (final subscriber in seeded) subscriber.name: subscriber.currentDue,
      };
      expect(balances['Alpha Subscriber'], closeTo(0, 0.001));
      expect(balances['Bravo Subscriber'], closeTo(0, 0.001));
      expect(balances['Charlie Advance'], closeTo(-250, 0.001));
      expect(
        balances['Delta Inactive'],
        closeTo(DateTime.now().month * 500, 0.001),
      );
      await $.pumpWidgetAndSettle(const CollectionBookApp());
      await $(AppKeys.homeSubscribers).tap();
      await $.pumpAndSettle();

      expect($('4 shown'), findsOneWidget);
      expect($('No Area'), findsNothing);
      expect($('North'), findsWidgets);
      expect($('South'), findsWidgets);

      await $(AppKeys.subscriberListSearch).enterText('Asha Home');
      await $.pumpAndSettle();
      expect($('Alpha Subscriber'), findsOneWidget);
      expect($('Bravo Subscriber'), findsNothing);
      await $(AppKeys.subscriberListSearch).enterText('Missing customer');
      await $.pumpAndSettle();
      expect($('No subscribers match filters'), findsOneWidget);
      await $(AppKeys.subscriberListSearch).enterText('VC-3003');
      await $.pumpAndSettle();
      expect($('Charlie Advance'), findsOneWidget);
      await $(AppKeys.subscriberListClearSearch).tap();
      await $.pumpAndSettle();
      expect($('4 shown'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await $.pumpAndSettle();
      await $.tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(-500, 0),
      );
      await $.pumpAndSettle();
      await $(AppKeys.subscriberStatusInactive).tap();
      await $.pumpAndSettle();
      expect($('1 shown'), findsOneWidget);
      expect($('Delta Inactive'), findsOneWidget);
      await $(AppKeys.subscriberStatusActive).tap();
      await $.pumpAndSettle();
      expect($('3 shown'), findsOneWidget);
      expect($('Delta Inactive'), findsNothing);
      await $.tester.ensureVisible(find.byKey(AppKeys.subscriberStatusActive));
      await $.pumpAndSettle();
      await $(AppKeys.subscriberStatusActive).tap();
      await $.pumpAndSettle();

      await $.tester.ensureVisible(find.byKey(AppKeys.subscriberFilterPaid));
      await $.pumpAndSettle();
      await $(AppKeys.subscriberFilterPaid).tap();
      await $.pumpAndSettle();
      expect($('3 shown'), findsOneWidget);
      expect($('Alpha Subscriber'), findsOneWidget);
      expect($('Bravo Subscriber'), findsOneWidget);
      expect($('Charlie Advance'), findsOneWidget);

      await $.tester.ensureVisible(find.byKey(AppKeys.subscriberFilterAll));
      await $.pumpAndSettle();
      await $(AppKeys.subscriberFilterAll).tap();
      await $.pumpAndSettle();
      await $.tester.ensureVisible(
        find.byKey(AppKeys.subscriberFilterOverpaid),
      );
      await $.pumpAndSettle();
      await $(AppKeys.subscriberFilterOverpaid).tap();
      await $.pumpAndSettle();
      expect($('1 shown'), findsOneWidget);
      expect($('Charlie Advance'), findsOneWidget);
      expect($('Alpha Subscriber'), findsNothing);

      await $.tester.ensureVisible(find.byKey(AppKeys.subscriberFilterUnpaid));
      await $.pumpAndSettle();
      await $(AppKeys.subscriberFilterUnpaid).tap();
      await $.pumpAndSettle();
      expect($('1 shown'), findsOneWidget);
      expect($('Delta Inactive'), findsOneWidget);
      expect($('Alpha Subscriber'), findsNothing);
      await $(AppKeys.subscriberListFilters).tap();
      await $.pumpAndSettle();
      await $(AppKeys.subscriberAreaFilter(ids.northId)).tap();
      await $.pumpAndSettle();
      expect($('1 shown'), findsOneWidget);
      expect($('Delta Inactive'), findsOneWidget);
      expect($('Alpha Subscriber'), findsNothing);
      await $.tester.ensureVisible(find.byKey(AppKeys.subscriberFilterAll));
      await $.pumpAndSettle();
      await $(AppKeys.subscriberFilterAll).tap();
      await $.pumpAndSettle();
      await $(AppKeys.subscriberAreaFilter(ids.northId)).tap();
      await $.pumpAndSettle();
      expect($('4 shown'), findsOneWidget);

      for (final key in const [
        AppKeys.subscriberSortNameDsc,
        AppKeys.subscriberSortDueHigh,
        AppKeys.subscriberSortDueLow,
        AppKeys.subscriberSortRentHigh,
        AppKeys.subscriberSortRentLow,
        AppKeys.subscriberSortNameAsc,
      ]) {
        await $(key).tap();
        await $.pumpAndSettle();
        expect($.tester.widget<FilterChip>(find.byKey(key)).selected, isTrue);
        expect($('4 shown'), findsOneWidget);
        switch (key) {
          case AppKeys.subscriberSortNameDsc:
            await _expectVerticalOrder($, const [
              'Delta Inactive',
              'Bravo Subscriber',
              'Alpha Subscriber',
              'Charlie Advance',
            ]);
          case AppKeys.subscriberSortDueHigh:
            await _expectVerticalOrder($, const [
              'Delta Inactive',
              'Alpha Subscriber',
              'Bravo Subscriber',
              'Charlie Advance',
            ]);
          case AppKeys.subscriberSortDueLow:
            await _expectVerticalOrder($, const [
              'Charlie Advance',
              'Alpha Subscriber',
              'Bravo Subscriber',
              'Delta Inactive',
            ]);
          case AppKeys.subscriberSortRentHigh:
            await _expectVerticalOrder($, const [
              'Bravo Subscriber',
              'Charlie Advance',
              'Alpha Subscriber',
              'Delta Inactive',
            ]);
          case AppKeys.subscriberSortRentLow:
            await _expectVerticalOrder($, const [
              'Delta Inactive',
              'Alpha Subscriber',
              'Charlie Advance',
              'Bravo Subscriber',
            ]);
          case AppKeys.subscriberSortNameAsc:
            await _expectVerticalOrder($, const [
              'Alpha Subscriber',
              'Bravo Subscriber',
              'Delta Inactive',
              'Charlie Advance',
            ]);
        }
      }
    },
  );

  patrolTest(
    'payment helpers, adjustments, projection, edit, and delete stay consistent',
    ($) async {
      await initializeCollectionBookForTest();
      final db = DatabaseService();
      final now = DateTime.now();
      final id = await db.insertSubscriber(
        Subscriber(
          name: 'Payment Ledger',
          aliasName: 'Ledger Home',
          vcNumber: 'VC-PAY-1',
          monthlyRent: 650,
          previousDue: 100,
          serviceType: 'tv',
          startYear: now.year,
          startMonth: 1,
        ),
      );
      await $.pumpWidgetAndSettle(const CollectionBookApp());
      await $(AppKeys.homeSubscribers).tap();
      await $.pumpAndSettle();
      await $('Payment Ledger').tap();
      await $.pumpAndSettle();

      expect($('Year ${now.year}'), findsOneWidget);
      expect(
        $(AppKeys.subscriberDetailMonth(now.month, now.year)),
        findsOneWidget,
      );
      await $(AppKeys.subscriberDetailYearNext).tap();
      await $.pumpAndSettle();
      expect($('Year ${now.year + 1}'), findsOneWidget);
      await $(AppKeys.subscriberDetailYearPrevious).tap();
      await $.pumpAndSettle();
      expect($('Year ${now.year}'), findsOneWidget);

      final matrixMonth = now.month == 1 ? 2 : 1;
      final changedMonth = matrixMonth == 1 ? 2 : 1;
      await $(AppKeys.subscriberDetailMonth(matrixMonth, now.year)).tap();
      await $.pumpAndSettle();
      expect($('Record Payment'), findsOneWidget);
      expect(
        $(
          'Current due till ${_longMonth(matrixMonth)} ${now.year}: ₹${matrixMonth * 650 + 100}',
        ),
        findsOneWidget,
      );
      await $(AppKeys.paymentMonth).tap();
      await $(_longMonth(changedMonth)).tap();
      await $.pumpAndSettle();
      await $(AppKeys.paymentYear).tap();
      await $('${now.year + 1}').tap();
      await $.pumpAndSettle();
      final monthsThroughChangedPeriod =
          (now.year + 1 - now.year) * 12 + changedMonth;
      expect(
        $(
          'Current due till ${_longMonth(changedMonth)} ${now.year + 1}: '
          '₹${monthsThroughChangedPeriod * 650 + 100}',
        ),
        findsOneWidget,
      );
      await $(find.byTooltip('Back')).tap();
      await $.pumpAndSettle();

      await $(AppKeys.subscriberDetailRecordPayment).tap();
      await $.pumpAndSettle();
      final due = now.month * 650 + 100;
      await $(AppKeys.paymentAdjustment).scrollTo();
      await $(AppKeys.paymentAdjustment).enterText('200');
      await $(AppKeys.paymentClearDue).tap();
      await $.pumpAndSettle();
      expect(
        $('Suggested amount to make due 0: ₹${due + 200}'),
        findsOneWidget,
      );
      await $(AppKeys.paymentClearDueApply).tap();
      await $.pumpAndSettle();
      expect(_textFieldValue($, AppKeys.paymentAmount), '${due + 200}');
      await $(AppKeys.paymentClearDue).tap();
      await $.pumpAndSettle();
      await $(AppKeys.paymentClearDueApplyNote).tap();
      await $.pumpAndSettle();
      await $(AppKeys.paymentNote).scrollTo();
      expect(_textFieldValue($, AppKeys.paymentNote), contains('Auto-set'));
      expect($('After save: due becomes 0 (fully clear).'), findsOneWidget);
      await $(AppKeys.paymentSave).scrollTo();
      await $(AppKeys.paymentSave).tap();
      await $.pumpAndSettle();
      expect($('Payment recorded for Payment Ledger'), findsOneWidget);

      await $(AppKeys.subscriberDetailRecordPayment).tap();
      await $.pumpAndSettle();
      expect($('Edit Payment'), findsOneWidget);
      await $(AppKeys.paymentAmount).enterText('100');
      await $(AppKeys.paymentAdjustment).enterText('-50');
      await $(AppKeys.paymentNote).scrollTo();
      await $(AppKeys.paymentNote).enterText('Approved discount');
      await $.tester.drag(find.byType(ListView), const Offset(0, 1000));
      await $.pumpAndSettle();
      expect(find.textContaining('remaining due will be'), findsOneWidget);
      await $(AppKeys.paymentSave).scrollTo();
      await $(AppKeys.paymentSave).tap();
      await $.pumpAndSettle();

      final edited = await db.getPayment(id, now.year, now.month);
      expect(edited?.amountPaid, 100);
      expect(edited?.adjustment, -50);
      expect(edited?.adjustmentNote, 'Approved discount');

      await $(AppKeys.subscriberDetailRecordPayment).tap();
      await $.pumpAndSettle();
      await $(AppKeys.paymentDelete).scrollTo();
      await $(AppKeys.paymentDelete).tap();
      await $.pumpAndSettle();
      expect($('Delete Payment?'), findsOneWidget);
      await $('Cancel').tap();
      await $.pumpAndSettle();
      await $(AppKeys.paymentDelete).scrollTo();
      await $(AppKeys.paymentDelete).tap();
      await $.pumpAndSettle();
      await $('Delete').tap();
      await $.pumpAndSettle();
      expect(await db.getPayment(id, now.year, now.month), isNull);
      expect($('Year ${now.year}'), findsOneWidget);
    },
  );

  patrolTest('full app reset clears data, preferences, and singleton defaults', (
    $,
  ) async {
    await pumpCollectionBook($);
    await $(AppKeys.homeSettings).tap();
    await $.pumpAndSettle();
    await $(AppKeys.settingsModeFiber).tap();
    await $.pumpAndSettle();
    expect($('Internet'), findsWidgets);

    await $(AppKeys.settingsAppLanguage).tap();
    await $.pumpAndSettle();
    await $(AppKeys.appLanguageHindi).tap();
    await $.pumpAndSettle();
    expect($('हिन्दी'), findsWidgets);
    await $(AppKeys.settingsBusinessName).tap();
    await $.pumpAndSettle();
    await $(AppKeys.receiptBusinessNameField).enterText('Patrol Cable');
    await $(AppKeys.receiptBusinessNameSave).tap();
    await $.pumpAndSettle();
    expect($('Patrol Cable'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            RegExp(r'^[A-Z0-9]{6}$').hasMatch(widget.data ?? ''),
      ),
      findsOneWidget,
    );
    final oldReferralCode = (await SharedPreferences.getInstance()).getString(
      'receipt_referral_code',
    );
    expect(oldReferralCode, isNotNull);

    await $(AppKeys.settingsAddArea).scrollTo();
    await $(AppKeys.settingsAddArea).tap();
    await $.pumpAndSettle();
    await $(AppKeys.areaNameField).enterText('North');
    await $(AppKeys.areaNameSave).tap();
    await $.pumpAndSettle();
    expect($(AppKeys.settingsAreaTile('North')), findsOneWidget);
    final db = DatabaseService();
    final north = (await db.getAreas()).singleWhere(
      (area) => area.name == 'North',
    );
    final areaSubscriberId = await db.insertSubscriber(
      Subscriber(
        areaId: north.id,
        name: 'Area Resident',
        vcNumber: 'VC-AREA',
        monthlyRent: 450,
        serviceType: 'tv',
        startYear: DateTime.now().year,
        startMonth: 1,
      ),
    );
    await $(AppKeys.settingsAreaDelete('North')).tap();
    await $.pumpAndSettle();
    expect($(_tr('delete_area')), findsOneWidget);
    expect($(_tr('delete_area_message', {'name': 'North'})), findsOneWidget);
    await $(_tr('cancel')).tap();
    await $.pumpAndSettle();
    await $(AppKeys.settingsAreaDelete('North')).tap();
    await $.pumpAndSettle();
    await $(_tr('delete')).tap();
    await $.pumpAndSettle();
    expect($(AppKeys.settingsAreaTile('North')), findsNothing);
    final unassigned = await db.getSubscriber(areaSubscriberId);
    expect(unassigned?.areaId, isNull);
    expect(unassigned?.areaName, isNull);

    await $(AppKeys.settingsBackup).scrollTo();
    await $(AppKeys.settingsBackup).tap();
    await $.pumpAndSettle();
    expect($(_tr('backup_created')), findsOneWidget);
    expect(
      find.textContaining(_tr('last_backup', {'date': ''})),
      findsOneWidget,
    );
    expect(await BackupService().listBackups(), hasLength(1));

    await $(AppKeys.settingsRestore).scrollTo();
    await $(AppKeys.settingsRestore).tap();
    await $.pumpAndSettle();
    expect($(_tr('restore_backup_title')), findsOneWidget);
    await $(_tr('cancel')).tap();
    await $.pumpAndSettle();

    await $.pumpWidget(const SizedBox.shrink());
    await pumpCollectionBook($);
    await $(AppKeys.homeSettings).tap();
    await $.pumpAndSettle();
    expect($('हिन्दी'), findsWidgets);
    expect($('Patrol Cable'), findsOneWidget);
    expect($(_tr('internet')), findsWidgets);

    await $(AppKeys.settingsReset).scrollTo();
    await $(AppKeys.settingsReset).tap();
    await $.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(_tr('reset_app')),
      ),
      findsOneWidget,
    );
    expect($(_tr('wait_seconds', {'seconds': 10})), findsOneWidget);
    await $.tester.pump(const Duration(seconds: 11));
    await $.pumpAndSettle();
    expect($(_tr('reset_everything')), findsOneWidget);
    await $(AppKeys.resetConfirm).tap();
    await $.pumpAndSettle();
    expect(
      $(
        'No Cable TV subscribers yet.\nAdd subscribers and assign them to areas.',
      ),
      findsOneWidget,
    );
    expect(await DatabaseService().getSubscribers(), isEmpty);
    expect(await DatabaseService().getAreas(), isEmpty);
    expect(
      (await SharedPreferences.getInstance()).getKeys(),
      isEmpty,
      reason: 'Reset must clear every app-owned SharedPreferences entry.',
    );
    expect($('TV'), findsOneWidget);
    expect(AppModeService().mode, ServiceMode.tv);
    expect(ReceiptSettingsService().language, ReceiptLanguage.english);
    expect(AppLanguageService.instance.languageCode, 'en');
    expect(
      ReceiptSettingsService().businessNameNotifier.value,
      ReceiptSettingsService.defaultBusinessName,
    );

    await $(AppKeys.homeSettings).tap();
    await $.pumpAndSettle();
    expect($('English'), findsOneWidget);
    expect($('Collection Book'), findsOneWidget);
    final newReferralCode = (await SharedPreferences.getInstance()).getString(
      'receipt_referral_code',
    );
    expect(newReferralCode, isNotNull);
    expect(newReferralCode, isNot(oldReferralCode));

    await $.pumpWidget(const SizedBox.shrink());
    await pumpCollectionBook($);
    expect($('TV'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'receipt_referral_code',
      ),
      newReferralCode,
    );
    await $(AppKeys.homeSettings).tap();
    await $.pumpAndSettle();
    expect($('English'), findsOneWidget);
    expect($('Collection Book'), findsOneWidget);
    expect(AppModeService().mode, ServiceMode.tv);
  });

  patrolTest(
    'subscriber deletion requires confirmation and removes ledger data',
    ($) async {
      await initializeCollectionBookForTest();
      final db = DatabaseService();
      final id = await db.insertSubscriber(
        Subscriber(
          name: 'Delete Me',
          vcNumber: 'VC-DELETE',
          monthlyRent: 500,
          serviceType: 'tv',
          startYear: DateTime.now().year,
          startMonth: 1,
        ),
      );
      await db.insertOrUpdatePayment(
        Payment(
          subscriberId: id,
          year: DateTime.now().year,
          month: DateTime.now().month,
          amountPaid: 500,
        ),
      );
      await $.pumpWidgetAndSettle(const CollectionBookApp());
      await $(AppKeys.homeSubscribers).tap();
      await $.pumpAndSettle();
      await $('Delete Me').tap();
      await $.pumpAndSettle();
      await $(AppKeys.subscriberDetailDelete).tap();
      await $.pumpAndSettle();
      expect($('Delete Subscriber?'), findsOneWidget);
      await $('Cancel').tap();
      await $.pumpAndSettle();
      expect($('Delete Me'), findsWidgets);
      await $(AppKeys.subscriberDetailDelete).tap();
      await $.pumpAndSettle();
      await $('Delete').tap();
      await $.pumpAndSettle();
      expect($('No subscribers match filters'), findsOneWidget);
      expect(await db.getSubscriber(id), isNull);
      expect(await db.getPaymentsForSubscriber(id), isEmpty);
    },
  );

  patrolTest('import history status stays localized in Hindi', ($) async {
    await initializeCollectionBookForTest();
    final db = DatabaseService();
    final runId = await db.insertImportRun(
      const ImportRun(
        fileName: 'localized-status.csv',
        serviceType: 'tv',
        status: 'partial',
        insertCount: 1,
        rejectCount: 1,
      ),
    );
    await db.insertImportErrors(runId, const [
      ImportRowError(rowNumber: 2, reason: 'Missing strong identifier'),
    ]);
    await $.pumpWidgetAndSettle(const CollectionBookApp());

    try {
      await $(AppKeys.homeSettings).tap();
      await $.pumpAndSettle();
      await $(AppKeys.settingsAppLanguage).tap();
      await $.pumpAndSettle();
      await $(AppKeys.appLanguageHindi).tap();
      await $.pumpAndSettle();

      await $(AppKeys.settingsImportHistory).scrollTo();
      await $(AppKeys.settingsImportHistory).tap();
      await $.pumpAndSettle();
      expect($('आयात इतिहास'), findsOneWidget);
      expect($('आंशिक'), findsOneWidget);
      expect($('PARTIAL'), findsNothing);
      await $(AppKeys.importHistoryRun(runId)).tap();
      await $.pumpAndSettle();
      expect($('आयात विवरण'), findsOneWidget);
      expect($('आंशिक'), findsOneWidget);
      expect($('PARTIAL'), findsNothing);

      await $(AppKeys.importRunDetailBack).tap();
      await $.pumpAndSettle();
      expect($('आयात इतिहास'), findsOneWidget);
      await $(AppKeys.importHistoryBack).tap();
      await $.pumpAndSettle();
      expect($('सेटिंग्स'), findsOneWidget);
      await $(AppKeys.settingsAppLanguage).scrollTo();
      await $(AppKeys.settingsAppLanguage).tap();
      await $.pumpAndSettle();
      await $(AppKeys.appLanguageEnglish).tap();
      await $.pumpAndSettle();
      expect(AppLanguageService.instance.languageCode, 'en');
    } finally {
      await AppLanguageService.instance.setLocale(
        AppLanguageService.englishLocale,
      );
    }
  });

  patrolTest(
    'import setup, persisted history, severity details, and error search are covered',
    ($) async {
      await initializeCollectionBookForTest();
      expect(AppLanguageService.instance.languageCode, 'en');
      final db = DatabaseService();
      final partialId = await db.insertImportRun(
        ImportRun(
          fileName: 'patrol-partial.csv',
          serviceType: 'tv',
          status: 'partial',
          insertCount: 3,
          updateCount: 1,
          rejectCount: 2,
          conflictCount: 1,
          paymentCount: 4,
        ),
      );
      await db.insertImportErrors(partialId, const [
        ImportRowError(
          rowNumber: 2,
          sourceColumn: 'vc_number',
          reason: 'VC number is required',
          severity: ImportSeverity.fatal,
        ),
        ImportRowError(
          rowNumber: 5,
          sourceColumn: 'monthly_rent',
          reason: 'Rent is not numeric',
          severity: ImportSeverity.error,
        ),
        ImportRowError(
          rowNumber: 8,
          sourceColumn: 'name',
          reason: 'Name was normalized',
          severity: ImportSeverity.warning,
        ),
      ]);
      await db.insertImportRun(
        const ImportRun(
          fileName: 'patrol-success.csv',
          serviceType: 'fiber',
          status: 'success',
          insertCount: 6,
          updateCount: 2,
        ),
      );
      await $.pumpWidgetAndSettle(const CollectionBookApp());
      await $(AppKeys.homeSettings).tap();
      await $.pumpAndSettle();

      await $(AppKeys.settingsImportHistory).scrollTo();
      await $(AppKeys.settingsImportHistory).tap();
      await $.pumpAndSettle();
      expect($(AppKeys.importHistoryEmpty), findsNothing);
      expect($('patrol-partial.csv'), findsOneWidget);
      expect($('Partial'), findsOneWidget);
      expect($('patrol-success.csv'), findsOneWidget);
      expect($('Success'), findsOneWidget);
      expect($('Rejected'), findsOneWidget);
      expect($('Conflicts'), findsOneWidget);
      await $(AppKeys.importHistoryRun(partialId)).tap();
      await $.pumpAndSettle();
      expect($('Error Rows (3)'), findsOneWidget);
      expect($('VC number is required'), findsOneWidget);
      expect($('Rent is not numeric'), findsOneWidget);
      expect($('Name was normalized'), findsOneWidget);
      await $(AppKeys.importErrorSearch).enterText('monthly_rent');
      await $.pumpAndSettle();
      expect($('Rent is not numeric'), findsOneWidget);
      expect($('VC number is required'), findsNothing);
      await $(AppKeys.importErrorSearch).enterText('unknown');
      await $.pumpAndSettle();
      expect($('No matching errors.'), findsOneWidget);
      await $(find.byTooltip('Back')).tap();
      await $.pumpAndSettle();
      await $(find.byTooltip('Back')).tap();
      await $.pumpAndSettle();

      await $(AppKeys.settingsImportTv).scrollTo();
      await $(AppKeys.settingsImportTv).tap();
      await $.pumpAndSettle();
      expect($('Import Cable TV Subscribers'), findsOneWidget);
      expect($(AppKeys.importTv), findsOneWidget);
      expect(
        $.tester
            .widget<FilledButton>(find.byKey(AppKeys.importContinue))
            .onPressed,
        isNull,
      );
      await $(AppKeys.importStartMonth).tap();
      await $(_longMonth(DateTime.now().month)).tap();
      await $(AppKeys.importStartYear).tap();
      await $('${DateTime.now().year}').tap();
      await $.pumpAndSettle();
      await $(AppKeys.importContinue).scrollTo();
      await $(AppKeys.importContinue).tap();
      await $.pumpAndSettle();
      expect($(AppKeys.importPickFile), findsOneWidget);
      await $(find.byTooltip('Back')).tap();
      await $.pumpAndSettle();

      await $(AppKeys.settingsImportFiber).scrollTo();
      await $(AppKeys.settingsImportFiber).tap();
      await $.pumpAndSettle();
      expect($('Import Internet Subscribers'), findsOneWidget);
      expect($(AppKeys.importFiber), findsOneWidget);
      await $(AppKeys.importStartMonth).tap();
      await $(_longMonth(DateTime.now().month)).tap();
      await $(AppKeys.importStartYear).tap();
      await $('${DateTime.now().year}').tap();
      await $.pumpAndSettle();
      await $(AppKeys.importContinue).scrollTo();
      await $(AppKeys.importContinue).tap();
      await $.pumpAndSettle();
      expect($(AppKeys.importPickFile), findsOneWidget);
      await $(find.byTooltip('Back')).tap();
      await $.pumpAndSettle();
      expect($('Import TV Subscribers'), findsOneWidget);
      expect($('Import Internet Subscribers'), findsOneWidget);
    },
  );

  patrolTest(
    'Save & Send validates a missing receipt phone without launching an external app',
    ($) async {
      await initializeCollectionBookForTest();
      final db = DatabaseService();
      final id = await db.insertSubscriber(
        Subscriber(
          name: 'No Phone Customer',
          vcNumber: 'VC-NO-PHONE',
          monthlyRent: 400,
          serviceType: 'tv',
          startYear: DateTime.now().year,
          startMonth: DateTime.now().month,
        ),
      );
      await $.pumpWidgetAndSettle(const CollectionBookApp());
      await $(AppKeys.homeRecordPayment).tap();
      await $.pumpAndSettle();
      await $(AppKeys.paymentSubscriber).tap();
      await $('No Phone Customer').tap();
      await $.pumpAndSettle();
      await $(AppKeys.paymentSaveAndSend).scrollTo();
      await $(AppKeys.paymentSaveAndSend).tap();
      await $.pumpAndSettle();
      expect(
        $(
          'Payment saved, but receipt was not sent. Add a valid WhatsApp phone '
          'number to this subscriber, then use Send Receipt on the payment.',
        ),
        findsOneWidget,
      );
      final payment = await db.getPayment(
        id,
        DateTime.now().year,
        DateTime.now().month,
      );
      expect(payment?.amountPaid, 400);
    },
  );

  patrolTest(
    'all five app languages render Settings, Import Wizard, Home, and Subscribers',
    ($) async {
      await initializeCollectionBookForTest();
      expect(AppLanguageService.instance.languageCode, 'en');
      await $.pumpWidgetAndSettle(const CollectionBookApp());

      // Captured while the app is still English so every regional locale can be
      // proven to translate these keys instead of silently returning English.
      final englishCopy = <String, String>{
        for (final key in _localizedProbeKeys) key: _tr(key),
      };

      try {
        for (final language in _patrolAppLanguages) {
          // Home -> Settings through the production control.
          await $(AppKeys.homeSettings).tap();
          await $.pumpAndSettle();
          expect($(_tr('settings')), findsOneWidget);

          // Production language selector dialog.
          await _revealSetting($, AppKeys.settingsAppLanguage);
          expect($(_tr('app_language')), findsOneWidget);
          await $(AppKeys.settingsAppLanguage).tap();
          await $.pumpAndSettle();
          expect($(_tr('choose_language')), findsOneWidget);
          await $(language.option).tap();
          await $.pumpAndSettle();
          // Material ignores a tap on the already-selected radio, so the
          // selector only stays open when the language did not change. Close
          // it with the platform Back so the cycle stays deterministic.
          if (find.byKey(language.option).evaluate().isNotEmpty) {
            await $.tester.pageBack();
            await $.pumpAndSettle();
          }
          expect(find.byKey(AppKeys.appLanguageEnglish), findsNothing);

          expect(AppLanguageService.instance.languageCode, language.code);
          for (final probe in englishCopy.entries) {
            if (language.code == 'en') {
              expect(
                _tr(probe.key),
                probe.value,
                reason:
                    'English must keep its own catalog value for '
                    '${probe.key}.',
              );
            } else {
              expect(
                _tr(probe.key),
                isNot(probe.value),
                reason:
                    '${language.code} must translate ${probe.key} instead of '
                    'silently falling back to the English value.',
              );
            }
          }
          expect($(_tr('settings')), findsOneWidget);
          expect($(_tr('app_language')), findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(AppKeys.settingsAppLanguage),
              matching: find.text(
                AppLanguageService.languageNames[language.code]!,
              ),
            ),
            findsOneWidget,
          );

          // Lower, scrolling Settings surfaces. The Settings body is a lazily
          // mounted `ListView`, so each lower tile is revealed before its own
          // copy is asserted. Section headers sit just above their first tile
          // and can stay unmounted, so only tile-owned copy is asserted.
          await _revealSetting($, AppKeys.settingsReset);
          expect(
            find.descendant(
              of: find.byKey(AppKeys.settingsReset),
              matching: find.text(_tr('reset_app')),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(AppKeys.settingsReset),
              matching: find.text(_tr('reset_app_description')),
            ),
            findsOneWidget,
          );

          await _revealSetting($, AppKeys.settingsImportHistory);
          expect(
            find.descendant(
              of: find.byKey(AppKeys.settingsImportHistory),
              matching: find.text(_tr('import_history')),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(AppKeys.settingsImportHistory),
              matching: find.text(_tr('import_history_description')),
            ),
            findsOneWidget,
          );

          // TV import wizard opened from the production Settings tile.
          await _revealSetting($, AppKeys.settingsImportTv);
          expect(
            find.descendant(
              of: find.byKey(AppKeys.settingsImportTv),
              matching: find.text(_tr('import_tv_subscribers')),
            ),
            findsOneWidget,
          );
          await $.pumpAndSettle();
          _expectNoLayoutException($, language.code, 'Settings lower surfaces');
          await $(AppKeys.settingsImportTv).tap();
          await $.pumpAndSettle();
          expect(
            $(_tr('import_subscribers_title', {'service': _tr('cable_tv')})),
            findsOneWidget,
          );
          expect($(_tr('import_subscribers')), findsOneWidget);
          expect($(_tr('import_service_help')), findsOneWidget);
          expect($(_tr('cable_tv')), findsOneWidget);
          expect($(_tr('import_tv_option')), findsOneWidget);
          expect($(_tr('step_service')), findsOneWidget);
          expect($(_tr('step_file')), findsOneWidget);
          expect($(AppKeys.importTv), findsOneWidget);
          expect(
            $.tester
                .widget<FilledButton>(find.byKey(AppKeys.importContinue))
                .onPressed,
            isNull,
          );
          await $.pumpAndSettle();
          _expectNoLayoutException($, language.code, 'TV Import Wizard');
          await $(AppKeys.importBack).tap();
          await $.pumpAndSettle();
          expect($(_tr('settings')), findsOneWidget);

          // Settings -> Home. The dues hero card header is asserted because it
          // is the narrowest production surface and previously overflowed on
          // long vernacular labels at this device width.
          await $(find.byType(BackButton)).tap();
          await $.pumpAndSettle();
          expect($(_tr('app_name')), findsOneWidget);
          expect($(_tr('record_payment')), findsOneWidget);
          expect($(_tr('outstanding_dues')), findsOneWidget);
          expect($(_tr('subscribers_count', {'count': 0})), findsOneWidget);
          expect($(find.byTooltip(_tr('all_subscribers'))), findsOneWidget);
          expect($(find.byTooltip(_tr('settings'))), findsOneWidget);
          await $.pumpAndSettle();
          _expectNoLayoutException($, language.code, 'Home');

          // Home -> Subscribers -> Home.
          await $(AppKeys.homeSubscribers).tap();
          await $.pumpAndSettle();
          expect($(_tr('subscribers')), findsOneWidget);
          expect($(_tr('no_subscribers_match')), findsOneWidget);
          await $.pumpAndSettle();
          _expectNoLayoutException($, language.code, 'Subscriber List');
          await $(find.byType(BackButton)).tap();
          await $.pumpAndSettle();
          expect($(_tr('app_name')), findsOneWidget);
        }

        // Leave the device on English through the production selector.
        await $(AppKeys.homeSettings).tap();
        await $.pumpAndSettle();
        await _revealSetting($, AppKeys.settingsAppLanguage);
        await $(AppKeys.settingsAppLanguage).tap();
        await $.pumpAndSettle();
        await $(AppKeys.appLanguageEnglish).tap();
        await $.pumpAndSettle();
        expect(AppLanguageService.instance.languageCode, 'en');
        expect(find.byKey(AppKeys.appLanguageEnglish), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(AppKeys.settingsAppLanguage),
            matching: find.text('English'),
          ),
          findsOneWidget,
        );
      } finally {
        await AppLanguageService.instance.setLocale(
          AppLanguageService.englishLocale,
        );
      }
    },
  );
}

/// Fails the journey when a settled localized surface left a pending Flutter or
/// rendering exception behind, such as a `RenderFlex` overflow. Exactly one
/// exception is taken per call and asserted, so a real overflow surfaces with
/// its locale and surface instead of being drained and hidden.
void _expectNoLayoutException(
  PatrolIntegrationTester $,
  String languageCode,
  String surface,
) {
  expect(
    $.tester.takeException(),
    isNull,
    reason:
        'A Flutter or layout exception was raised while rendering $surface '
        'in language $languageCode.',
  );
}

/// Scrolls the lazily mounted Settings list down to [key] and aligns it fully
/// in view. The Settings body is a `ListView`, so tiles far outside the
/// viewport are not mounted and cannot be scrolled to directly; this walks the
/// scroll position in half-viewport steps from the top instead.
Future<void> _revealSetting(PatrolIntegrationTester $, Key key) async {
  final listView = find.byType(ListView);
  expect(listView, findsOneWidget);
  final position = $.tester
      .state<ScrollableState>(
        find.descendant(of: listView, matching: find.byType(Scrollable)),
      )
      .position;
  position.jumpTo(0);
  await $.pumpAndSettle();

  final finder = find.byKey(key);
  while (finder.evaluate().isEmpty) {
    final next = (position.pixels + position.viewportDimension * 0.5)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    expect(
      next,
      greaterThan(position.pixels),
      reason: 'Could not scroll the Settings list to $key.',
    );
    position.jumpTo(next);
    await $.pumpAndSettle();
  }
  await $.tester.ensureVisible(finder);
  await $.pumpAndSettle();
}

const List<String> _localizedProbeKeys = [
  'app_name',
  'subscribers',
  'settings',
  'outstanding_dues',
];

/// One production language-selector target for the five-language journey.
class _PatrolAppLanguage {
  const _PatrolAppLanguage({required this.code, required this.option});

  final String code;
  final Key option;
}

const List<_PatrolAppLanguage> _patrolAppLanguages = [
  _PatrolAppLanguage(code: 'en', option: AppKeys.appLanguageEnglish),
  _PatrolAppLanguage(code: 'hi', option: AppKeys.appLanguageHindi),
  _PatrolAppLanguage(code: 'mr', option: AppKeys.appLanguageMarathi),
  _PatrolAppLanguage(code: 'bn', option: AppKeys.appLanguageBengali),
  _PatrolAppLanguage(code: 'ta', option: AppKeys.appLanguageTamil),
];

Future<_FilterSeedIds> _seedDashboardSubscribers(DatabaseService db) async {
  final now = DateTime.now();
  final northId = await db.insertArea(const Area(name: 'North'));
  final southId = await db.insertArea(const Area(name: 'South'));
  await db.insertSubscriber(
    Subscriber(
      areaId: northId,
      name: 'Alpha Subscriber',
      vcNumber: 'VC-DASH-A',
      monthlyRent: 700,
      serviceType: 'tv',
      startYear: now.year,
      startMonth: 1,
    ),
  );
  final bravoId = await db.insertSubscriber(
    Subscriber(
      areaId: northId,
      name: 'Bravo Subscriber',
      vcNumber: 'VC-DASH-B',
      monthlyRent: 900,
      serviceType: 'tv',
      startYear: now.year,
      startMonth: 1,
    ),
  );
  final charlieId = await db.insertSubscriber(
    Subscriber(
      areaId: southId,
      name: 'Charlie Advance',
      vcNumber: 'VC-DASH-C',
      monthlyRent: 800,
      serviceType: 'tv',
      startYear: now.year,
      startMonth: 1,
    ),
  );
  await db.insertOrUpdatePayment(
    Payment(
      subscriberId: bravoId,
      year: now.year,
      month: now.month,
      amountPaid: now.month * 900,
    ),
  );
  await db.insertOrUpdatePayment(
    Payment(
      subscriberId: charlieId,
      year: now.year,
      month: now.month,
      amountPaid: now.month * 800 + 250,
    ),
  );
  return _FilterSeedIds(northId: northId, southId: southId);
}

class _FilterSeedIds {
  const _FilterSeedIds({required this.northId, required this.southId});

  final int northId;
  final int southId;
}

Future<_FilterSeedIds> _seedFilterSubscribers(DatabaseService db) async {
  final now = DateTime.now();
  final northId = await db.insertArea(const Area(name: 'North'));
  final southId = await db.insertArea(const Area(name: 'South'));
  final alphaId = await db.insertSubscriber(
    Subscriber(
      areaId: northId,
      name: 'Alpha Subscriber',
      aliasName: 'Asha Home',
      vcNumber: 'VC-1001',
      monthlyRent: 700,
      serviceType: 'tv',
      startYear: now.year,
      startMonth: 1,
    ),
  );
  final bravoId = await db.insertSubscriber(
    Subscriber(
      areaId: northId,
      name: 'Bravo Subscriber',
      aliasName: 'Bravo Home',
      vcNumber: 'VC-2002',
      monthlyRent: 900,
      serviceType: 'tv',
      startYear: now.year,
      startMonth: 1,
    ),
  );
  final charlieId = await db.insertSubscriber(
    Subscriber(
      areaId: southId,
      name: 'Charlie Advance',
      aliasName: 'Charlie Home',
      vcNumber: 'VC-3003',
      monthlyRent: 800,
      serviceType: 'tv',
      startYear: now.year,
      startMonth: 1,
    ),
  );
  await db.insertSubscriber(
    Subscriber(
      areaId: northId,
      name: 'Delta Inactive',
      aliasName: 'Delta Home',
      vcNumber: 'VC-4004',
      monthlyRent: 500,
      isActive: false,
      serviceType: 'tv',
      startYear: now.year,
      startMonth: 1,
    ),
  );
  await db.insertOrUpdatePayment(
    Payment(
      subscriberId: alphaId,
      year: now.year,
      month: now.month,
      amountPaid: now.month * 700,
    ),
  );
  await db.insertOrUpdatePayment(
    Payment(
      subscriberId: bravoId,
      year: now.year,
      month: now.month,
      amountPaid: now.month * 900,
    ),
  );
  await db.insertOrUpdatePayment(
    Payment(
      subscriberId: charlieId,
      year: now.year,
      month: now.month,
      amountPaid: now.month * 800 + 250,
    ),
  );
  return _FilterSeedIds(northId: northId, southId: southId);
}

Color _primaryColor(PatrolIntegrationTester tester) {
  return tester.tester
      .widget<MaterialApp>(find.byType(MaterialApp))
      .theme!
      .colorScheme
      .primary;
}

Future<void> _expectVerticalOrder(
  PatrolIntegrationTester tester,
  List<String> labels,
) async {
  final listView = find.byType(ListView).last;
  expect(listView, findsOneWidget);
  final scrollableFinder = find.descendant(
    of: listView,
    matching: find.byType(Scrollable),
  );
  expect(scrollableFinder, findsOneWidget);
  final scrollable = tester.tester.state<ScrollableState>(scrollableFinder);
  final position = scrollable.position;
  position.jumpTo(0);
  await tester.pumpAndSettle();

  final contentTops = <String, double>{};
  while (contentTops.length < labels.length) {
    final listTop = tester.tester.getTopLeft(listView).dy;
    for (final label in labels) {
      final labelFinder = find.text(label);
      if (labelFinder.evaluate().isNotEmpty) {
        final localTop =
            tester.tester.getTopLeft(labelFinder.last).dy - listTop;
        contentTops[label] = position.pixels + localTop;
      }
    }
    if (contentTops.length == labels.length) break;

    final nextOffset = (position.pixels + position.viewportDimension * 0.6)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    expect(
      nextOffset,
      greaterThan(position.pixels),
      reason:
          'Could not build every expected row before reaching the list end: '
          '${contentTops.keys.toList()}',
    );
    position.jumpTo(nextOffset);
    await tester.pumpAndSettle();
  }

  for (var i = 1; i < labels.length; i++) {
    expect(
      contentTops[labels[i]]!,
      greaterThan(contentTops[labels[i - 1]]!),
      reason: '${labels[i - 1]} should appear above ${labels[i]}',
    );
  }
}

String _tr(String key, [Map<String, Object?> args = const {}]) {
  return AppLanguageService.instance.tr(key, args);
}

String _textFieldValue(PatrolIntegrationTester tester, Key key) {
  return tester.tester.widget<TextFormField>(find.byKey(key)).controller!.text;
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
