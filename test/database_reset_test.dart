import 'dart:io';

import 'package:collection_book/models/area.dart';
import 'package:collection_book/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late DatabaseService service;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ledger_reset_db_');
    await databaseFactoryFfi.setDatabasesPath(directory.path);
    service = DatabaseService();
    await service.database;
    await service.insertArea(const Area(id: 1, name: 'Original'));
  });

  tearDown(() async {
    await service.closeDb();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'reset replaces the live database and removes its temporary backup',
    () async {
      final path = await service.getDatabasePath();

      await service.resetAllData();

      expect(await service.getAreas(), isEmpty);
      expect(await service.getSubscribers(), isEmpty);
      expect(
        (await directory.list().toList())
            .where((entity) => entity.path.contains('.reset-'))
            .toList(),
        isEmpty,
      );
      expect(await File(path).exists(), isTrue);
    },
  );

  test(
    'reset restores and reopens the original when recreation fails',
    () async {
      var openCalls = 0;
      final original = await service.database;
      final failingService = DatabaseService.forTesting(
        original,
        openDatabaseForTesting: (path) async {
          openCalls++;
          if (openCalls == 1) throw StateError('injected recreation failure');
          return databaseFactoryFfi.openDatabase(path);
        },
      );

      await expectLater(
        failingService.resetAllData(),
        throwsA(isA<StateError>()),
      );

      expect(openCalls, 2);
      expect(await failingService.getAreas(), hasLength(1));
      expect((await failingService.getAreas()).single.name, 'Original');
      expect(
        (await directory.list().toList())
            .where((entity) => entity.path.contains('.reset-'))
            .toList(),
        isEmpty,
      );
      await failingService.closeDb();
    },
  );
}
