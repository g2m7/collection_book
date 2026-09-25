import 'package:collection_book/models/payment.dart';
import 'package:collection_book/models/subscriber.dart';
import 'package:collection_book/services/app_language_service.dart';
import 'package:collection_book/services/receipt_settings_service.dart';
import 'package:collection_book/services/whatsapp_receipt_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Latin plus Devanagari, Bengali, and Tamil digits, so a cap written as
/// "१००" or "১০০" is caught just like "100".
final RegExp _anyDigit = RegExp(
  r'[0-9\u0966-\u096F\u09E6-\u09EF\u0BE6-\u0BEF]',
);

/// The free-tier words the old referral lines used, in every receipt language.
const List<String> _freeTierWords = <String>[
  'free',
  'मुफ्त',
  'मुफ़्त',
  'मोफत',
  'বিনামূল্যে',
  'இலவசம்',
];

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

  group('Receipt referral copy makes no unsupported promise', () {
    String receiptFor(ReceiptLanguage language) {
      return WhatsAppReceiptService.buildReceiptText(
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
        language: language,
        referralCode: 'AB12CD',
      );
    }

    /// The closing referral line: the second-to-last line, above the URL.
    String referralAskFor(ReceiptLanguage language) {
      final lines = receiptFor(language).trim().split('\n');
      expect(lines.length, greaterThanOrEqualTo(2));
      return lines[lines.length - 2];
    }

    for (final language in ReceiptLanguage.values) {
      test(
        '${language.label} asks for a referral without a cap or a price',
        () {
          final text = receiptFor(language);
          final ask = referralAskFor(language);

          expect(text, contains('https://cbk.sarbaa.com/r/AB12CD'));
          expect(
            text.trim().split('\n').last,
            'https://cbk.sarbaa.com/r/AB12CD',
          );
          // Collection Book has no subscriber cap, so the referral line may not
          // quote one, in Latin or Indic digits.
          expect(
            ask,
            isNot(matches(_anyDigit)),
            reason: 'Unexpected digit in "$ask"',
          );
          for (final word in _freeTierWords) {
            expect(
              ask.toLowerCase(),
              isNot(contains(word)),
              reason: 'Free-tier wording "$word" in "$ask"',
            );
          }
        },
      );
    }

    test('every locale still states what the receipt is about', () {
      for (final language in ReceiptLanguage.values) {
        final text = receiptFor(language);

        expect(text, contains('Ramesh Cable Network'));
        expect(text, contains('Sanjay Verma'));
        expect(text, contains('0214889210'));
        expect(text, contains('₹350'));
        expect(text, isNot(contains('{{')));
      }
    });
  });
}
