import 'package:url_launcher/url_launcher.dart';

import '../models/payment.dart';
import '../models/subscriber.dart';
import 'receipt_settings_service.dart';

enum ReceiptBalanceStatus { fullyPaid, advance, arrears }

class ReceiptBalance {
  final ReceiptBalanceStatus status;
  final String label;
  final double remainingDue;

  const ReceiptBalance({
    required this.status,
    required this.label,
    required this.remainingDue,
  });
}

class ReceiptLaunchResult {
  final bool usedWebFallback;

  const ReceiptLaunchResult({required this.usedWebFallback});
}

class ReceiptLaunchException implements Exception {
  final String message;

  const ReceiptLaunchException(this.message);

  @override
  String toString() => message;
}

typedef UrlLauncher = Future<bool> Function(Uri uri);

/// Formats receipts and opens them in WhatsApp, falling back to wa.me.
class WhatsAppReceiptService {
  static const referralBaseUrl = 'https://cbk.sarbaa.com/';

  final UrlLauncher _launchUrl;

  WhatsAppReceiptService({UrlLauncher? launchUrl})
    : _launchUrl = launchUrl ?? _defaultLaunchUrl;

  static Future<bool> _defaultLaunchUrl(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Normalizes an Indian mobile number to E.164 (+91XXXXXXXXXX).
  static String? normalizeIndianPhone(String? value) {
    if (value == null) return null;
    final input = value.trim();
    if (input.isEmpty || !RegExp(r'^[+0-9 ()-]+$').hasMatch(input)) {
      return null;
    }

    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    String nationalNumber;
    if (digits.length == 10) {
      nationalNumber = digits;
    } else if (digits.length == 11 && digits.startsWith('0')) {
      nationalNumber = digits.substring(1);
    } else if (digits.length == 12 && digits.startsWith('91')) {
      nationalNumber = digits.substring(2);
    } else {
      return null;
    }

    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(nationalNumber)) return null;
    return '+91$nationalNumber';
  }

  static Uri buildAppUri(String phone, String message) {
    return Uri(
      scheme: 'whatsapp',
      host: 'send',
      query: _encodedQuery({'phone': phone, 'text': message}),
    );
  }

  static Uri buildWebUri(String phone, String message) {
    return Uri(
      scheme: 'https',
      host: 'wa.me',
      path: '/$phone',
      query: _encodedQuery({'text': message}),
    );
  }

  static String _encodedQuery(Map<String, String> values) {
    return values.entries
        .map((entry) {
          final encoded = Uri.encodeQueryComponent(
            entry.value,
          ).replaceAll('+', '%20');
          return '${Uri.encodeQueryComponent(entry.key)}=$encoded';
        })
        .join('&');
  }

