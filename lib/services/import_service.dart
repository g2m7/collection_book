import 'dart:io';
import 'package:excel/excel.dart';
import 'package:html/parser.dart' as html_parser;
import 'database_service.dart';

// ---------------------------------------------------------------------------
// Public surface
// ---------------------------------------------------------------------------

enum ImportFormat { book1, activePackages, totalList, unknown }

class ImportPreview {
  final ImportFormat format;
  // ignore: library_private_types_in_public_api
  final List<_SubRecord> records;

  const ImportPreview({required this.format, required this.records});

  int get subscriberCount => records.length;
  int get paymentCount =>
      records.fold(0, (s, r) => s + r.payments.length);

  String get formatLabel => switch (format) {
        ImportFormat.book1 => 'Book1 ledger (subscribers + payments)',
        ImportFormat.activePackages => 'Operator active-packages report',
        ImportFormat.totalList => 'Operator total-subscriber report',
        ImportFormat.unknown => 'Unknown format',
      };
}

class ImportResult {
  final int inserted;
  final int updated;
  final int payments;

  const ImportResult({
    required this.inserted,
    required this.updated,
    required this.payments,
  });
}

class ImportService {
  final _db = DatabaseService();

  /// Detect format + parse file into an in-memory preview (no DB writes).
  Future<ImportPreview> preview(String path) async {
    final bytes = await File(path).readAsBytes();
    final lower = path.toLowerCase();

    if (lower.endsWith('.xlsx')) {
      return _parseBook1Xlsx(bytes);
    }

    // .xls files from this operator are HTML tables — detect subtype by headers
    final text = String.fromCharCodes(bytes);
    if (text.contains('STB_NUMBER') || text.contains('START_DATE')) {
      return _parseActivePackagesHtml(text);
    }
    if (text.contains('STB_ISSUE_DATE')) {
      return _parseTotalListHtml(text);
    }
    return ImportPreview(format: ImportFormat.unknown, records: []);
  }

  /// Write the already-parsed preview into the DB.
  Future<ImportResult> commit(ImportPreview preview) async {
    final db = await _db.database;
    int inserted = 0, updated = 0, payments = 0;

    for (final rec in preview.records) {
      if (rec.name == null && rec.vc == null) continue;

      // Upsert area via raw insert (ignore conflict), then resolve id
      final resolvedAreaId = rec.area != null
          ? await _resolveAreaId(rec.area!)
          : null;

      final existingId = await _findSubscriber(rec.vc, rec.name ?? '');

      if (existingId != null) {
        await db.execute('''
          UPDATE subscribers SET
            area_id     = COALESCE(?, area_id),
            alias_name  = COALESCE(?, alias_name),
            monthly_rent = COALESCE(NULLIF(?, 0), monthly_rent),
            previous_due = COALESCE(?, previous_due),
            start_year  = COALESCE(?, start_year),
            start_month = COALESCE(?, start_month)
          WHERE id = ?
        ''', [
          resolvedAreaId,
          rec.alias,
          rec.rent,
          rec.prevDue,
          rec.startYear,
          rec.startMonth,
          existingId,
        ]);
        updated++;
        _upsertPayments(db, existingId, rec.payments);
        payments += rec.payments.length;
      } else {
        if (rec.name == null) continue;
        final id = await db.rawInsert('''
          INSERT INTO subscribers
            (area_id, name, alias_name, vc_number, monthly_rent,
             previous_due, is_active, service_type, start_year, start_month)
          VALUES (?, ?, ?, ?, ?, ?, 1, 'tv', ?, ?)
        ''', [
          resolvedAreaId,
          rec.name,
          rec.alias,
          rec.vc,
          rec.rent ?? 0,
          rec.prevDue ?? 0,
          rec.startYear,
          rec.startMonth,
        ]);
        inserted++;
        _upsertPayments(db, id, rec.payments);
        payments += rec.payments.length;
      }
    }

    return ImportResult(
        inserted: inserted, updated: updated, payments: payments);
  }

  // ---------------------------------------------------------------------------
  // Book1 xlsx parser
  // ---------------------------------------------------------------------------

  static const _book1Year = 2025;

  // Col indices: {month: (paidCol, adjCol)}
  static const _monthCols = {
    1: (7, 9),
    2: (10, -1),
    3: (14, -1),
    4: (18, 17),
    5: (22, 21),
    6: (25, 24),
    7: (29, 28),
    8: (35, 34),
    9: (40, 39),
    10: (48, 47),
    11: (51, 50),
    12: (56, 55),
  };

