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

  static const paymentSubscriber = Key('payment-subscriber');
  static const paymentAmount = Key('payment-amount');
  static const paymentAdjustment = Key('payment-adjustment');
  static const paymentNote = Key('payment-note');
  static const paymentSave = Key('payment-save');
  static const paymentSaveAndSend = Key('payment-save-and-send');
  static const paymentClearDue = Key('payment-clear-due');

  static const settingsModeTv = Key('settings-mode-tv');
  static const settingsModeFiber = Key('settings-mode-fiber');
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
}
