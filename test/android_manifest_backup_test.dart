import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The product promise is that the subscriber register never leaves the device,
/// so the Android app must not hand its local database to the platform's backup
/// service. The privacy policy at `cbk.sarbaa.com/privacy` states that the app
/// is installed with operating-system backup disabled, and this test is what
/// keeps that sentence true.
void main() {
  group('Android manifest keeps the local-only promise', () {
    late String manifest;

    setUpAll(() {
      manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
    });

    test('disables operating-system backup for the application', () {
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, isNot(contains('android:allowBackup="true"')));
    });

    test('keeps the app link and WhatsApp query targets intact', () {
      expect(manifest, contains('android:host="cbk.sarbaa.com"'));
      expect(manifest, contains('android:pathPrefix="/r/"'));
      expect(manifest, contains('android:host="wa.me"'));
    });
  });
}
