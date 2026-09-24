import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/subscriber.dart';
import 'database_service.dart';

const _clientIdKey = 'analytics_client_id_v1';
const _maxEventsPerBatch = 50;
const _maxPropertiesBytes = 4096;
const _retention = Duration(days: 30);
const _endpoint = 'https://cbk.sarbaa.com/api/v1/telemetry/batch';

class TelemetryResponse {
  final int statusCode;
  final String body;

  const TelemetryResponse(this.statusCode, this.body);
}

typedef TelemetrySender = Future<TelemetryResponse> Function(Uint8List body);
typedef ResponseCanceller =
    Future<void> Function(StreamSubscription<List<int>> subscription);
typedef WifiChecker = Future<bool> Function();
typedef Clock = int Function();

class PreparedAnalyticsEvent {
  final String eventId;
  final String eventName;
  final String propertiesJson;
  final int createdAt;

  const PreparedAnalyticsEvent({
    required this.eventId,
    required this.eventName,
    required this.propertiesJson,
    required this.createdAt,
  });
}

class AnalyticsService {
  static const eventNames = <String>{
    'app_first_open',
    'first_subscriber_created',
    'mso_file_imported',
    'payment_recorded',
    'whatsapp_receipt_dispatched',
  };

  static final AnalyticsService _instance = AnalyticsService._();
  factory AnalyticsService() => _instance;

  final DatabaseService _databaseService;
  final Database? _databaseOverride;
  final TelemetrySender _sender;
  final WifiChecker _isWifi;
  final Clock _clock;
  final Future<SharedPreferences> Function() _preferences;
  final Future<bool> Function(String key, String value) _storeClientId;
  Timer? _periodicTimer;
  Completer<void>? _flushCompletion;
  bool _initialized = false;
  bool _flushing = false;
  bool _flushRequested = false;
  bool _resetSuspended = false;
  bool _resumeTimerAfterReset = false;

  AnalyticsService._({
    DatabaseService? databaseService,
    TelemetrySender? sender,
    WifiChecker? isWifi,
    Clock? clock,
    Future<SharedPreferences> Function()? preferences,
    Future<bool> Function(String key, String value)? storeClientId,
  }) : _databaseService = databaseService ?? DatabaseService(),
       _databaseOverride = null,
       _sender = sender ?? ((body) => sendTelemetry(body)),
       _isWifi = isWifi ?? _hasWifi,
       _clock = clock ?? _epochMilliseconds,
       _preferences = preferences ?? SharedPreferences.getInstance,
       _storeClientId =
           storeClientId ??
           ((key, value) async =>
               (await SharedPreferences.getInstance()).setString(key, value));

  @visibleForTesting
  AnalyticsService.test({
    required Database database,
    required TelemetrySender sender,
    required WifiChecker isWifi,
    Clock? clock,
    Future<SharedPreferences> Function()? preferences,
    Future<bool> Function(String key, String value)? storeClientId,
  }) : _databaseService = DatabaseService(),
       _databaseOverride = database,
       _sender = sender,
       _isWifi = isWifi,
       _clock = clock ?? _epochMilliseconds,
       _preferences = preferences ?? SharedPreferences.getInstance,
       _storeClientId =
           storeClientId ??
           ((key, value) async =>
               (await SharedPreferences.getInstance()).setString(key, value));

  Future<Database> get _database async =>
      _databaseOverride ?? _databaseService.database;

  static int _epochMilliseconds() => DateTime.now().millisecondsSinceEpoch;

