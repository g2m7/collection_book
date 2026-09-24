import 'package:collection_book/models/payment.dart';
import 'package:collection_book/models/subscriber.dart';
import 'package:collection_book/services/receipt_settings_service.dart';
import 'package:collection_book/services/whatsapp_receipt_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Indian phone normalization', () {
    test('normalizes supported Indian mobile formats', () {
      expect(
        WhatsAppReceiptService.normalizeIndianPhone('9876543210'),
        '+919876543210',
      );
      expect(
        WhatsAppReceiptService.normalizeIndianPhone('+91 98765 43210'),
        '+919876543210',
      );
      expect(
        WhatsAppReceiptService.normalizeIndianPhone('09876543210'),
        '+919876543210',
      );
      expect(
        WhatsAppReceiptService.normalizeIndianPhone('91-98765-43210'),
        '+919876543210',
      );
    });

    test('rejects missing, malformed, and non-mobile numbers', () {
      for (final value in <String?>[
        null,
        '',
        '1234567890',
        '98765',
        '+1 98765 43210',
        '98765 4321a',
      ]) {
        expect(
          WhatsAppReceiptService.normalizeIndianPhone(value),
          isNull,
          reason: 'Expected $value to be rejected',
        );
      }
    });
  });

  group('Receipt URI and referral construction', () {
    test('builds encoded app and web WhatsApp URIs', () {
      const phone = '+919876543210';
      const message = 'Payment ₹350 & thanks\nलाइन';

      final appUri = WhatsAppReceiptService.buildAppUri(
        phone.substring(1),
        message,
      );
      final webUri = WhatsAppReceiptService.buildWebUri(
        phone.substring(1),
        message,
      );

      expect(appUri.scheme, 'whatsapp');
      expect(appUri.host, 'send');
      expect(appUri.queryParameters['phone'], '919876543210');
      expect(appUri.queryParameters['text'], message);
      expect(appUri.toString(), contains('text=Payment%20%E2%82%B9350'));
      expect(webUri.toString(), contains('text=Payment%20%E2%82%B9350'));
      expect(webUri.scheme, 'https');
      expect(webUri.host, 'wa.me');
      expect(webUri.path, '/919876543210');
      expect(webUri.queryParameters['text'], message);
    });

    test('uses the canonical referral URL', () {
      expect(
        WhatsAppReceiptService.buildReferralUrl('AB12CD'),
        'https://cbk.sarbaa.com/r/AB12CD',
      );
      expect(
        () => WhatsAppReceiptService.buildReferralUrl('../bad'),
        throwsArgumentError,
      );
    });
  });

  group('Balance states', () {
    test('identifies fully paid, arrears, and advance', () {
      final paid = WhatsAppReceiptService.calculateBalance(
        0,
        ReceiptLanguage.english,
      );
      final arrears = WhatsAppReceiptService.calculateBalance(
        150.4,
        ReceiptLanguage.english,
      );
      final advance = WhatsAppReceiptService.calculateBalance(
        -150.4,
        ReceiptLanguage.english,
      );

      expect(paid.status, ReceiptBalanceStatus.fullyPaid);
      expect(paid.label, 'FULLY PAID');
      expect(paid.remainingDue, 0);
      expect(arrears.status, ReceiptBalanceStatus.arrears);
      expect(arrears.label, 'PARTIAL (DUE)');
      expect(arrears.remainingDue, 150.4);
      expect(advance.status, ReceiptBalanceStatus.advance);
      expect(advance.label, 'ADVANCE ₹150');
      expect(advance.remainingDue, 0);
    });
  });

  group('Five-language receipt templates', () {
    final expectations = <ReceiptLanguage, String>{
      ReceiptLanguage.english: '*PAYMENT RECEIPT',
      ReceiptLanguage.hindi: '*भुगतान रसीद',
      ReceiptLanguage.marathi: '*पावती',
      ReceiptLanguage.bengali: '*পেমেন্ট রসিদ',
      ReceiptLanguage.tamil: '*ரசீது',
    };

    for (final entry in expectations.entries) {
      test('formats ${entry.key.label} with customer and referral data', () {
        final text = WhatsAppReceiptService.buildReceiptText(
          organizationName: 'Ramesh Cable Network',
          subscriber: Subscriber(
            id: 7,
            name: 'Sanjay Verma',
            areaId: 2,
            monthlyRent: 350,
            serviceType: 'tv',
            vcNumber: '0214889210',
            areaName: 'Ward 4',
          ),
          payment: Payment(
            subscriberId: 7,
            year: 2026,
            month: 9,
            amountPaid: 350,
          ),
          balanceAfterPayment: 0,
          language: entry.key,
          referralCode: 'AB12CD',
        );

        expect(text, contains(entry.value));
        expect(text, contains('Ramesh Cable Network'));
        expect(text, contains('Sanjay Verma'));
        expect(text, contains('₹350'));
        expect(text, contains('September 2026'));
        expect(text, contains('https://cbk.sarbaa.com/r/AB12CD'));
        expect(text, isNot(contains('{{')));
      });
    }
  });

  test('referral code persists without using subscriber data', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = ReceiptSettingsService();

    await settings.init();
    final firstCode = await settings.getReferralCode();
    await settings.init();
    final secondCode = await settings.getReferralCode();

    expect(firstCode, secondCode);
    expect(firstCode, hasLength(6));
    expect(RegExp(r'^[A-Z0-9]{6}$').hasMatch(firstCode), isTrue);
  });

  group('Launch delivery', () {
    test('uses WhatsApp app before the web fallback', () async {
      final attempted = <Uri>[];
      final service = WhatsAppReceiptService(
        launchUrl: (uri) async {
          attempted.add(uri);
          return uri.scheme == 'https';
        },
      );

      final result = await service.launch(
        phone: '9876543210',
        message: 'Receipt',
      );

      expect(result.usedWebFallback, isTrue);
      expect(attempted, hasLength(2));
      expect(attempted.first.scheme, 'whatsapp');
      expect(attempted.last.host, 'wa.me');
    });

    test('records dispatch only after a launcher succeeds', () async {
      final events = <MapEntry<String, Map<String, Object?>>>[];
      final service = WhatsAppReceiptService(
        launchUrl: (_) async => false,
        recordTelemetry: (name, properties) async {
          events.add(MapEntry(name, properties));
        },
      );

      expect(
        () => service.launch(
          phone: '9876543210',
          message: 'Receipt',
          serviceType: 'fiber',
        ),
        throwsA(isA<ReceiptLaunchException>()),
      );
      expect(events, isEmpty);

      final successful = WhatsAppReceiptService(
        launchUrl: (_) async => true,
        recordTelemetry: (name, properties) async {
          events.add(MapEntry(name, properties));
        },
      );
      await successful.launch(
        phone: '9876543210',
        message: 'Receipt',
        serviceType: 'fiber',
      );
      expect(events.single.key, 'whatsapp_receipt_dispatched');
      expect(events.single.value, {
        'service_type': 'fiber',
        'used_web_fallback': false,
      });
    });

    test('throws a clear error when both delivery paths fail', () async {
      final service = WhatsAppReceiptService(launchUrl: (_) async => false);

      expect(
        () => service.launch(phone: '9876543210', message: 'Receipt'),
        throwsA(isA<ReceiptLaunchException>()),
      );
    });
  });
}