  static String buildReferralUrl(String referralCode) {
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(referralCode)) {
      throw ArgumentError.value(
        referralCode,
        'referralCode',
        'Must be a six-character referral code',
      );
    }
    return '${referralBaseUrl}r/${Uri.encodeComponent(referralCode)}';
  }

  static ReceiptBalance calculateBalance(
    double balanceAfterPayment,
    ReceiptLanguage language,
  ) {
    const tolerance = 0.005;
    final amount = _formatCurrency(balanceAfterPayment.abs());
    final label = switch (balanceAfterPayment) {
      final value when value > tolerance => _statusLabel(
        language,
        ReceiptBalanceStatus.arrears,
        amount,
      ),
      final value when value < -tolerance => _statusLabel(
        language,
        ReceiptBalanceStatus.advance,
        amount,
      ),
      _ => _statusLabel(language, ReceiptBalanceStatus.fullyPaid, amount),
    };

    return ReceiptBalance(
      status: balanceAfterPayment > tolerance
          ? ReceiptBalanceStatus.arrears
          : balanceAfterPayment < -tolerance
          ? ReceiptBalanceStatus.advance
          : ReceiptBalanceStatus.fullyPaid,
      label: label,
      remainingDue: balanceAfterPayment > tolerance ? balanceAfterPayment : 0,
    );
  }

  static String buildReceiptText({
    required String organizationName,
    required Subscriber subscriber,
    required Payment payment,
    required double balanceAfterPayment,
    required ReceiptLanguage language,
    required String referralCode,
  }) {
    final balance = calculateBalance(balanceAfterPayment, language);
    final values = <String, String>{
      'ORG_NAME': organizationName.trim().isEmpty
          ? 'Collection Book'
          : organizationName.trim(),
      'CUST_NAME': subscriber.name,
      'VC_NUMBER': _subscriberIdentifier(subscriber),
      'SERVICE': subscriber.serviceType == 'fiber'
          ? 'Fiber Internet'
          : 'Cable TV',
      'AREA': subscriber.areaName?.trim().isNotEmpty == true
          ? subscriber.areaName!.trim()
          : 'N/A',
      'MONTH': '${_monthName(payment.month)} ${payment.year}',
      'PAID_AMT': _formatCurrency(payment.amountPaid),
      'STATUS_LABEL': balance.label,
      'REMAINING_DUE': _formatCurrency(balance.remainingDue),
      'REF_URL': buildReferralUrl(referralCode),
    };

    return _template(language).replaceAllMapped(
      RegExp(r'\{\{([A-Z_]+)\}\}'),
      (match) => values[match.group(1)!] ?? match.group(0)!,
    );
  }

  Future<ReceiptLaunchResult> launch({
    required String phone,
    required String message,
  }) async {
    final normalized = normalizeIndianPhone(phone);
    if (normalized == null) {
      throw const ReceiptLaunchException(
        'A valid Indian mobile number is required to send this receipt.',
      );
    }

    final whatsappNumber = normalized.substring(1);
    final appUri = buildAppUri(whatsappNumber, message);
    final webUri = buildWebUri(whatsappNumber, message);
    Object? appFailure;

    try {
      if (await _launchUrl(appUri)) {
        return const ReceiptLaunchResult(usedWebFallback: false);
      }
    } catch (error) {
      appFailure = error;
    }

    try {
      if (await _launchUrl(webUri)) {
        return const ReceiptLaunchResult(usedWebFallback: true);
      }
    } catch (error) {
      throw ReceiptLaunchException(
        'Could not open WhatsApp or wa.me. WhatsApp error: $appFailure; '
        'web fallback error: $error',
      );
    }

    throw ReceiptLaunchException(
      appFailure == null
          ? 'Could not open WhatsApp or its wa.me fallback.'
          : 'WhatsApp could not be opened, and wa.me was unavailable. '
                'WhatsApp error: $appFailure',
    );
  }

  static String _subscriberIdentifier(Subscriber subscriber) {
    if (subscriber.serviceType == 'tv') {
      return _nonEmpty(subscriber.vcNumber);
    }
    return _nonEmpty(
      subscriber.accountId ?? subscriber.vcNumber ?? subscriber.username,
    );
  }

  static String _nonEmpty(String? value) {
    return value == null || value.trim().isEmpty ? 'N/A' : value.trim();
  }

  static String _formatCurrency(double value) {
    final rounded = value.round();
    return '₹${rounded.abs()}';
  }

  static String _statusLabel(
    ReceiptLanguage language,
    ReceiptBalanceStatus status,
    String amount,
  ) {
    return switch ((language, status)) {
      (ReceiptLanguage.english, ReceiptBalanceStatus.fullyPaid) => 'FULLY PAID',
      (ReceiptLanguage.english, ReceiptBalanceStatus.advance) =>
        'ADVANCE $amount',
      (ReceiptLanguage.english, ReceiptBalanceStatus.arrears) =>
        'PARTIAL (DUE)',
      (ReceiptLanguage.hindi, ReceiptBalanceStatus.fullyPaid) => 'पूरा भुगतान',
      (ReceiptLanguage.hindi, ReceiptBalanceStatus.advance) => 'अग्रिम $amount',
      (ReceiptLanguage.hindi, ReceiptBalanceStatus.arrears) => 'बकाया',
      (ReceiptLanguage.marathi, ReceiptBalanceStatus.fullyPaid) =>
        'पूर्णपणे भरले',
      (ReceiptLanguage.marathi, ReceiptBalanceStatus.advance) =>
        'अग्रिम $amount',
      (ReceiptLanguage.marathi, ReceiptBalanceStatus.arrears) => 'बाकी',
      (ReceiptLanguage.bengali, ReceiptBalanceStatus.fullyPaid) =>
        'সম্পূর্ণ পরিশোধ',
      (ReceiptLanguage.bengali, ReceiptBalanceStatus.advance) =>
        'অগ্রিম $amount',
      (ReceiptLanguage.bengali, ReceiptBalanceStatus.arrears) => 'বকেয়া',
      (ReceiptLanguage.tamil, ReceiptBalanceStatus.fullyPaid) =>
        'முழுமையாக செலுத்தப்பட்டது',
      (ReceiptLanguage.tamil, ReceiptBalanceStatus.advance) =>
        'முன்பணம் $amount',
      (ReceiptLanguage.tamil, ReceiptBalanceStatus.arrears) => 'பாக்கி',
    };
  }

  static String _monthName(int month) {
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
    return month >= 1 && month <= 12 ? months[month - 1] : 'Unknown month';
  }

  static String _template(ReceiptLanguage language) {
    return switch (language) {
      ReceiptLanguage.english =>
        '''
🧾 *PAYMENT RECEIPT | {{ORG_NAME}}*
━━━━━━━━━━━━━━━━━━━━━
👤 *Customer:* {{CUST_NAME}}
📺 *Service:* {{SERVICE}} (VC: {{VC_NUMBER}})
📍 *Area:* {{AREA}}
🗓️ *Billing Month:* {{MONTH}}
━━━━━━━━━━━━━━━━━━━━━
💵 *Amount Paid:* {{PAID_AMT}}
✅ *Status:* {{STATUS_LABEL}}
⚠️ *Remaining Due:* {{REMAINING_DUE}}
━━━━━━━━━━━━━━━━━━━━━
🙏 Thank you for your payment!

📱 Managed via Collection Book App
👉 Are you a Cable/WiFi Operator? Try Free (up to 100 subs):
{{REF_URL}}''',
      ReceiptLanguage.hindi =>
        '''
🧾 *भुगतान रसीद | {{ORG_NAME}}*
━━━━━━━━━━━━━━━━━━━━━
👤 *ग्राहक:* {{CUST_NAME}}
📺 *सेवा:* {{SERVICE}} (VC: {{VC_NUMBER}})
📍 *क्षेत्र:* {{AREA}}
🗓️ *बिलिंग महीना:* {{MONTH}}
━━━━━━━━━━━━━━━━━━━━━
💵 *जमा राशि:* {{PAID_AMT}}
✅ *स्थिति:* {{STATUS_LABEL}}
⚠️ *बकाया राशि:* {{REMAINING_DUE}}
━━━━━━━━━━━━━━━━━━━━━
🙏 समय पर भुगतान करने के लिए धन्यवाद!

📱 Managed via Collection Book App
👉 क्या आप केबल/WiFi ऑपरेटर हैं? 100 कनेक्शन तक फ्री ऐप डाउनलोड करें:
{{REF_URL}}''',
      ReceiptLanguage.marathi =>
        '''
🧾 *पावती | {{ORG_NAME}}*
━━━━━━━━━━━━━━━━━━━━━
👤 *ग्राहक:* {{CUST_NAME}}
📺 *सेवा:* {{SERVICE}} (VC: {{VC_NUMBER}})
📍 *गल्ली/भाग:* {{AREA}}
🗓️ *महिना:* {{MONTH}}
━━━━━━━━━━━━━━━━━━━━━
💵 *जमा केलेली रक्कम:* {{PAID_AMT}}
✅ *स्थिती:* {{STATUS_LABEL}}
⚠️ *उर्वरित बाकी:* {{REMAINING_DUE}}
━━━━━━━━━━━━━━━━━━━━━
🙏 वेळेवर बिल भरल्याबद्दल धन्यवाद!

📱 Managed via Collection Book App
👉 आपण केबल/इंटरनेट ऑपरेटर आहात का? १०० ग्राहकांसाठी मोफत अ‍ॅप:
{{REF_URL}}''',
      ReceiptLanguage.bengali =>
        '''
🧾 *পেমেন্ট রসিদ | {{ORG_NAME}}*
━━━━━━━━━━━━━━━━━━━━━
👤 *গ্রাহক:* {{CUST_NAME}}
📺 *পরিষেবা:* {{SERVICE}} (VC: {{VC_NUMBER}})
📍 *এলাকা:* {{AREA}}
🗓️ *বিলিং মাস:* {{MONTH}}
━━━━━━━━━━━━━━━━━━━━━
💵 *প্রদত্ত টাকা:* {{PAID_AMT}}
✅ *স্ট্যাটাস:* {{STATUS_LABEL}}
⚠️ *বকেয়া টাকা:* {{REMAINING_DUE}}
━━━━━━━━━━━━━━━━━━━━━
🙏 সময়মতো বিল পরিশোধ করার জন্য ধন্যবাদ!

📱 Managed via Collection Book App
👉 আপনি কি কেবল বা ইন্টারনেট অপারেটর? ১০০ গ্রাহক পর্যন্ত ফ্রি অ্যাপ:
{{REF_URL}}''',
      ReceiptLanguage.tamil =>
        '''
🧾 *ரசீது | {{ORG_NAME}}*
━━━━━━━━━━━━━━━━━━━━━
👤 *வாடிக்கையாளர்:* {{CUST_NAME}}
📺 *சேவை:* {{SERVICE}} (VC: {{VC_NUMBER}})
📍 *பகுதி:* {{AREA}}
🗓️ *மாதம்:* {{MONTH}}
━━━━━━━━━━━━━━━━━━━━━
💵 *செலுத்திய தொகை:* {{PAID_AMT}}
✅ *நிலை:* {{STATUS_LABEL}}
⚠️ *மீதி பாக்கி:* {{REMAINING_DUE}}
━━━━━━━━━━━━━━━━━━━━━
🙏 சரியான நேரத்தில் கட்டணம் செலுத்தியதற்கு நன்றி!

📱 Managed via Collection Book App
👉 நீங்கள் கேபிள்/வைஃபை ஆபரேட்டரா? 100 இணைப்புகள் இலவசம்:
{{REF_URL}}''',
    };
  }
}
