import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection_book/models/subscriber.dart';
import 'package:collection_book/services/analytics_service.dart';
import 'package:collection_book/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory directory;
  late Database database;
  late int now;
  late List<Map<String, Object?>> sentBatches;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('ledger_analytics_');
    database = await databaseFactoryFfi.openDatabase(
      '${directory.path}/analytics.db',
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, version) async {
          await DatabaseService.createAnalyticsEvents(db);
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
        },
      ),
    );
    now = 1800000000000;
    sentBatches = [];
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  AnalyticsService service({
    required Future<TelemetryResponse> Function(Uint8List body) sender,
    bool wifi = true,
    Future<bool> Function(String key, String value)? storeClientId,
  }) {
    return AnalyticsService.test(
      database: database,
      sender: (body) async {
        sentBatches.add(
          Map<String, Object?>.from(
            jsonDecode(utf8.decode(gzip.decode(body))) as Map,
          ),
        );
        return sender(body);
      },
      isWifi: () async => wifi,
      clock: () => now,
      storeClientId: storeClientId,
    );
  }

  String accept(Uint8List body) {
    final value =
        jsonDecode(utf8.decode(gzip.decode(body))) as Map<String, dynamic>;
    return jsonEncode({
      'accepted_event_ids': (value['events'] as List)
          .map((event) => (event as Map<String, dynamic>)['id'])
          .toList(),
    });
  }

  test('allowlist rejects unknown events and PII-like properties', () {
    expect(AnalyticsService.isValidEvent('app_first_open', const {}), isTrue);
    expect(
      AnalyticsService.isValidEvent('payment_recorded', {
        'service_type': 'tv',
        'has_adjustment': false,
      }),
      isTrue,
    );
    expect(
      AnalyticsService.isValidEvent('payment_recorded', {
        'service_type': 'tv',
        'has_adjustment': false,
        'subscriber_name': 'Private Customer',
      }),
      isFalse,
    );
    expect(AnalyticsService.isValidEvent('unknown_event', const {}), isFalse);
  });

  test('queues a cryptographically random event id', () async {
    final analytics = service(
      sender: (_) async => const TelemetryResponse(200, '{}'),
    );
    await analytics.track('app_first_open', const {}, requestFlush: false);

    final rows = await database.query('analytics_events');
    expect(rows, hasLength(1));
    expect(rows.single['event_id'], matches(RegExp(r'^[0-9a-f]{32}$')));
  });

  test('app first open is concurrent and durable-idempotent', () async {
    final analytics = service(
      sender: (_) async => const TelemetryResponse(200, '{}'),
      wifi: false,
    );
    await Future.wait([
      analytics.recordAppFirstOpen(),
      analytics.recordAppFirstOpen(),
      analytics.recordAppFirstOpen(),
    ]);

    expect(await database.query('analytics_events'), hasLength(1));
    expect(await database.query('analytics_milestones'), hasLength(1));
  });

  test('failed first-open insertion rolls back its milestone claim', () async {
    await database.execute('''
      CREATE TRIGGER reject_first_open BEFORE INSERT ON analytics_events
      WHEN NEW.event_name = 'app_first_open'
      BEGIN SELECT RAISE(ABORT, 'injected failure'); END
    ''');
    final analytics = service(
      sender: (_) async => const TelemetryResponse(200, '{}'),
      wifi: false,
    );
    await analytics.recordAppFirstOpen();
    expect(await database.query('analytics_milestones'), isEmpty);

    await database.execute('DROP TRIGGER reject_first_open');
    await analytics.recordAppFirstOpen();
    expect(await database.query('analytics_milestones'), hasLength(1));
    expect(await database.query('analytics_events'), hasLength(1));
  });

  test(
    'first subscriber milestone is atomic across concurrent methods',
    () async {
      final analytics = service(
        sender: (_) async => const TelemetryResponse(200, '{}'),
        wifi: false,
      );
      final results = await Future.wait([
        analytics.trackFirstSubscriber(
          Subscriber(name: 'Manual', monthlyRent: 0, serviceType: 'tv'),
          'manual',
        ),
        analytics.trackFirstSubscriber(
          Subscriber(name: 'Imported', monthlyRent: 0, serviceType: 'fiber'),
          'mso_import',
        ),
      ]);

      expect(results, [isTrue, isTrue]);
      expect(await database.query('subscribers'), hasLength(2));
      final events = await database.query(
        'analytics_events',
        where: 'event_name = ?',
        whereArgs: ['first_subscriber_created'],
      );
      expect(events, hasLength(1));
      expect(
        ['manual', 'mso_import'],
        contains(
          jsonDecode(events.single['properties_json']! as String)['method'],
        ),
      );
    },
  );

  test('first-subscriber insert and claim roll back together', () async {
    await database.execute('''
      CREATE TRIGGER reject_first_subscriber BEFORE INSERT ON analytics_events
      WHEN NEW.event_name = 'first_subscriber_created'
      BEGIN SELECT RAISE(ABORT, 'injected failure'); END
    ''');
    final analytics = service(
      sender: (_) async => const TelemetryResponse(200, '{}'),
      wifi: false,
    );

    expect(
      await analytics.trackFirstSubscriber(
        Subscriber(name: 'Manual', monthlyRent: 0, serviceType: 'tv'),
        'manual',
      ),
      isFalse,
    );
    expect(await database.query('subscribers'), isEmpty);
    expect(await database.query('analytics_milestones'), isEmpty);
    expect(await database.query('analytics_events'), isEmpty);
  });

  test('a later manual insert cannot duplicate an import milestone', () async {
    final analytics = service(
      sender: (_) async => const TelemetryResponse(200, '{}'),
      wifi: false,
    );
    final claimed = await database.transaction((transaction) async {
      await transaction.insert(
        'subscribers',
        Subscriber(
          name: 'Imported',
          monthlyRent: 0,
          serviceType: 'fiber',
        ).toMap(),
      );
      return analytics.insertFirstSubscriberEvent(transaction, 'mso_import');
    });
    await analytics.trackFirstSubscriber(
      Subscriber(name: 'Manual', monthlyRent: 0, serviceType: 'tv'),
      'manual',
    );

    expect(claimed, isTrue);
    final events = await database.query(
      'analytics_events',
      where: 'event_name = ?',
      whereArgs: ['first_subscriber_created'],
    );
    expect(events, hasLength(1));
    expect(jsonDecode(events.single['properties_json']! as String), {
      'method': 'mso_import',
    });
  });

  test(
    'a later import claim cannot duplicate an earlier manual milestone',
    () async {
      final analytics = service(
        sender: (_) async => const TelemetryResponse(200, '{}'),
        wifi: false,
      );
      await analytics.trackFirstSubscriber(
        Subscriber(name: 'Manual', monthlyRent: 0, serviceType: 'tv'),
        'manual',
      );
      final claimed = await database.transaction((transaction) async {
        await transaction.insert(
          'subscribers',
          Subscriber(
            name: 'Imported',
            monthlyRent: 0,
            serviceType: 'fiber',
          ).toMap(),
        );
        return analytics.insertFirstSubscriberEvent(transaction, 'mso_import');
      });

      expect(claimed, isFalse);
      expect(
        await database.query(
          'analytics_events',
          where: 'event_name = ?',
          whereArgs: ['first_subscriber_created'],
        ),
        hasLength(1),
      );
    },
  );

  test(
    'failed client-ID persistence retains the queue without sending',
    () async {
      var sends = 0;
      final analytics = service(
        sender: (_) async {
          sends++;
          return const TelemetryResponse(200, '{}');
        },
        storeClientId: (_, _) async => false,
      );
      await analytics.track('app_first_open', const {}, requestFlush: false);

      await analytics.flushIfWifi();
      expect(sends, 0);
      expect(await database.query('analytics_events'), hasLength(1));
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('analytics_client_id_v1'), isNull);
    },
  );

  test('only Wi-Fi flushes and batches contain at most 50 events', () async {
    final analytics = service(
      sender: (body) async => TelemetryResponse(200, accept(body)),
      wifi: false,
    );
    for (var index = 0; index < 51; index++) {
      await analytics.track('app_first_open', const {}, requestFlush: false);
      now++;
    }

    await analytics.flushIfWifi();
    expect(sentBatches, isEmpty);

    final wifiAnalytics = service(
      sender: (body) async => TelemetryResponse(200, accept(body)),
    );
    // Reuse the same queue and mock preferences through a second service.
    await wifiAnalytics.flushIfWifi();
    expect(sentBatches.map((batch) => (batch['events']! as List).length), [
      50,
      1,
    ]);
    expect(
      sentBatches.first['client_id'],
      matches(RegExp(r'^anon_[0-9a-f]{32}$')),
    );
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('analytics_client_id_v1'),
      sentBatches.first['client_id'],
    );
    expect(await database.query('analytics_events'), isEmpty);
  });

  test('deletes only rows explicitly accepted by the Worker', () async {
    await database.insert('analytics_events', {
      'event_id': 'a' * 32,
      'event_name': 'app_first_open',
      'properties_json': '{}',
      'created_at': now,
    });
    await database.insert('analytics_events', {
      'event_id': 'b' * 32,
      'event_name': 'app_first_open',
      'properties_json': '{}',
      'created_at': now + 1,
    });
    final analytics = service(
      sender: (_) async => const TelemetryResponse(
        200,
        '{"accepted_event_ids":["aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"]}',
      ),
    );

    await analytics.flushIfWifi();
    final rows = await database.query('analytics_events');
    expect(rows.map((row) => row['event_id']), ['b' * 32]);
  });

  test(
    'retains retryable failures and applies bounded exponential backoff',
    () async {
      var calls = 0;
      final analytics = service(
        sender: (body) async {
          calls++;
          if (calls == 1) return const TelemetryResponse(503, '');
          return TelemetryResponse(200, accept(body));
        },
      );
      await analytics.track('app_first_open', const {}, requestFlush: false);

      await analytics.flushIfWifi();
      var rows = await database.query('analytics_events');
      expect(rows.single['attempt_count'], 1);
      expect(rows.single['next_attempt_at'], now + 60000);
      expect(rows.single['last_error'], 'retryable_http');

      now += 60000;
      await analytics.flushIfWifi();
      rows = await database.query('analytics_events');
      expect(rows, isEmpty);
      expect(calls, 2);
    },
  );

  test('retains timeouts/429, then removes permanent 413 batches', () async {
    var attempt = 0;
    final analytics = service(
      sender: (body) async {
        attempt++;
        if (attempt == 1) throw TimeoutException('telemetry timeout');
        if (attempt == 2) return const TelemetryResponse(429, 'retry later');
        return const TelemetryResponse(413, 'payload too large');
      },
    );
    await analytics.track('app_first_open', const {}, requestFlush: false);
    await analytics.flushIfWifi();
    expect(await database.query('analytics_events'), hasLength(1));

    now += 60000;
    await analytics.flushIfWifi();
    expect(await database.query('analytics_events'), hasLength(1));
    expect(
      (await database.query('analytics_events')).single['attempt_count'],
      2,
    );

    now += 120000;
    await analytics.flushIfWifi();
    expect(await database.query('analytics_events'), isEmpty);
  });

  for (final status in [301, 302, 307, 308]) {
    test('retains redirect response $status for retry', () async {
      await database.insert('analytics_events', {
        'event_id': 'a' * 32,
        'event_name': 'app_first_open',
        'properties_json': '{}',
        'created_at': now,
      });
      final analytics = service(
        sender: (_) async => TelemetryResponse(status, ''),
      );

      await analytics.flushIfWifi();
      final row = (await database.query('analytics_events')).single;
      expect(row['attempt_count'], 1);
      expect(row['last_error'], 'redirect_http');
      expect(row['next_attempt_at'], now + 60000);
    });
  }

  test(
    'reset suspension fences an in-flight flush and blocks new flushes',
    () async {
      await database.insert('analytics_events', {
        'event_id': 'a' * 32,
        'event_name': 'app_first_open',
        'properties_json': '{}',
        'created_at': now,
      });
      final senderStarted = Completer<void>();
      final releaseSender = Completer<void>();
      final analytics = service(
        sender: (body) async {
          senderStarted.complete();
          await releaseSender.future;
          return TelemetryResponse(200, accept(body));
        },
      );

      final flush = analytics.flushIfWifi();
      await senderStarted.future;
      var suspensionCompleted = false;
      final suspension = analytics.suspendForReset().then((_) {
        suspensionCompleted = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(suspensionCompleted, isFalse);

      await analytics.flushIfWifi();
      expect(sentBatches, hasLength(1));
      await analytics.resumeAfterReset();
      expect(suspensionCompleted, isFalse);
      expect(sentBatches, hasLength(1));

      releaseSender.complete();
      await flush;
      await suspension;
      await analytics.flushIfWifi();
      expect(sentBatches, hasLength(1));
    },
  );

  test(
    'a flush cannot recreate the client ID while reset is suspended',
    () async {
      await database.insert('analytics_events', {
        'event_id': 'a' * 32,
        'event_name': 'app_first_open',
        'properties_json': '{}',
        'created_at': now,
      });
      var storeCalls = 0;
      final analytics = service(
        sender: (body) async => TelemetryResponse(200, accept(body)),
        storeClientId: (key, value) async {
          storeCalls++;
          return (await SharedPreferences.getInstance()).setString(key, value);
        },
      );

      await analytics.suspendForReset();
      await analytics.flushIfWifi();
      expect(storeCalls, 0);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('analytics_client_id_v1'), isNull);

      await analytics.resumeAfterReset();
      await analytics.flushIfWifi();
      expect(storeCalls, 1);
      expect(
        preferences.getString('analytics_client_id_v1'),
        matches(RegExp(r'^anon_[0-9a-f]{32}$')),
      );
    },
  );

  test('telemetry timeout covers stalled response-body consumption', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await request.drain<void>();
      try {
        request.response
          ..statusCode = 200
          ..headers.contentLength = 100
          ..add(const [1])
          ..flush();
        await Future<void>.delayed(const Duration(seconds: 1));
        await request.response.close();
      } catch (_) {
        // The client intentionally closes the stalled response.
      }
    });
    final body = Uint8List.fromList(
      gzip.encode(utf8.encode(jsonEncode({'client_id': 'test', 'events': []}))),
    );

    final stopwatch = Stopwatch()..start();
    await expectLater(
      AnalyticsService.sendTelemetry(
        body,
        endpoint: Uri.parse('http://${server.address.host}:${server.port}/'),
        timeout: const Duration(milliseconds: 150),
        cancelResponse: (_) => Completer<void>().future,
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(stopwatch.elapsedMilliseconds, lessThan(500));
  });

  test('deletes events older than 30 days before sending', () async {
    await database.insert('analytics_events', {
      'event_id': 'a' * 32,
      'event_name': 'app_first_open',
      'properties_json': '{}',
      'created_at': now - const Duration(days: 31).inMilliseconds,
    });
    await database.insert('analytics_events', {
      'event_id': 'b' * 32,
      'event_name': 'app_first_open',
      'properties_json': '{}',
      'created_at': now - 1000,
    });
    final analytics = service(
      sender: (body) async => TelemetryResponse(200, accept(body)),
    );

    await analytics.flushIfWifi();
    final body = sentBatches.single;
    expect((body['events']! as List), hasLength(1));
    expect((body['events']! as List).single, containsPair('id', 'b' * 32));
  });
}