  static Future<bool> _hasWifi() async {
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  @visibleForTesting
  static Future<TelemetryResponse> sendTelemetry(
    Uint8List body, {
    Uri? endpoint,
    Duration timeout = const Duration(seconds: 8),
    ResponseCanceller? cancelResponse,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = timeout < const Duration(seconds: 5)
          ? timeout
          : const Duration(seconds: 5);
    final deadline = DateTime.now().add(timeout);
    try {
      final request = await client
          .postUrl(endpoint ?? Uri.parse(_endpoint))
          .timeout(_remaining(deadline));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
      request.contentLength = body.length;
      request.add(body);
      final response = await request.close().timeout(_remaining(deadline));
      final bytes = await _consumeResponse(
        response,
        deadline,
        cancelResponse ?? _cancelResponse,
      );
      return TelemetryResponse(
        response.statusCode,
        utf8.decode(bytes, allowMalformed: true),
      );
    } finally {
      client.close(force: true);
    }
  }

  static Future<Uint8List> _consumeResponse(
    Stream<List<int>> response,
    DateTime deadline,
    ResponseCanceller cancel,
  ) async {
    final completer = Completer<Uint8List>();
    final bytes = BytesBuilder(copy: false);
    final timer = Timer(_remaining(deadline), () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Telemetry timeout'));
      }
    });
    late final StreamSubscription<List<int>> subscription;
    subscription = response.listen(
      (chunk) {
        if (completer.isCompleted) return;
        if (bytes.length + chunk.length > 64 * 1024) {
          completer.completeError(
            const HttpException('Telemetry response is too large'),
          );
        } else {
          bytes.add(chunk);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete(bytes.takeBytes());
      },
      cancelOnError: true,
    );
    try {
      return await completer.future;
    } finally {
      timer.cancel();
      unawaited(_runCancellation(cancel, subscription));
    }
  }

  static Future<void> _cancelResponse(
    StreamSubscription<List<int>> subscription,
  ) => subscription.cancel();

  static Future<void> _runCancellation(
    ResponseCanceller cancel,
    StreamSubscription<List<int>> subscription,
  ) async {
    try {
      await cancel(subscription);
    } catch (_) {
      // Cleanup errors must not become unhandled asynchronous errors.
    }
  }

  static Duration _remaining(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) throw TimeoutException('Telemetry timeout');
    return remaining;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => unawaited(flushIfWifi()),
    );
  }

  /// Stops periodic and new flushes and waits for the current flush to finish.
  /// The reset coordinator must not mutate preferences or SQLite until this
  /// future completes.
  Future<void> suspendForReset() async {
    _resetSuspended = true;
    _resumeTimerAfterReset = _resumeTimerAfterReset || _initialized;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _initialized = false;
    await _flushCompletion?.future;
  }

  /// Restores the periodic flush after a reset attempt, successful or not.
  Future<void> resumeAfterReset() async {
    if (!_resetSuspended) return;
    _resetSuspended = false;
    if (_resumeTimerAfterReset) {
      _resumeTimerAfterReset = false;
      await init();
    }
  }

  @visibleForTesting
  void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _initialized = false;
    _resumeTimerAfterReset = false;
  }

  @visibleForTesting
  static bool isValidEvent(String eventName, Map<String, Object?> properties) {
    if (!eventNames.contains(eventName)) return false;
    final keys = properties.keys.toSet();
    switch (eventName) {
      case 'app_first_open':
        return keys.isEmpty;
      case 'first_subscriber_created':
        return _hasExactKeys(keys, {'method'}) &&
            _isEnum(properties['method'], {'manual', 'mso_import'});
      case 'mso_file_imported':
        return _hasExactKeys(keys, {
              'service_type',
              'record_count',
              'mso_format',
              'elapsed_ms',
              'inserted_count',
              'updated_count',
              'payment_count',
            }) &&
            _isEnum(properties['service_type'], {'tv', 'fiber'}) &&
            _isEnum(properties['mso_format'], {
              'book1',
              'active_packages',
              'total_list',
              'csv',
              'unknown',
            }) &&
            _isCount(properties['record_count']) &&
            _isCount(properties['elapsed_ms'], maximum: 86400000) &&
            _isCount(properties['inserted_count']) &&
            _isCount(properties['updated_count']) &&
            _isCount(properties['payment_count']);
      case 'payment_recorded':
        return _hasExactKeys(keys, {'service_type', 'has_adjustment'}) &&
            _isEnum(properties['service_type'], {'tv', 'fiber'}) &&
            properties['has_adjustment'] is bool;
      case 'whatsapp_receipt_dispatched':
        return _hasExactKeys(keys, {'service_type', 'used_web_fallback'}) &&
            _isEnum(properties['service_type'], {'tv', 'fiber'}) &&
            properties['used_web_fallback'] is bool;
      default:
        return false;
    }
  }

  static bool _hasExactKeys(Set<String> actual, Set<String> expected) =>
      actual.length == expected.length && actual.containsAll(expected);

  static bool _isEnum(Object? value, Set<String> allowed) =>
      value is String && allowed.contains(value);

  static bool _isCount(Object? value, {int maximum = 2147483647}) =>
      value is int && value >= 0 && value <= maximum;

  PreparedAnalyticsEvent? _prepareEvent(
    String eventName,
    Map<String, Object?> properties,
  ) {
    if (!isValidEvent(eventName, properties)) return null;
    final json = jsonEncode(properties);
    if (utf8.encode(json).length > _maxPropertiesBytes) return null;
    return PreparedAnalyticsEvent(
      eventId: _randomId(),
      eventName: eventName,
      propertiesJson: json,
      createdAt: _clock(),
    );
  }

  static Future<void> _deleteExpired(Transaction transaction, int now) {
    return transaction.delete(
      'analytics_events',
      where: 'created_at < ?',
      whereArgs: [now - _retention.inMilliseconds],
    );
  }

  static Future<bool> _insertPrepared(
    DatabaseExecutor transaction,
    PreparedAnalyticsEvent event, {
    String? milestone,
  }) async {
    if (milestone != null) {
      final claim = await transaction.rawInsert(
        'INSERT OR IGNORE INTO analytics_milestones (milestone, created_at) VALUES (?, ?)',
        [milestone, event.createdAt],
      );
      if (claim == 0) return false;
    }
    await transaction.insert('analytics_events', {
      'event_id': event.eventId,
      'event_name': event.eventName,
      'properties_json': event.propertiesJson,
      'created_at': event.createdAt,
      'attempt_count': 0,
      'next_attempt_at': 0,
    });
    return true;
  }

  /// Validates and stores a privacy-minimized event. It returns false when the
  /// event violates the local allowlist or the local store is unavailable.
  Future<bool> track(
    String eventName,
    Map<String, Object?> properties, {
    bool requestFlush = true,
  }) async {
    final event = _prepareEvent(eventName, properties);
    if (event == null) return false;
    try {
      final database = await _database;
      await database.transaction((transaction) async {
        await _deleteExpired(transaction, event.createdAt);
        await _insertPrepared(transaction, event);
      });
      if (requestFlush) unawaited(flushIfWifi());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Records the install's first launch with a durable SQLite claim in the
  /// same transaction as event insertion. Concurrent calls and crashes between
  /// those operations cannot create a duplicate or lose the claim.
  Future<void> recordAppFirstOpen() async {
    final event = _prepareEvent('app_first_open', const {});
    if (event == null) return;
    try {
      final database = await _database;
      await database.transaction((transaction) async {
        await _deleteExpired(transaction, event.createdAt);
        await _insertPrepared(transaction, event, milestone: 'app_first_open');
      });
      unawaited(flushIfWifi());
    } catch (_) {
      // Telemetry must never prevent application startup.
    }
  }

  /// Inserts a subscriber and claims/queues the first-subscriber milestone in
  /// one database transaction.
  Future<bool> trackFirstSubscriber(
    Subscriber subscriber,
    String method,
  ) async {
    final event = _prepareEvent('first_subscriber_created', {'method': method});
    if (event == null) return false;
    try {
      final database = await _database;
      await database.transaction((transaction) async {
        final count =
            Sqflite.firstIntValue(
              await transaction.rawQuery('SELECT COUNT(*) FROM subscribers'),
            ) ??
            0;
        await transaction.insert('subscribers', subscriber.toMap());
        if (count == 0) {
          await _insertPrepared(
            transaction,
            event,
            milestone: 'first_subscriber_created',
          );
        }
      });
      unawaited(flushIfWifi());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Adds the first-subscriber event to an existing caller-owned transaction,
  /// allowing import commit to claim it in the same transaction as the first
  /// subscriber insert without changing the import transaction boundary.
  Future<bool> insertFirstSubscriberEvent(
    Transaction transaction,
    String method,
  ) async {
    final event = _prepareEvent('first_subscriber_created', {'method': method});
    if (event == null) return false;
    return _insertPrepared(
      transaction,
      event,
      milestone: 'first_subscriber_created',
    );
  }

  /// Flushes one or more bounded batches. It is serialized to prevent parallel
  /// sends; concurrent requests coalesce into one follow-up pass.
  Future<void> flushIfWifi() async {
    if (_resetSuspended) return;
    if (_flushing) {
      _flushRequested = true;
      return;
    }
    _flushing = true;
    final completion = _flushCompletion = Completer<void>();
    try {
      do {
        _flushRequested = false;
        if (!await _isWifi()) break;
        while (await _flushOneBatch()) {}
      } while (_flushRequested && await _isWifi());
    } catch (_) {
      // Network, connectivity, and local failures retain the queue.
    } finally {
      _flushing = false;
      _flushCompletion = null;
      completion.complete();
    }
  }

  Future<bool> _flushOneBatch() async {
    final database = await _database;
    final now = _clock();
    await database.delete(
      'analytics_events',
      where: 'created_at < ?',
      whereArgs: [now - _retention.inMilliseconds],
    );
    final rows = await database.query(
      'analytics_events',
      where: 'next_attempt_at <= ?',
      whereArgs: [now],
      orderBy: 'created_at, id',
      limit: _maxEventsPerBatch,
    );
    if (rows.isEmpty) return false;

    final clientId = await _getClientId();
    if (clientId == null) return false;
    final events = rows
        .map((row) {
          return {
            'id': row['event_id'] as String,
            'event_name': row['event_name'] as String,
            'timestamp': row['created_at'] as int,
            'properties': jsonDecode(row['properties_json'] as String),
          };
        })
        .toList(growable: false);
    final body = Uint8List.fromList(
      gzip.encode(
        utf8.encode(jsonEncode({'client_id': clientId, 'events': events})),
      ),
    );

    TelemetryResponse response;
    try {
      response = await _sender(body);
    } on TimeoutException {
      await _recordFailure(rows, 'timeout');
      return false;
    } on SocketException {
      await _recordFailure(rows, 'network');
      return false;
    } on HttpException {
      await _recordFailure(rows, 'network');
      return false;
    } catch (_) {
      await _recordFailure(rows, 'network');
      return false;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final accepted = _acceptedIds(response.body);
      final requested = rows.map((row) => row['event_id'] as String).toSet();
      if (accepted == null ||
          accepted.isEmpty ||
          !requested.containsAll(accepted)) {
        await _recordFailure(rows, 'invalid_response');
        return false;
      }
      await _deleteExact(rows, accepted);
      return true;
    }
    if (response.statusCode >= 400 && response.statusCode < 500) {
      if (response.statusCode == 408 ||
          response.statusCode == 425 ||
          response.statusCode == 429) {
        await _recordFailure(rows, 'retryable_http');
        return false;
      }
      await _deleteExact(rows, requestedIds(rows));
      return true;
    }
    if (response.statusCode >= 300 && response.statusCode < 400) {
      await _recordFailure(rows, 'redirect_http');
      return false;
    }
    await _recordFailure(
      rows,
      response.statusCode >= 500 ? 'retryable_http' : 'http_error',
    );
    return false;
  }

  Future<String?> _getClientId() async {
    try {
      final preferences = await _preferences();
      final existing = preferences.getString(_clientIdKey);
      if (existing != null &&
          RegExp(r'^anon_[0-9a-f]{32}$').hasMatch(existing)) {
        return existing;
      }
      final generated = 'anon_${_randomId()}';
      final stored = await _storeClientId(_clientIdKey, generated);
      return stored ? generated : null;
    } catch (_) {
      return null;
    }
  }

  static Set<String>? _acceptedIds(String body) {
    try {
      final value = jsonDecode(body);
      if (value is! Map<String, dynamic>) return null;
      final ids = value['accepted_event_ids'];
      if (ids is! List || ids.any((id) => id is! String)) return null;
      return ids.cast<String>().toSet();
    } catch (_) {
      return null;
    }
  }

  static Set<String> requestedIds(List<Map<String, Object?>> rows) =>
      rows.map((row) => row['event_id'] as String).toSet();

  Future<void> _recordFailure(
    List<Map<String, Object?>> rows,
    String errorCode,
  ) async {
    final database = await _database;
    final now = _clock();
    await database.transaction((transaction) async {
      for (final row in rows) {
        final attempt = (row['attempt_count'] as int? ?? 0) + 1;
        final delay = min(3600000, 60000 * (1 << min(attempt - 1, 6)));
        await transaction.update(
          'analytics_events',
          {
            'attempt_count': attempt,
            'next_attempt_at': now + delay,
            'last_error': errorCode,
          },
          where: 'event_id = ?',
          whereArgs: [row['event_id']],
        );
      }
    });
  }

  Future<void> _deleteExact(
    List<Map<String, Object?>> rows,
    Set<String> eventIds,
  ) async {
    if (eventIds.isEmpty) return;
    final database = await _database;
    await database.transaction((transaction) async {
      for (final id in eventIds) {
        await transaction.delete(
          'analytics_events',
          where: 'event_id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  static String _randomId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }
}
