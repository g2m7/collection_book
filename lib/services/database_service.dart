import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/area.dart';
import '../models/subscriber.dart';
import '../models/payment.dart';
import '../models/import_run.dart';
import '../models/import_result.dart';
import 'backup_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;
  DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'rent_ledger.db');
    return openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE subscribers RENAME TO subscribers_old');
      await db.execute('''
        CREATE TABLE subscribers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          area_id INTEGER,
          name TEXT NOT NULL,
          alias_name TEXT,
          vc_number TEXT,
          monthly_rent REAL NOT NULL DEFAULT 0,
          previous_due REAL NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL DEFAULT (datetime('now')),
          FOREIGN KEY (area_id) REFERENCES areas(id)
        )
      ''');
      await db.execute('''
        INSERT INTO subscribers (id, area_id, name, alias_name, vc_number, monthly_rent, previous_due, is_active, created_at)
        SELECT id, area_id, name, alias_name, vc_number, monthly_rent, previous_due, is_active, created_at FROM subscribers_old
      ''');
      await db.execute('DROP TABLE subscribers_old');
      await db.execute(
        'CREATE INDEX idx_subscribers_area ON subscribers(area_id)',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE subscribers ADD COLUMN service_type TEXT NOT NULL DEFAULT 'tv'",
      );
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE subscribers ADD COLUMN start_year INTEGER');
      await db.execute(
        'ALTER TABLE subscribers ADD COLUMN start_month INTEGER',
      );
    }
    if (oldVersion < 5) {
      // Add Internet-specific identifier columns
      await db.execute('ALTER TABLE subscribers ADD COLUMN account_id TEXT');
      await db.execute('ALTER TABLE subscribers ADD COLUMN username TEXT');
      await db.execute('ALTER TABLE subscribers ADD COLUMN phone TEXT');
      // Remediate legacy 'both' rows → default to 'tv'
      await db.execute(
        "UPDATE subscribers SET service_type = 'tv' WHERE service_type = 'both'",
      );
    }
    if (oldVersion < 6) {
      await _createImportTables(db);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE areas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE subscribers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        area_id INTEGER,
        name TEXT NOT NULL,
        alias_name TEXT,
        vc_number TEXT,
        monthly_rent REAL NOT NULL DEFAULT 0,
        previous_due REAL NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        service_type TEXT NOT NULL DEFAULT 'tv',
        start_year INTEGER,
        start_month INTEGER,
        account_id TEXT,
        username TEXT,
        phone TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (area_id) REFERENCES areas(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subscriber_id INTEGER NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        amount_paid REAL NOT NULL DEFAULT 0,
        adjustment REAL NOT NULL DEFAULT 0,
        adjustment_note TEXT,
        recorded_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (subscriber_id) REFERENCES subscribers(id),
        UNIQUE(subscriber_id, year, month)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_payments_subscriber ON payments(subscriber_id, year, month)',
    );
    await db.execute(
      'CREATE INDEX idx_subscribers_area ON subscribers(area_id)',
    );

    await _createImportTables(db);
  }

  Future<void> _createImportTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS import_runs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_name TEXT NOT NULL,
        service_type TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'success',
        insert_count INTEGER NOT NULL DEFAULT 0,
        update_count INTEGER NOT NULL DEFAULT 0,
        reject_count INTEGER NOT NULL DEFAULT 0,
        conflict_count INTEGER NOT NULL DEFAULT 0,
        payment_count INTEGER NOT NULL DEFAULT 0,
        started_at TEXT NOT NULL DEFAULT (datetime('now')),
        completed_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS import_errors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        run_id INTEGER NOT NULL,
        row_number INTEGER NOT NULL,
        source_column TEXT,
        reason TEXT NOT NULL,
        severity TEXT NOT NULL DEFAULT 'error',
        FOREIGN KEY (run_id) REFERENCES import_runs(id)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_import_errors_run ON import_errors(run_id)',
    );
  }

  // --------------- AREAS ---------------

  Future<int> insertArea(Area area) async {
    final db = await database;
    return db.insert(
      'areas',
      area.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Area>> getAreas() async {
    final db = await database;
    final maps = await db.query('areas', orderBy: 'name');
    return maps.map((m) => Area.fromMap(m)).toList();
  }

  Future<void> updateArea(Area area) async {
    final db = await database;
    await db.update(
      'areas',
      area.toMap(),
      where: 'id = ?',
      whereArgs: [area.id],
    );
  }

  Future<void> deleteArea(int id) async {
    final db = await database;
    await db.delete('areas', where: 'id = ?', whereArgs: [id]);
  }

  // --------------- SUBSCRIBERS ---------------

  Future<int> insertSubscriber(Subscriber subscriber) async {
    final db = await database;
    return db.insert('subscribers', subscriber.toMap());
  }

  Future<void> updateSubscriber(Subscriber subscriber) async {
    final db = await database;
    await db.update(
      'subscribers',
      subscriber.toMap(),
      where: 'id = ?',
      whereArgs: [subscriber.id],
    );
  }

  Future<void> deleteSubscriber(int id) async {
    final db = await database;
    await db.delete('payments', where: 'subscriber_id = ?', whereArgs: [id]);
    await db.delete('subscribers', where: 'id = ?', whereArgs: [id]);
  }

  Future<Subscriber?> getSubscriber(int id) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT s.*, a.name as area_name
      FROM subscribers s
      LEFT JOIN areas a ON s.area_id = a.id
      WHERE s.id = ?
    ''',
      [id],
    );
    if (maps.isEmpty) return null;
    return Subscriber.fromMap(maps.first);
  }

  /// [serviceType] — pass 'tv' or 'fiber' to filter; null means no filter.
  Future<List<Subscriber>> getSubscribers({
    int? areaId,
    bool? isActive,
    String? search,
    int? year,
    int? month,
    String? filter,
    String? serviceType,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];

    if (areaId != null) {
      where.add('s.area_id = ?');
      args.add(areaId);
    }
    if (isActive != null) {
      where.add('s.is_active = ?');
      args.add(isActive ? 1 : 0);
    }
    if (search != null && search.isNotEmpty) {
      where.add('(s.name LIKE ? OR s.alias_name LIKE ? OR s.vc_number LIKE ?)');
      args.addAll(['%$search%', '%$search%', '%$search%']);
    }
    if (serviceType != null) {
      where.add('s.service_type = ?');
      args.add(serviceType);
    }

    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final y = year ?? DateTime.now().year;
    final m = month ?? DateTime.now().month;

    final rows = await db.rawQuery(
      '''
      SELECT s.*, a.name as area_name,
        (
          s.previous_due
          + (
              CASE
                WHEN ((? - CAST(strftime('%Y', s.created_at) AS INTEGER)) * 12
                  + (? - CAST(strftime('%m', s.created_at) AS INTEGER)) + 1) > 0
                THEN ((? - CAST(strftime('%Y', s.created_at) AS INTEGER)) * 12
                  + (? - CAST(strftime('%m', s.created_at) AS INTEGER)) + 1)
                ELSE 0
              END
            ) * s.monthly_rent
          + COALESCE((
              SELECT SUM(p2.adjustment) FROM payments p2
              WHERE p2.subscriber_id = s.id
                AND (
                  p2.year > CAST(strftime('%Y', s.created_at) AS INTEGER)
                  OR (
                    p2.year = CAST(strftime('%Y', s.created_at) AS INTEGER)
                    AND p2.month >= CAST(strftime('%m', s.created_at) AS INTEGER)
                  )
                )
                AND (
                  p2.year < ?
                  OR (p2.year = ? AND p2.month <= ?)
                )
            ), 0)
          - COALESCE((
              SELECT SUM(p3.amount_paid) FROM payments p3
              WHERE p3.subscriber_id = s.id
                AND (
                  p3.year > CAST(strftime('%Y', s.created_at) AS INTEGER)
                  OR (
                    p3.year = CAST(strftime('%Y', s.created_at) AS INTEGER)
                    AND p3.month >= CAST(strftime('%m', s.created_at) AS INTEGER)
                  )
                )
                AND (
                  p3.year < ?
                  OR (p3.year = ? AND p3.month <= ?)
                )
            ), 0)
        ) as current_due
      FROM subscribers s
      LEFT JOIN areas a ON s.area_id = a.id
      $whereClause
      ORDER BY a.name, s.name
    ''',
      [y, m, y, m, y, y, m, y, y, m, ...args],
    );

    var subscribers = rows.map((r) => Subscriber.fromMap(r)).toList();

    if (filter == 'paid') {
      subscribers = subscribers.where((s) => (s.currentDue ?? 0) <= 0).toList();
    } else if (filter == 'unpaid') {
      subscribers = subscribers.where((s) => (s.currentDue ?? 0) > 0).toList();
    } else if (filter == 'overpaid') {
      subscribers = subscribers.where((s) => (s.currentDue ?? 0) < 0).toList();
    }

    return subscribers;
  }

  // --------------- IMPORT: SERVICE-BOUND UPSERT ---------------

  /// Find a subscriber by strong ID within a specific service type.
  /// Returns null if no match. Never crosses service boundaries.
  Future<int?> findSubscriberByStrongId(
    String serviceType,
    String? vcNumber,
    String? accountId,
    String? username,
    String? phone,
  ) async {
    final db = await database;
    if (serviceType == 'tv' && vcNumber != null && vcNumber.isNotEmpty) {
      final r = await db.rawQuery(
        'SELECT id FROM subscribers WHERE vc_number = ? AND service_type = ?',
        [vcNumber, serviceType],
      );
      if (r.isNotEmpty) return r.first['id'] as int;
    }
    if (serviceType == 'fiber') {
      if (accountId != null && accountId.isNotEmpty) {
        final r = await db.rawQuery(
          'SELECT id FROM subscribers WHERE account_id = ? AND service_type = ?',
          [accountId, serviceType],
        );
        if (r.isNotEmpty) return r.first['id'] as int;
      }
      if (username != null && username.isNotEmpty) {
        final r = await db.rawQuery(
          'SELECT id FROM subscribers WHERE username = ? AND service_type = ?',
          [username, serviceType],
        );
        if (r.isNotEmpty) return r.first['id'] as int;
      }
      if (phone != null && phone.isNotEmpty) {
        final r = await db.rawQuery(
          'SELECT id FROM subscribers WHERE phone = ? AND service_type = ?',
          [phone, serviceType],
        );
        if (r.isNotEmpty) return r.first['id'] as int;
      }
    }
    return null;
  }

  /// Check if a strong ID exists in the OPPOSITE service (cross-service conflict).
  Future<bool> hasConflictInOppositeService(
    String serviceType,
    String? vcNumber,
    String? accountId,
    String? username,
  ) async {
    final db = await database;
    final opposite = serviceType == 'tv' ? 'fiber' : 'tv';

    if (vcNumber != null && vcNumber.isNotEmpty) {
      final r = await db.rawQuery(
        'SELECT 1 FROM subscribers WHERE vc_number = ? AND service_type = ?',
        [vcNumber, opposite],
      );
      if (r.isNotEmpty) return true;
    }
    if (accountId != null && accountId.isNotEmpty) {
      final r = await db.rawQuery(
        'SELECT 1 FROM subscribers WHERE account_id = ? AND service_type = ?',
        [accountId, opposite],
      );
      if (r.isNotEmpty) return true;
    }
    if (username != null && username.isNotEmpty) {
      final r = await db.rawQuery(
        'SELECT 1 FROM subscribers WHERE username = ? AND service_type = ?',
        [username, opposite],
      );
      if (r.isNotEmpty) return true;
    }
    return false;
  }

  /// Fallback: find by name within the same service type.
  Future<int?> findSubscriberByName(String name, String serviceType) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT id FROM subscribers WHERE name = ? AND service_type = ?',
      [name, serviceType],
    );
    return r.isEmpty ? null : r.first['id'] as int;
  }

  // --------------- PAYMENTS ---------------

  Future<int> insertOrUpdatePayment(Payment payment) async {
    final db = await database;
    final existing = await db.query(
      'payments',
      where: 'subscriber_id = ? AND year = ? AND month = ?',
      whereArgs: [payment.subscriberId, payment.year, payment.month],
    );

    int result;
    if (existing.isNotEmpty) {
      result = existing.first['id'] as int;
      await db.update(
        'payments',
        payment.toMap(),
        where: 'id = ?',
        whereArgs: [result],
      );
    } else {
      result = await db.insert('payments', payment.toMap());
    }

    BackupService().autoBackup();
    return result;
  }

  Future<List<Payment>> getPaymentsForSubscriber(
    int subscriberId, {
    int? year,
  }) async {
    final db = await database;
    final w = 'subscriber_id = ?${year != null ? ' AND year = ?' : ''}';
    final a = <dynamic>[subscriberId];
    if (year != null) a.add(year);

    final maps = await db.query(
      'payments',
      where: w,
      whereArgs: a,
      orderBy: 'year, month',
    );
    return maps.map((m) => Payment.fromMap(m)).toList();
  }

  Future<Payment?> getPayment(int subscriberId, int year, int month) async {
    final db = await database;
    final maps = await db.query(
      'payments',
      where: 'subscriber_id = ? AND year = ? AND month = ?',
      whereArgs: [subscriberId, year, month],
    );
    if (maps.isEmpty) return null;
    return Payment.fromMap(maps.first);
  }

  Future<void> deletePayment(int id) async {
    final db = await database;
    await db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }

  // --------------- DUE CALCULATION ---------------

  Future<double> getYearStartBalance(int subscriberId, int year) async {
    final sub = await getSubscriber(subscriberId);
    if (sub == null) return 0;

    final created = _parseCreatedAt(sub.createdAt);
    final startYear = created?.year ?? DateTime.now().year;
    final startMonth = created?.month ?? 1;

    if (year <= startYear) return sub.previousDue;

    final monthsCharged = (year - 1 - startYear) * 12 + (12 - startMonth + 1);

    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(amount_paid), 0) AS total_paid,
        COALESCE(SUM(adjustment),  0) AS total_adj
      FROM payments
      WHERE subscriber_id = ?
        AND (
          year > ? OR (year = ? AND month >= ?)
        )
        AND year < ?
    ''',
      [subscriberId, startYear, startYear, startMonth, year],
    );

    final totalPaid = (result.first['total_paid'] as num).toDouble();
    final totalAdj = (result.first['total_adj'] as num).toDouble();

    return sub.previousDue +
        monthsCharged * sub.monthlyRent +
        totalAdj -
        totalPaid;
  }

  Future<double> calculateDue(int subscriberId, int year, int month) async {
    final db = await database;
    final sub = await getSubscriber(subscriberId);
    if (sub == null) return 0;

    final created = _parseCreatedAt(sub.createdAt);
    final startYear = created?.year ?? year;
    final startMonth = created?.month ?? month;
    final months = _monthsBetweenInclusive(startYear, startMonth, year, month);
    final totalRent = sub.monthlyRent * months;
    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(amount_paid), 0) as total_paid,
        COALESCE(SUM(adjustment), 0) as total_adj
      FROM payments
      WHERE subscriber_id = ?
        AND (
          year > ? OR (year = ? AND month >= ?)
        )
        AND (
          year < ? OR (year = ? AND month <= ?)
        )
    ''',
      [subscriberId, startYear, startYear, startMonth, year, year, month],
    );

    final totalPaid = (result.first['total_paid'] as num).toDouble();
    final totalAdj = (result.first['total_adj'] as num).toDouble();

    return sub.previousDue + totalRent + totalAdj - totalPaid;
  }

  // --------------- DASHBOARD ---------------

  /// [serviceType] — 'tv' or 'fiber' to scope dashboard; null = all.
  Future<Map<String, dynamic>> getDashboardSummary(
    int year,
    int month, {
    String? serviceType,
  }) async {
    final db = await database;

    final serviceFilter = serviceType != null
        ? "AND s.service_type = '$serviceType'"
        : '';

    const startedByMonthFilter = '''
      AND (
        CAST(strftime('%Y', s.created_at) AS INTEGER) < ?
        OR (
          CAST(strftime('%Y', s.created_at) AS INTEGER) = ?
          AND CAST(strftime('%m', s.created_at) AS INTEGER) <= ?
        )
      )
    ''';

    final subscriberCount = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM subscribers s WHERE s.is_active = 1 $serviceFilter $startedByMonthFilter',
        [year, year, month],
      ),
    );

    final paymentData = await db.rawQuery(
      '''
      SELECT
        COUNT(DISTINCT p.subscriber_id) as paid_count,
        COALESCE(SUM(p.amount_paid), 0) as total_collected,
        COALESCE(SUM(p.adjustment), 0) as total_adjustment
      FROM payments p
      JOIN subscribers s ON p.subscriber_id = s.id
      WHERE p.year = ? AND p.month = ?
        AND s.is_active = 1
        $serviceFilter
        $startedByMonthFilter
    ''',
      [year, month, year, year, month],
    );

    final totalAdjustment =
        (paymentData.first['total_adjustment'] as num?)?.toDouble() ?? 0;

    final totalExpected = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COALESCE(SUM(s.monthly_rent), 0) FROM subscribers s WHERE s.is_active = 1 $serviceFilter $startedByMonthFilter',
        [year, year, month],
      ),
    );

    final paidCount = (paymentData.first['paid_count'] as num?)?.toInt() ?? 0;
    final totalCollected =
        (paymentData.first['total_collected'] as num?)?.toDouble() ?? 0;
    final netExpected = (totalExpected ?? 0).toDouble() + totalAdjustment;

    return {
      'subscriber_count': subscriberCount ?? 0,
      'paid_count': paidCount,
      'unpaid_count': (subscriberCount ?? 0) - paidCount,
      'total_collected': totalCollected,
      'total_expected': netExpected,
      'collection_rate': (subscriberCount ?? 0) > 0
          ? (paidCount / (subscriberCount ?? 1) * 100)
          : 0.0,
    };
  }

  /// [serviceType] — 'tv' or 'fiber' to scope area summary; null = all.
  Future<List<Map<String, dynamic>>> getAreaSummary(
    int year,
    int month, {
    String? serviceType,
  }) async {
    final db = await database;
    final serviceFilter = serviceType != null
        ? "AND s.service_type = '$serviceType'"
        : '';

    return db.rawQuery(
      '''
      SELECT
        a.id as area_id,
        a.name as area_name,
        COUNT(s.id) as subscriber_count,
        COALESCE(SUM(s.monthly_rent), 0) as total_rent,
        COALESCE((
          SELECT SUM(p.amount_paid) FROM payments p
          WHERE p.subscriber_id IN (
            SELECT id FROM subscribers WHERE area_id = a.id AND is_active = 1 $serviceFilter
          )
          AND p.year = ? AND p.month = ?
        ), 0) as total_collected,
        COALESCE((
          SELECT COUNT(DISTINCT p.subscriber_id) FROM payments p
          WHERE p.subscriber_id IN (
            SELECT id FROM subscribers WHERE area_id = a.id AND is_active = 1 $serviceFilter
          )
          AND p.year = ? AND p.month = ?
        ), 0) as paid_count
      FROM areas a
      LEFT JOIN subscribers s ON s.area_id = a.id AND s.is_active = 1 $serviceFilter
      GROUP BY a.id
      ORDER BY a.name
    ''',
      [year, month, year, month],
    );
  }

  // --------------- IMPORT HISTORY ---------------

  Future<int> insertImportRun(ImportRun run) async {
    final db = await database;
    return db.insert('import_runs', run.toMap());
  }

  Future<void> updateImportRun(ImportRun run) async {
    final db = await database;
    await db.update(
      'import_runs',
      run.toMap(),
      where: 'id = ?',
      whereArgs: [run.id],
    );
  }

  Future<List<ImportRun>> getImportRuns() async {
    final db = await database;
    final maps = await db.query('import_runs', orderBy: 'started_at DESC');
    return maps.map((m) => ImportRun.fromMap(m)).toList();
  }

  Future<void> insertImportErrors(
    int runId,
    List<ImportRowError> errors,
  ) async {
    final db = await database;
    final batch = db.batch();
    for (final error in errors) {
      batch.insert('import_errors', {'run_id': runId, ...error.toMap()});
    }
    await batch.commit(noResult: true);
  }

  Future<List<ImportRowError>> getImportErrors(int runId) async {
    final db = await database;
    final maps = await db.query(
      'import_errors',
      where: 'run_id = ?',
      whereArgs: [runId],
      orderBy: 'row_number',
    );
    return maps.map((m) => ImportRowError.fromMap(m)).toList();
  }

  // --------------- UTILITIES ---------------

  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return p.join(dbPath, 'rent_ledger.db');
  }

  Future<void> closeDb() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  Future<void> replaceDatabase(String sourcePath) async {
    await closeDb();
    final targetPath = await getDatabasePath();
    final sourceFile = File(sourcePath);
    final targetFile = File(targetPath);
    if (await targetFile.exists()) await targetFile.delete();
    await sourceFile.copy(targetPath);
    _db = await openDatabase(targetPath);
  }

  DateTime? _parseCreatedAt(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value) ??
        DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }

  int _monthsBetweenInclusive(
    int startYear,
    int startMonth,
    int endYear,
    int endMonth,
  ) {
    final count = (endYear - startYear) * 12 + (endMonth - startMonth) + 1;
    return count > 0 ? count : 0;
  }
}