  ImportPreview _parseBook1Xlsx(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables['Sheet1'] ?? excel.tables.values.first;
    final rows = sheet.rows;

    String? currentArea;
    final records = <_SubRecord>[];

    for (int i = 0; i < rows.length; i++) {
      if (i < 3) continue; // skip header rows
      final row = rows[i];

      // Forward-fill area (col 0) — but ignore the "AREA" header label
      final areaCell = _str(row, 0);
      if (areaCell != null && areaCell.toUpperCase() != 'AREA') {
        currentArea = areaCell;
      }

      final name = _str(row, 3);
      final vc   = _vcStr(row, 4);
      if (name == null && vc == null) continue;

      final alias   = _str(row, 2);
      final rent    = _num(row, 5) ?? 0;
      final prevDue = _num(row, 6) ?? 0;

      final payments = <int, _Payment>{};
      int? firstPayMonth;

      for (final entry in _monthCols.entries) {
        final month = entry.key;
        final paidCol = entry.value.$1;
        final adjCol  = entry.value.$2;

        final paid = _num(row, paidCol);
        final adj  = adjCol >= 0 ? (_num(row, adjCol) ?? 0.0) : 0.0;

        if (paid != null) {
          payments[month] = _Payment(paid: paid, adj: adj);
          firstPayMonth ??= month;
        }
      }

      records.add(_SubRecord(
        name:       name,
        alias:      alias,
        vc:         vc,
        area:       currentArea,
        rent:       rent,
        prevDue:    prevDue,
        startYear:  firstPayMonth != null ? _book1Year : null,
        startMonth: firstPayMonth,
        payments:   payments,
      ));
    }

    return ImportPreview(format: ImportFormat.book1, records: records);
  }

  // ---------------------------------------------------------------------------
  // Operator HTML-XLS parsers
  // ---------------------------------------------------------------------------

  ImportPreview _parseActivePackagesHtml(String html) {
    final rows = _htmlRows(html);
    if (rows.isEmpty) {
      return ImportPreview(format: ImportFormat.activePackages, records: []);
    }

    final headers = rows.first;
    final idx = _headerMap(headers);
    final records = <_SubRecord>[];
    final seen = <String>{};

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= 1) continue;

      final planType = _col(row, idx['PLAN_TYPE']);
      if (planType != null && planType != 'BASE') continue;

      final vc   = _cleanVc(_col(row, idx['STB_NUMBER']) ?? _col(row, idx['VC_CARD']));
      final name = _cleanName(_col(row, idx['NAME']));
      if (vc == null && name == null) continue;

      final key = vc ?? name!;
      if (seen.contains(key)) continue;
      seen.add(key);

      final startDate = _parseDate(_col(row, idx['START_DATE']));
      final area      = _col(row, idx['ADDRESS3'])?.trim();
      final status    = _col(row, idx['STATUS'])?.toUpperCase() == 'ACTIVE';

