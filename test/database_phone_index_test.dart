import 'dart:io';

import 'package:collection_book/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('v6 to v8 upgrade preserves phone data and adds the index', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'ledger_receipt_migration_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final path = '${tempDir.path}/migration.db';

    final v6 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE subscribers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              phone TEXT
            )
          ''');
          await db.insert('subscribers', {
            'name': 'Existing Customer',
            'phone': '+919876543210',
          });
        },
      ),
    );
    await v6.close();

    final upgraded = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: DatabaseService.databaseVersion,
        onUpgrade: DatabaseService.applyUpgrade,
      ),
    );
    addTearDown(upgraded.close);

    expect(
      Sqflite.firstIntValue(await upgraded.rawQuery('PRAGMA user_version')),
      DatabaseService.databaseVersion,
    );

    // Reapplying the v7 migration verifies its IF NOT EXISTS behavior.
    await DatabaseService.applyUpgrade(
      upgraded,
      6,
      DatabaseService.databaseVersion,
    );

    final indexes = await upgraded.rawQuery('PRAGMA index_list(subscribers)');
    expect(
      indexes.any((row) => row['name'] == 'idx_subscribers_phone'),
      isTrue,
    );

    final rows = await upgraded.query('subscribers');
    expect(rows, hasLength(1));
    expect(rows.single['name'], 'Existing Customer');
    expect(rows.single['phone'], '+919876543210');
  });

  test('v7 to v8 migration creates a durable analytics queue', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'ledger_analytics_migration_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final path = '${tempDir.path}/migration.db';

    final v7 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE marker (id INTEGER PRIMARY KEY)');
          await db.insert('marker', {'id': 1});
        },
      ),
    );
    await v7.close();

    final upgraded = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: DatabaseService.databaseVersion,
        onUpgrade: DatabaseService.applyUpgrade,
      ),
    );
    addTearDown(upgraded.close);
    await DatabaseService.applyUpgrade(
      upgraded,
      7,
      DatabaseService.databaseVersion,
    );

    final milestoneColumns = await upgraded.rawQuery(
      'PRAGMA table_info(analytics_milestones)',
    );
    expect(
      milestoneColumns.map((row) => row['name']),
      containsAll(['milestone', 'created_at']),
    );
    final columns = await upgraded.rawQuery(
      'PRAGMA table_info(analytics_events)',
    );
    expect(
      columns.map((row) => row['name']),
      containsAll([
        'event_id',
        'event_name',
        'properties_json',
        'created_at',
        'attempt_count',
        'next_attempt_at',
        'last_error',
      ]),
    );
    expect(await upgraded.query('marker'), hasLength(1));
  });
}
