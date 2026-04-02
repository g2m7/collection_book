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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService().database;
  await AppModeService().init();
  runApp(const RentLedgerApp());
}

class RentLedgerApp extends StatelessWidget {
  const RentLedgerApp({super.key});

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