      records.add(_SubRecord(
        name:       name,
        vc:         vc,
        area:       area?.isNotEmpty == true ? area : null,
        startYear:  startDate?.year,
        startMonth: startDate?.month,
        isActive:   status,
      ));
    }

    return ImportPreview(format: ImportFormat.activePackages, records: records);
  }

  ImportPreview _parseTotalListHtml(String html) {
    final rows = _htmlRows(html);
    if (rows.isEmpty) {
      return ImportPreview(format: ImportFormat.totalList, records: []);
    }

    final headers = rows.first;
    final idx = _headerMap(headers);
    final records = <_SubRecord>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= 1) continue;

      final vc   = _cleanVc(_col(row, idx['VC_CARD']));
      final name = _cleanName(_col(row, idx['NAME']));
      if (vc == null && name == null) continue;

      final startDate = _parseDate(_col(row, idx['STB_ISSUE_DATE']));
      final area      = _col(row, idx['ADDRESS3'])?.trim();
      final status    = _col(row, idx['STATUS'])?.toUpperCase() == 'ACTIVE';

      records.add(_SubRecord(
        name:       name,
        vc:         vc,
        area:       area?.isNotEmpty == true ? area : null,
        startYear:  startDate?.year,
        startMonth: startDate?.month,
        isActive:   status,
      ));
    }

    return ImportPreview(format: ImportFormat.totalList, records: records);
  }

  // ---------------------------------------------------------------------------
  // HTML helpers
  // ---------------------------------------------------------------------------

  List<List<String>> _htmlRows(String html) {
    final doc  = html_parser.parse(html);
    final trs  = doc.querySelectorAll('tr');
    return trs
        .map((tr) =>
            tr.querySelectorAll('td, th').map((c) => c.text.trim()).toList())
        .where((r) => r.isNotEmpty)
        .toList();
  }

  Map<String, int> _headerMap(List<String> headers) {
    final map = <String, int>{};
    for (int i = 0; i < headers.length; i++) {
      map[headers[i].toUpperCase()] = i;
    }
    return map;
  }

  String? _col(List<String> row, int? idx) {
    if (idx == null || idx >= row.length) return null;
    final v = row[idx].trim();
    return v.isEmpty ? null : v;
  }

  // ---------------------------------------------------------------------------
  // Excel cell helpers  (avoid .toString() on CellValue — can return TextSpan)
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Excel cell helpers
  // In excel 4.x, TextCellValue.value is a TextSpan (not String).
  // TextSpan.toString() concatenates all text runs correctly.
  // ---------------------------------------------------------------------------

  String? _cellRawString(CellValue? v) {
    if (v == null) return null;
    // TextCellValue.value is TextSpan — use toString() to get plain text
    if (v is TextCellValue)   return v.value.toString();
    if (v is IntCellValue)    return v.value.toString();
    if (v is DoubleCellValue) return v.value.toStringAsFixed(0);
    return null;
  }

  String? _str(List<Data?> row, int col) {
    if (col >= row.length) return null;
    final s = _cellRawString(row[col]?.value)
        ?.trim()
        .replaceAll(RegExp(r"^'+|'+$"), '');
    return (s == null || s.isEmpty) ? null : s;
  }

  String? _vcStr(List<Data?> row, int col) {
    if (col >= row.length) return null;
    final v = row[col]?.value;
    if (v == null) return null;
    if (v is IntCellValue)    return v.value.toString();
    if (v is DoubleCellValue) return v.value.toStringAsFixed(0);
    if (v is TextCellValue) {
      final s = v.value.toString().trim().replaceAll(RegExp(r"^'+|'+$"), '');
      if (s.isEmpty) return null;
      // Normalise scientific notation (e.g. "1.39e+10")
      final d = double.tryParse(s);
      if (d != null && s.toLowerCase().contains('e')) {
        return d.toStringAsFixed(0);
      }
      return s;
    }
    return null;
  }

  double? _num(List<Data?> row, int col) {
    if (col >= row.length) return null;
    final v = row[col]?.value;
    if (v == null) return null;
    if (v is IntCellValue)    return v.value.toDouble();
    if (v is DoubleCellValue) return v.value;
    if (v is TextCellValue)   return double.tryParse(v.value.toString());
    return null;
  }

  // ---------------------------------------------------------------------------
  // Shared string cleaners
  // ---------------------------------------------------------------------------

  String? _cleanName(String? s) {
    if (s == null) return null;
    final clean = s.trim().replaceAll(RegExp(r"^'+|'+$"), '');
    return clean.isEmpty ? null : clean;
  }

  String? _cleanVc(String? s) {
    if (s == null) return null;
    final clean = s.trim().replaceAll(RegExp(r"^'+|'+$"), '');
    if (clean.isEmpty) return null;
    final d = double.tryParse(clean);
    if (d != null && clean.toLowerCase().contains('e')) {
      return d.toStringAsFixed(0);
    }
    return clean;
  }

  DateTime? _parseDate(String? s) {
    if (s == null) return null;
    try {
      final parts = s.split('/');
      if (parts.length == 3) {
        return DateTime(int.parse(parts[2]), int.parse(parts[1]),
            int.parse(parts[0]));
      }
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------------------
  // DB helpers
  // ---------------------------------------------------------------------------

  Future<int?> _resolveAreaId(String name) async {
    final db = await _db.database;
    await db.rawInsert(
        'INSERT OR IGNORE INTO areas (name) VALUES (?)', [name]);
    final rows =
        await db.rawQuery('SELECT id FROM areas WHERE name = ?', [name]);
    return rows.isEmpty ? null : rows.first['id'] as int?;
  }

  Future<int?> _findSubscriber(String? vc, String name) async {
    final db = await _db.database;
    if (vc != null) {
      final r = await db
          .rawQuery('SELECT id FROM subscribers WHERE vc_number = ?', [vc]);
      if (r.isNotEmpty) return r.first['id'] as int;
    }
    final r = await db
        .rawQuery('SELECT id FROM subscribers WHERE name = ?', [name]);
    return r.isEmpty ? null : r.first['id'] as int;
  }

  void _upsertPayments(dynamic db, int subId, Map<int, _Payment> payments) {
    for (final entry in payments.entries) {
      final month = entry.key;
      final p     = entry.value;
      if (p.paid == 0 && p.adj == 0) continue;
      db.rawInsert('''
        INSERT INTO payments
          (subscriber_id, year, month, amount_paid, adjustment)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(subscriber_id, year, month) DO UPDATE SET
          amount_paid = excluded.amount_paid,
          adjustment  = excluded.adjustment
      ''', [subId, _book1Year, month, p.paid, p.adj]);
    }
  }
}

// ---------------------------------------------------------------------------
// Internal data classes
// ---------------------------------------------------------------------------

class _SubRecord {
  final String? name;
  final String? alias;
  final String? vc;
  final String? area;
  final double? rent;
  final double? prevDue;
  final int? startYear;
  final int? startMonth;
  final bool? isActive;
  final Map<int, _Payment> payments;

  const _SubRecord({
    this.name,
    this.alias,
    this.vc,
    this.area,
    this.rent,
    this.prevDue,
    this.startYear,
    this.startMonth,
    this.isActive,
    this.payments = const {},
  });
}

class _Payment {
  final double paid;
  final double adj;
  const _Payment({required this.paid, required this.adj});
}


