import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language_service.dart';

enum ReceiptLanguage { english, hindi, marathi, bengali, tamil }

extension AppLanguageReceipt on AppLanguageService {
  ReceiptLanguage get receiptLanguage => switch (languageCode) {
    'hi' => ReceiptLanguage.hindi,
    'mr' => ReceiptLanguage.marathi,
    'bn' => ReceiptLanguage.bengali,
    'ta' => ReceiptLanguage.tamil,
    _ => ReceiptLanguage.english,
  };
}

extension ReceiptLanguageX on ReceiptLanguage {
  String get key => name;
  String get localeCode => switch (this) {
    ReceiptLanguage.english => 'en',
    ReceiptLanguage.hindi => 'hi',
    ReceiptLanguage.marathi => 'mr',
    ReceiptLanguage.bengali => 'bn',
    ReceiptLanguage.tamil => 'ta',
  };

  String get label => switch (this) {
    ReceiptLanguage.english => 'English',
    ReceiptLanguage.hindi => 'Hindi',
    ReceiptLanguage.marathi => 'Marathi',
    ReceiptLanguage.bengali => 'Bengali',
    ReceiptLanguage.tamil => 'Tamil',
  };

  static ReceiptLanguage fromKey(String? value) {
    return ReceiptLanguage.values.firstWhere(
      (language) => language.key == value,
      orElse: () => ReceiptLanguage.english,
    );
  }
}

/// Persists receipt preferences and an anonymous installation referral code.
class ReceiptSettingsService {
  static final ReceiptSettingsService _instance = ReceiptSettingsService._();
  factory ReceiptSettingsService() => _instance;
  ReceiptSettingsService._();

  static const _businessNameKey = 'receipt_business_name';
  static const _languageKey = 'receipt_language';
  static const _referralCodeKey = 'receipt_referral_code';
  static const defaultBusinessName = 'Collection Book';

  static const _referralAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final ValueNotifier<ReceiptLanguage> languageNotifier = ValueNotifier(
    ReceiptLanguage.english,
  );
  final ValueNotifier<String> businessNameNotifier = ValueNotifier(
    defaultBusinessName,
  );

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    businessNameNotifier.value = _businessName(prefs);
    languageNotifier.value = ReceiptLanguageX.fromKey(
      prefs.getString(_languageKey),
    );
    await _getOrCreateReferralCode(prefs);
  }

  ReceiptLanguage get language => languageNotifier.value;

  Future<void> setLanguage(ReceiptLanguage language) async {
    languageNotifier.value = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.key);
  }

  Future<void> setBusinessName(String name) async {
    final normalized = name.trim().isEmpty ? defaultBusinessName : name.trim();
    businessNameNotifier.value = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_businessNameKey, normalized);
  }

  /// Returns a stable, random code that contains no subscriber or operator PII.
  Future<String> getReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    return _getOrCreateReferralCode(prefs);
  }

  /// Restores default in-memory values after an all-app-data reset.
  void resetToDefaults() {
    businessNameNotifier.value = defaultBusinessName;
    languageNotifier.value = ReceiptLanguage.english;
  }

  String _businessName(SharedPreferences prefs) {
    final value = prefs.getString(_businessNameKey)?.trim();
    return value == null || value.isEmpty ? defaultBusinessName : value;
  }

  Future<String> _getOrCreateReferralCode(SharedPreferences prefs) async {
    final saved = prefs.getString(_referralCodeKey);
    if (_isValidReferralCode(saved)) return saved!;

    final random = Random.secure();
    final code = List.generate(6, (_) {
      return _referralAlphabet[random.nextInt(_referralAlphabet.length)];
    }).join();
    await prefs.setString(_referralCodeKey, code);
    return code;
  }

  bool _isValidReferralCode(String? code) {
    return code != null &&
        RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code);
  }
}
