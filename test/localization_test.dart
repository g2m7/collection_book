import 'package:collection_book/models/payment.dart';
import 'package:collection_book/models/subscriber.dart';
import 'package:collection_book/services/app_language_service.dart';
import 'package:collection_book/services/receipt_settings_service.dart';
import 'package:collection_book/services/whatsapp_receipt_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppLanguageService.instance.resetInMemoryForTesting();
    await AppLanguageService.instance.init();
  });

  tearDown(() {
    AppLanguageService.instance.resetInMemoryForTesting();
  });

  test('all five catalogs have exact key parity', () async {
    final service = AppLanguageService.instance;
    final catalogs = service.catalogsForTesting;
    final englishKeys = catalogs['en']!.keys.toSet();

    expect(catalogs.keys, containsAll(['en', 'hi', 'mr', 'bn', 'ta']));
    for (final language in ['en', 'hi', 'mr', 'bn', 'ta']) {
      expect(
        catalogs[language]!.keys.toSet(),
        englishKeys,
        reason: '$language catalog keys must match en.json exactly',
      );
    }
  });

  test('all catalogs preserve English interpolation tokens', () async {
    final catalogs = AppLanguageService.instance.catalogsForTesting;
    final tokenPattern = RegExp(r'\{(\w+)\}');

    for (final entry in catalogs.entries) {
      for (final message in catalogs['en']!.entries) {
        final expected = tokenPattern
            .allMatches(message.value)
            .map((match) => match.group(0))
            .toSet();
        final actual = tokenPattern
            .allMatches(entry.value[message.key]!)
            .map((match) => match.group(0))
            .toSet();
        expect(
          actual,
          expected,
          reason: '${entry.key}:${message.key} interpolation tokens differ',
        );
      }
    }
  });

  test(
    'interpolates translated values and falls back to English by key',
    () async {
      final service = AppLanguageService.instance;
      await service.setLocale(const Locale('hi'));

      expect(
        service.tr('payment_recorded_for', {'name': 'राम'}),
        'राम का भुगतान दर्ज हुआ',
      );
      expect(service.trFor(const Locale('ta'), 'name'), 'பெயர்');

      // A key absent from a regional catalog deterministically uses English.
      await service.setLocale(const Locale('mr'));
      final english = service.catalogsForTesting['en']!;
      final regional = service.catalogsForTesting['mr']!;
      final translatedName = regional.remove('name');
      expect(service.tr('name'), 'Name');
      regional['name'] = translatedName!;
      expect(
        service.interpolate(english['payment_recorded_for']!, {'name': 'Asha'}),
        'Payment recorded for Asha',
      );
    },
  );

  test(
    'localizes import statuses, fields, sources, and dry-run labels',
    () async {
      final service = AppLanguageService.instance;
      await service.setLocale(const Locale('hi'));

      expect(service.importStatus('success'), 'सफल');
      expect(service.importStatus('partial'), 'आंशिक');
      expect(service.importStatus('failed'), 'विफल');
      expect(service.importField('subscriber_name'), 'नाम');
      expect(service.importField('monthly_amount'), 'मासिक किराया');
      expect(service.importField('subscriber identifier'), 'ग्राहक पहचान');
      expect(
        service.importSourceColumn('vc_number (auto-detected)'),
        'vc_number (स्वतः पहचाना गया)',
      );
      expect(service.tr('new_subscribers'), 'नए ग्राहक');
      expect(service.tr('updates'), 'अपडेट');
    },
  );

  group('first-start preference restoration', () {
    test('cold start restores a supported app language', () async {
      SharedPreferences.setMockInitialValues({
        AppLanguageService.preferenceKey: 'mr',
      });
      final service = AppLanguageService.instance..resetInMemoryForTesting();

      await service.init();

      expect(service.languageCode, 'mr');
    });

    test(
      'invalid explicit app language wins and falls back without replacement',
      () async {
        SharedPreferences.setMockInitialValues({
          AppLanguageService.preferenceKey: 'unsupported',
          'receipt_language': 'tamil',
        });
        final service = AppLanguageService.instance..resetInMemoryForTesting();

        await service.init();

        expect(service.languageCode, 'en');
        final preferences = await SharedPreferences.getInstance();
        expect(
          preferences.getString(AppLanguageService.preferenceKey),
          'unsupported',
        );
        expect(preferences.getString('receipt_language'), 'tamil');
      },
    );

    test(
      'cold start falls back without persisting invalid legacy data',
      () async {
        SharedPreferences.setMockInitialValues({'receipt_language': 'klingon'});
        final service = AppLanguageService.instance..resetInMemoryForTesting();

        await service.init();

        expect(service.languageCode, 'en');
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getString(AppLanguageService.preferenceKey), isNull);
        expect(preferences.getString('receipt_language'), 'klingon');
      },
    );

    test('cold start migrates every valid legacy receipt language', () async {
      const legacyLanguages = <String, String>{
        'english': 'en',
        'hindi': 'hi',
        'marathi': 'mr',
        'bengali': 'bn',
        'tamil': 'ta',
      };

      for (final entry in legacyLanguages.entries) {
        SharedPreferences.setMockInitialValues({'receipt_language': entry.key});
        final service = AppLanguageService.instance..resetInMemoryForTesting();

        await service.init();

        expect(service.languageCode, entry.value);
        final preferences = await SharedPreferences.getInstance();
        expect(
          preferences.getString(AppLanguageService.preferenceKey),
          entry.value,
        );
        expect(preferences.getString('receipt_language'), entry.key);
      }
    });

    test('explicit app language takes precedence over legacy value', () async {
      SharedPreferences.setMockInitialValues({
        AppLanguageService.preferenceKey: 'bn',
        'receipt_language': 'marathi',
      });
      final service = AppLanguageService.instance..resetInMemoryForTesting();

      await service.init();

      expect(service.languageCode, 'bn');
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(AppLanguageService.preferenceKey), 'bn');
      expect(preferences.getString('receipt_language'), 'marathi');
    });

    test('receipt settings initialize independently after migration', () async {
      SharedPreferences.setMockInitialValues({'receipt_language': 'marathi'});
      final service = AppLanguageService.instance..resetInMemoryForTesting();
      final receiptSettings = ReceiptSettingsService()..resetToDefaults();

      await service.init();
      await receiptSettings.init();

      expect(service.languageCode, 'mr');
      expect(receiptSettings.language, ReceiptLanguage.marathi);
    });
  });

  test('each selected app language feeds the receipt template path', () async {
    final service = AppLanguageService.instance;
    final expected = <String, (ReceiptLanguage, String)>{
      'en': (ReceiptLanguage.english, '*PAYMENT RECEIPT'),
      'hi': (ReceiptLanguage.hindi, '*भुगतान रसीद'),
      'mr': (ReceiptLanguage.marathi, '*पावती'),
      'bn': (ReceiptLanguage.bengali, '*পেমেন্ট রসিদ'),
      'ta': (ReceiptLanguage.tamil, '*ரசீது'),
    };
    final subscriber = Subscriber(
      id: 1,
      name: 'Localized Customer',
      monthlyRent: 350,
      serviceType: 'tv',
      vcNumber: 'VC-LOCALIZED',
    );
    final payment = Payment(
      subscriberId: 1,
      year: 2026,
      month: 9,
      amountPaid: 350,
    );

    for (final entry in expected.entries) {
      await service.setLocale(Locale(entry.key));

      expect(service.receiptLanguage, entry.value.$1);
      final receipt = WhatsAppReceiptService.buildReceiptText(
        organizationName: 'Ramesh Cable Network',
        subscriber: subscriber,
        payment: payment,
        balanceAfterPayment: 0,
        language: service.receiptLanguage,
        referralCode: 'AB12CD',
      );
      expect(receipt, contains(entry.value.$2));
    }
  });
}
