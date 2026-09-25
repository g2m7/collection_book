import 'package:flutter/widgets.dart';

/// Stable selectors for interactions shared by the app and Patrol journeys.
///
/// Keep these values independent from user-visible labels so copy changes do
/// not break end-to-end tests.
abstract final class AppKeys {
  static const homeModeToggle = Key('home-mode-toggle');
  static const homePreviousMonth = Key('home-previous-month');
  static const homeMonthLabel = Key('home-month-label');
  static const homeNextMonth = Key('home-next-month');
  static const homeSubscribers = Key('home-subscribers');
  static const homeSettings = Key('home-settings');
  static const homeRecordPayment = Key('home-record-payment');
  static Key homeAreaCard(int areaId) => Key('home-area-card-$areaId');

  static const subscriberListAdd = Key('subscriber-list-add');
  static const subscriberListSearch = Key('subscriber-list-search');
  static const subscriberListClearSearch = Key('subscriber-list-clear-search');
  static const subscriberListFilters = Key('subscriber-list-filters');
  static const subscriberListFab = Key('subscriber-list-fab');
  static const subscriberFilterAll = Key('subscriber-filter-all');
  static const subscriberFilterUnpaid = Key('subscriber-filter-unpaid');
  static const subscriberFilterPaid = Key('subscriber-filter-paid');
  static const subscriberFilterOverpaid = Key('subscriber-filter-overpaid');
  static const subscriberStatusActive = Key('subscriber-status-active');
  static const subscriberStatusInactive = Key('subscriber-status-inactive');
  static Key subscriberAreaFilter(int? areaId) => Key(
    areaId == null
        ? 'subscriber-area-filter-all'
        : 'subscriber-area-filter-$areaId',
  );
  static const subscriberSortNameAsc = Key('subscriber-sort-name-asc');
  static const subscriberSortNameDsc = Key('subscriber-sort-name-dsc');
  static const subscriberSortDueHigh = Key('subscriber-sort-due-high');
  static const subscriberSortDueLow = Key('subscriber-sort-due-low');
  static const subscriberSortRentHigh = Key('subscriber-sort-rent-high');
  static const subscriberSortRentLow = Key('subscriber-sort-rent-low');
  static const subscriberListClearFilters = Key(
    'subscriber-list-clear-filters',
  );

  static final subscriberForm = GlobalKey<FormState>(
    debugLabel: 'subscriber-form',
  );
  static const subscriberName = Key('subscriber-name');
  static const subscriberAlias = Key('subscriber-alias');
  static const subscriberIdentifier = Key('subscriber-identifier');
  static const subscriberUsername = Key('subscriber-username');
  static const subscriberPhone = Key('subscriber-phone');
  static const subscriberRent = Key('subscriber-rent');
  static const subscriberPreviousDue = Key('subscriber-previous-due');
  static const subscriberSave = Key('subscriber-save');
  static const subscriberServiceTv = Key('subscriber-service-tv');
  static const subscriberServiceFiber = Key('subscriber-service-fiber');
  static const subscriberArea = Key('subscriber-area');
  static const subscriberStartMonth = Key('subscriber-start-month');
  static const subscriberStartYear = Key('subscriber-start-year');
  static const subscriberActive = Key('subscriber-active');

  static const subscriberDetailEdit = Key('subscriber-detail-edit');
  static const subscriberDetailDelete = Key('subscriber-detail-delete');
  static const subscriberDetailRecordPayment = Key(
    'subscriber-detail-record-payment',
  );
  static const subscriberDetailSendReceipt = Key(
    'subscriber-detail-send-receipt',
  );
  static const subscriberDetailYearPrevious = Key(
    'subscriber-detail-year-previous',
  );
  static const subscriberDetailYearNext = Key('subscriber-detail-year-next');
  static Key subscriberDetailMonth(int month, int year) =>
      Key('subscriber-detail-month-$year-$month');

  static const paymentSubscriber = Key('payment-subscriber');
  static const paymentAmount = Key('payment-amount');
  static const paymentAdjustment = Key('payment-adjustment');
  static const paymentNote = Key('payment-note');
  static const paymentSave = Key('payment-save');
  static const paymentSaveAndSend = Key('payment-save-and-send');
  static const paymentClearDue = Key('payment-clear-due');
  static const paymentMonth = Key('payment-month');
  static const paymentYear = Key('payment-year');
  static const paymentDelete = Key('payment-delete');
  static const paymentClearDueApply = Key('payment-clear-due-apply');
  static const paymentClearDueApplyNote = Key('payment-clear-due-apply-note');

  static const settingsModeTv = Key('settings-mode-tv');
  static const settingsModeFiber = Key('settings-mode-fiber');
  static const settingsAppLanguage = Key('settings-app-language');
  static const settingsReceiptLanguage = Key('settings-receipt-language');
  static const settingsBusinessName = Key('settings-business-name');
  static const settingsImportTv = Key('settings-import-tv');
  static const settingsImportFiber = Key('settings-import-fiber');
  static const settingsImportHistory = Key('settings-import-history');
  static const settingsBackup = Key('settings-backup');
  static const settingsShareBackup = Key('settings-share-backup');
  static const settingsRestore = Key('settings-restore');
  static const settingsAddArea = Key('settings-add-area');
  static const settingsReset = Key('settings-reset');
  static const areaNameField = Key('area-name-field');
  static const areaNameSave = Key('area-name-save');
  static Key settingsAreaTile(String name) => Key('settings-area-$name');
  static Key settingsAreaDelete(String name) =>
      Key('settings-area-delete-$name');
  static const resetConfirm = Key('reset-confirm');

  static const appLanguageEnglish = Key('app-language-english');
  static const appLanguageHindi = Key('app-language-hindi');
  static const appLanguageMarathi = Key('app-language-marathi');
  static const appLanguageBengali = Key('app-language-bengali');
  static const appLanguageTamil = Key('app-language-tamil');
  static const receiptLanguageEnglish = Key('receipt-language-english');
  static const receiptLanguageHindi = Key('receipt-language-hindi');
  static const receiptLanguageMarathi = Key('receipt-language-marathi');
  static const receiptLanguageBengali = Key('receipt-language-bengali');
  static const receiptLanguageTamil = Key('receipt-language-tamil');
  static const receiptBusinessNameField = Key('receipt-business-name-field');
  static const receiptBusinessNameSave = Key('receipt-business-name-save');

  static const importTv = Key('import-tv');
  static const importFiber = Key('import-fiber');
  static const importStartMonth = Key('import-start-month');
  static const importStartYear = Key('import-start-year');
  static const importContinue = Key('import-continue');
  static const importPickFile = Key('import-pick-file');
  static const importBack = Key('import-back');
  static const importHistoryEmpty = Key('import-history-empty');
  static const importHistoryBack = Key('import-history-back');
  static Key importHistoryRun(int runId) => Key('import-history-run-$runId');
  static const importRunDetailBack = Key('import-run-detail-back');
  static const importErrorSearch = Key('import-error-search');
}
