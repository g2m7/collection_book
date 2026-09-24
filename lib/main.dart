import 'dart:async';

import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/subscriber_list_screen.dart';
import 'screens/subscriber_detail_screen.dart';
import 'screens/record_payment_screen.dart';
import 'screens/add_subscriber_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/import_wizard_screen.dart';
import 'screens/import_history_screen.dart';
import 'services/database_service.dart';
import 'services/app_mode_service.dart';
import 'services/receipt_settings_service.dart';
import 'services/analytics_service.dart';

Future<void> initializeCollectionBookApp() async {
  await DatabaseService().database;
  await AppModeService().init();
  await ReceiptSettingsService().init();
  final analytics = AnalyticsService();
  await analytics.init();
  await analytics.recordAppFirstOpen();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeCollectionBookApp();
  runApp(const CollectionBookApp());
}

class CollectionBookApp extends StatefulWidget {
  const CollectionBookApp({super.key});

  @override
  State<CollectionBookApp> createState() => _CollectionBookAppState();
}

class _CollectionBookAppState extends State<CollectionBookApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AnalyticsService().flushIfWifi());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ServiceMode>(
      valueListenable: AppModeService().modeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Collection Book',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeFor(mode),
          home: const HomeScreen(),
          routes: {
            '/subscribers': (context) => const SubscriberListScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/import-wizard': (context) => const ImportWizardScreen(),
            '/import-history': (context) => const ImportHistoryScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/subscriber-detail') {
              final id = settings.arguments as int;
              return MaterialPageRoute(
                builder: (context) => SubscriberDetailScreen(subscriberId: id),
              );
            }
            if (settings.name == '/record-payment') {
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (context) => RecordPaymentScreen(
                  subscriberId: args?['subscriberId'] as int?,
                  subscriberName: args?['subscriberName'] as String?,
                  initialMonth: args?['month'] as int?,
                  initialYear: args?['year'] as int?,
                ),
              );
            }
            if (settings.name == '/add-subscriber') {
              final sub = settings.arguments;
              return MaterialPageRoute(
                builder: (context) =>
                    AddSubscriberScreen(subscriberId: sub as int?),
              );
            }
            return null;
          },
        );
      },
    );
  }
}
