import 'dart:io';

import 'package:collection_book/services/analytics_service.dart';
import 'package:collection_book/services/database_service.dart';
import 'package:collection_book/services/import_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory directory;
  late Database database;
  late ImportService importService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp(
      'ledger_import_telemetry_',
    );
    database = await databaseFactoryFfi.openDatabase(
      '${directory.path}/import.db',
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE areas (id INTEGER PRIMARY KEY, name TEXT)',
          );
          await db.execute('''
            CREATE TABLE subscribers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              area_id INTEGER,
              name TEXT NOT NULL,
              alias_name TEXT,
              vc_number TEXT,
              monthly_rent REAL NOT NULL,
              previous_due REAL NOT NULL,
              is_active INTEGER NOT NULL,
              service_type TEXT NOT NULL,
              start_year INTEGER,
              start_month INTEGER,
              account_id TEXT,
              username TEXT,
              phone TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE payments (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              subscriber_id INTEGER NOT NULL,
              year INTEGER NOT NULL,
              month INTEGER NOT NULL,
              amount_paid REAL NOT NULL,
              adjustment REAL NOT NULL,
              adjustment_note TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE import_runs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              file_name TEXT NOT NULL,
              service_type TEXT NOT NULL,
              status TEXT NOT NULL,
              insert_count INTEGER NOT NULL,
              update_count INTEGER NOT NULL,
              reject_count INTEGER NOT NULL,
              conflict_count INTEGER NOT NULL,
              payment_count INTEGER NOT NULL,
              started_at TEXT NOT NULL,
              completed_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE import_errors (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              run_id INTEGER NOT NULL,
              row_number INTEGER NOT NULL,
              source_column TEXT,
              reason TEXT NOT NULL,
              severity TEXT NOT NULL
            )
          ''');
          await DatabaseService.createAnalyticsEvents(db);
        },
      ),
    );
    final analytics = AnalyticsService.test(
      database: database,
      sender: (_) async => const TelemetryResponse(200, '{}'),
      isWifi: () async => false,
      clock: () => 1800000000000,
    );
    importService = ImportService(
      databaseService: DatabaseService.forTesting(database),
      analytics: analytics,
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  const valid = ImportRecord(name: 'Valid', vc: 'VC-1');
  const invalid = ImportRecord(name: 'Missing strong ID');

  Future<List<String>> eventNames() async {
    final rows = await database.query(
      'analytics_events',
      columns: ['event_name'],
      orderBy: 'created_at, id',
    );
    return rows.map((row) => row['event_name']! as String).toList();
  }

  test('actual commit emits import and first-subscriber for success', () async {
    final result = await importService.commit(
      const ImportPreview(format: ImportFormat.csv, records: [valid]),
      'tv',
      'private-name.csv',
    );

    expect(result.inserted, 1);
    expect(await eventNames(), [
      'first_subscriber_created',
      'mso_file_imported',
    ]);
    final first = await database.query(
      'analytics_events',
      where: 'event_name = ?',
      whereArgs: ['first_subscriber_created'],
    );
    expect(first.single['properties_json'], contains('mso_import'));
  });

  test('actual commit emits import telemetry for a partial run', () async {
    final result = await importService.commit(
      const ImportPreview(
        format: ImportFormat.book1,
        records: [valid, invalid],
      ),
      'tv',
      'private-name.xlsx',
    );

    expect(result.inserted, 1);
    expect(result.rejected, 1);
    expect(await eventNames(), [
      'first_subscriber_created',
      'mso_file_imported',
    ]);
  });

  test(
    'actual failed commit emits no import or first-subscriber telemetry',
    () async {
      final result = await importService.commit(
        const ImportPreview(format: ImportFormat.csv, records: [invalid]),
        'tv',
        'private-name.csv',
      );

      expect(result.inserted, 0);
      expect(result.updated, 0);
      expect(await eventNames(), isEmpty);
      final run = await database.query('import_runs');
      expect(run.single['status'], 'failed');
    },
  );
}
