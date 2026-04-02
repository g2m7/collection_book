import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/import_result.dart';
import '../models/import_run.dart';
import 'database_service.dart';

// ---------------------------------------------------------------------------
// Public surface
// ---------------------------------------------------------------------------

enum ImportFormat { book1, activePackages, totalList, csv, unknown }

class ImportPreview {
  final ImportFormat format;
  final List<ImportRecord> records;
  final List<String> sourceHeaders;
  final List<FieldMapping> mappings;

  const ImportPreview({
    required this.format,
    required this.records,
    this.sourceHeaders = const [],
    this.mappings = const [],
  });

  int get subscriberCount => records.length;
  int get paymentCount => records.fold(0, (s, r) => s + r.payments.length);

  String get formatLabel => switch (format) {
    ImportFormat.book1 => 'Book1 ledger (subscribers + payments)',
    ImportFormat.activePackages => 'Operator active-packages report',
    ImportFormat.totalList => 'Operator total-subscriber report',
    ImportFormat.csv => 'CSV subscriber list',
    ImportFormat.unknown => 'Unknown format',
  };
}

class ImportService {
  final _db = DatabaseService();

  // =========================================================================
  // 1) PREVIEW — parse file into in-memory records (no DB writes)
  // =========================================================================

  Future<ImportPreview> preview(String path) async {
    final bytes = await File(path).readAsBytes();
    final lower = path.toLowerCase();

    if (lower.endsWith('.csv')) {
      return _parseCsv(bytes);
    }

    if (lower.endsWith('.xlsx')) {
      return _parseBook1Xlsx(bytes);
    }

    // .xls files from this operator are HTML tables
    final text = String.fromCharCodes(bytes);
    if (text.contains('STB_NUMBER') || text.contains('START_DATE')) {
      return _parseActivePackagesHtml(text);
    }
    if (text.contains('STB_ISSUE_DATE')) {
      return _parseTotalListHtml(text);
    }
    return ImportPreview(format: ImportFormat.unknown, records: []);
  }

  // =========================================================================
  // 2) VALIDATE — check required fields + generate mappings
  // =========================================================================

  ImportValidationResult validate(ImportPreview preview, String serviceType) {
    final errors = <ImportRowError>[];
    int validRows = 0;
    final invalidThreshold = 0.05; // 5% invalid rows → abort

    for (int i = 0; i < preview.records.length; i++) {
      final rec = preview.records[i];
      final rowNum = i + 1;
      final rowErrors = <String>[];

      // Required: name
      if (rec.name == null || rec.name!.trim().isEmpty) {
        rowErrors.add('Missing subscriber name');
      }

      // Required: strong ID
      final hasStrongId = _hasStrongIdentifier(rec, serviceType);
      if (!hasStrongId) {
        rowErrors.add(
          serviceType == 'tv'
              ? 'Missing strong ID (vc_number, stb_number, or customer_nbr)'
              : 'Missing strong ID (account_id, username, or phone)',
        );
      }

      if (rowErrors.isEmpty) {
        validRows++;
      } else {
        for (final reason in rowErrors) {
          errors.add(ImportRowError(rowNumber: rowNum, reason: reason));
        }
      }
    }

    final totalRows = preview.records.length;
    final invalidRatio = totalRows > 0
        ? (totalRows - validRows) / totalRows
        : 0.0;
    final canProceed =
        totalRows > 0 && invalidRatio <= invalidThreshold && validRows > 0;

    // Build mappings based on detected format
    final mappings = _buildMappings(preview, serviceType);

    return ImportValidationResult(
      mappings: mappings,
      errors: errors,
      totalRows: totalRows,
      validRows: validRows,
      canProceed: canProceed,
    );
  }

  bool _hasStrongIdentifier(ImportRecord rec, String serviceType) {
    if (serviceType == 'tv') {
      return (rec.vc != null && rec.vc!.isNotEmpty);
    }
    // Fiber: account_id, username, or phone
    return (rec.accountId != null && rec.accountId!.isNotEmpty) ||
        (rec.username != null && rec.username!.isNotEmpty) ||
        (rec.phone != null && rec.phone!.isNotEmpty);
  }

  List<FieldMapping> _buildMappings(ImportPreview preview, String serviceType) {
    final mappings = <FieldMapping>[];
    final isKnownFormat = preview.format != ImportFormat.unknown;

    mappings.add(
      FieldMapping(
        targetField: 'subscriber_name',
        sourceColumn: isKnownFormat ? 'name (auto-detected)' : null,
        confidence: isKnownFormat ? 1.0 : 0.0,
        isRequired: true,
      ),
    );

    if (serviceType == 'tv') {
      mappings.add(
        FieldMapping(
          targetField: 'vc_number',
          sourceColumn: isKnownFormat ? 'vc_number (auto-detected)' : null,
          confidence: isKnownFormat ? 1.0 : 0.0,
          isRequired: true,
        ),
      );
    } else {
      mappings.add(
        FieldMapping(
          targetField: 'account_id / username / phone',
          sourceColumn: isKnownFormat ? 'identifier (auto-detected)' : null,
          confidence: isKnownFormat ? 0.8 : 0.0,
          isRequired: true,
        ),
      );
    }

    mappings.add(
      FieldMapping(
        targetField: 'monthly_amount',
        sourceColumn: isKnownFormat ? 'monthly_rent (auto-detected)' : null,
        confidence: isKnownFormat ? 0.9 : 0.0,
        isRequired: false,
      ),
    );

    mappings.add(
      FieldMapping(
        targetField: 'area',
        sourceColumn: isKnownFormat ? 'area (auto-detected)' : null,
        confidence: isKnownFormat ? 0.9 : 0.0,
        isRequired: false,
      ),
    );

    return mappings;
  }

  // =========================================================================
  // 3) DRY RUN — simulate import, return counts without DB writes
  // =========================================================================

  Future<ImportDryRunResult> dryRun(
    ImportPreview preview,
    String serviceType,
  ) async {
    int inserts = 0, updates = 0, rejects = 0, conflicts = 0;
    final errors = <ImportRowError>[];

    for (int i = 0; i < preview.records.length; i++) {
      final rec = preview.records[i];
      final rowNum = i + 1;

      if (rec.name == null && rec.vc == null) {
        rejects++;
        errors.add(
          ImportRowError(
            rowNumber: rowNum,
            reason: 'Empty row (no name or identifier)',
            severity: ImportSeverity.warning,
          ),
        );
        continue;
      }

      if (!_hasStrongIdentifier(rec, serviceType)) {
        rejects++;
        errors.add(
          ImportRowError(
            rowNumber: rowNum,
            reason: 'Missing strong identifier',
          ),
        );
        continue;
      }

      // Check cross-service conflict
      final hasConflict = await _db.hasConflictInOppositeService(
        serviceType,
        rec.vc,
        rec.accountId,
        rec.username,
      );
      if (hasConflict) {
        conflicts++;
        errors.add(
          ImportRowError(
            rowNumber: rowNum,
            reason: 'Identifier exists in opposite service',
            severity: ImportSeverity.error,
          ),
        );
        continue;
      }

      // Check if existing (update) or new (insert)
      final existingId = await _db.findSubscriberByStrongId(
        serviceType,
        rec.vc,
        rec.accountId,
        rec.username,
        rec.phone,
      );

      if (existingId != null) {
        updates++;
      } else if (rec.name != null) {
        final nameMatch = await _db.findSubscriberByName(
          rec.name!,
          serviceType,
        );
        if (nameMatch != null) {
          updates++;
        } else {
          inserts++;
        }
      } else {
        rejects++;
        errors.add(
          ImportRowError(
            rowNumber: rowNum,
            reason: 'No name provided for new subscriber',
          ),
        );
      }
    }

    return ImportDryRunResult(
      insertCount: inserts,
      updateCount: updates,
      rejectCount: rejects,
      conflictCount: conflicts,
      errors: errors,
    );
  }

  // =========================================================================
  // 4) COMMIT — write to DB in a single transaction
  // =========================================================================

  Future<ImportCommitResult> commit(
    ImportPreview preview,
    String serviceType,
    String fileName, {
    void Function(int current, int total)? onProgress,
  }) async {
    final db = await _db.database;
    int inserted = 0, updated = 0, payments = 0, rejected = 0, conflicts = 0;
    final errors = <ImportRowError>[];
    final startTime = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final total = preview.records.length;

      for (int i = 0; i < total; i++) {
        final rec = preview.records[i];
        final rowNum = i + 1;

        onProgress?.call(i + 1, total);

        if (rec.name == null && rec.vc == null) {
          rejected++;
          continue;
        }

        if (!_hasStrongIdentifier(rec, serviceType)) {
          rejected++;
          errors.add(
            ImportRowError(
              rowNumber: rowNum,
              reason: 'Missing strong identifier',
            ),
          );
          continue;
        }

        // Check cross-service conflict
        final hasConflict = await _checkConflictInTxn(
          txn,
          serviceType,
          rec.vc,
          rec.accountId,
          rec.username,
        );
        if (hasConflict) {
          conflicts++;
          errors.add(
            ImportRowError(
              rowNumber: rowNum,
              reason: 'Identifier exists in opposite service',
            ),
          );
          continue;
        }

        // Resolve area
        final resolvedAreaId = rec.area != null
            ? await _resolveAreaId(txn, rec.area!)
            : null;

        // Find existing subscriber (service-bound)
        final existingId = await _findSubscriberInTxn(
          txn,
          serviceType,
          rec.vc,
          rec.accountId,
          rec.username,
          rec.phone,
          rec.name,
        );

        if (existingId != null) {
          await txn.rawUpdate(
            '''
            UPDATE subscribers SET
              area_id      = COALESCE(?, area_id),
              alias_name   = COALESCE(?, alias_name),
              monthly_rent = COALESCE(NULLIF(?, 0), monthly_rent),
              previous_due = COALESCE(?, previous_due),
              start_year   = COALESCE(?, start_year),
              start_month  = COALESCE(?, start_month),
              account_id   = COALESCE(?, account_id),
              username     = COALESCE(?, username),
              phone        = COALESCE(?, phone)
            WHERE id = ?
          ''',
            [
              resolvedAreaId,
              rec.alias,
              rec.rent,
              rec.prevDue,
              rec.startYear,
              rec.startMonth,
              rec.accountId,
              rec.username,
              rec.phone,
              existingId,
            ],
          );
          updated++;
          payments += await _upsertPayments(txn, existingId, rec.payments);
        } else {
          if (rec.name == null) {
            rejected++;
            errors.add(
              ImportRowError(
                rowNumber: rowNum,
                reason: 'No name for new subscriber',
              ),
            );
            continue;
          }
          final id = await txn.rawInsert(
            '''
            INSERT INTO subscribers
              (area_id, name, alias_name, vc_number, monthly_rent,
               previous_due, is_active, service_type, start_year, start_month,
               account_id, username, phone)
            VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?, ?)
          ''',
            [
              resolvedAreaId,
              rec.name,
              rec.alias,
              rec.vc,
              rec.rent ?? 0,
              rec.prevDue ?? 0,
              serviceType,
              rec.startYear,
              rec.startMonth,
              rec.accountId,
              rec.username,
              rec.phone,
            ],
          );
          inserted++;
          payments += await _upsertPayments(txn, id, rec.payments);
        }
      }
    });

    // Persist import run metadata
    final run = ImportRun(
      fileName: fileName,
      serviceType: serviceType,
      status: errors.isEmpty
          ? 'success'
          : (inserted + updated > 0 ? 'partial' : 'failed'),
      insertCount: inserted,
      updateCount: updated,
      rejectCount: rejected,
      conflictCount: conflicts,
      paymentCount: payments,
      startedAt: startTime,
      completedAt: DateTime.now().toIso8601String(),
    );
    final runId = await _db.insertImportRun(run);
    if (errors.isNotEmpty) {
      await _db.insertImportErrors(runId, errors);
    }

    return ImportCommitResult(
      inserted: inserted,
      updated: updated,
      payments: payments,
      rejected: rejected,
      conflicts: conflicts,
      errors: errors,
    );
  }

  // =========================================================================
  // Book1 xlsx parser
  // =========================================================================

  static const _book1Year = 2025;

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
    final records = <ImportRecord>[];

    for (int i = 0; i < rows.length; i++) {
      if (i < 3) continue;
      final row = rows[i];

      final areaCell = _str(row, 0);
      if (areaCell != null && areaCell.toUpperCase() != 'AREA') {
        currentArea = areaCell;
      }

      final name = _str(row, 3);
      final vc = _vcStr(row, 4);
      if (name == null && vc == null) continue;

      final alias = _str(row, 2);
      final rent = _num(row, 5) ?? 0;
      final prevDue = _num(row, 6) ?? 0;

      final pmts = <int, PaymentEntry>{};
      int? firstPayMonth;

      for (final entry in _monthCols.entries) {
        final month = entry.key;
        final paidCol = entry.value.$1;
        final adjCol = entry.value.$2;

        final paid = _num(row, paidCol);
        final adj = adjCol >= 0 ? (_num(row, adjCol) ?? 0.0) : 0.0;

        if (paid != null) {
          pmts[month] = PaymentEntry(paid: paid, adj: adj);
          firstPayMonth ??= month;
        }
      }

      records.add(
        ImportRecord(
          name: name,
          alias: alias,
          vc: vc,
          area: currentArea,
          rent: rent,
          prevDue: prevDue,
          startYear: firstPayMonth != null ? _book1Year : null,
          startMonth: firstPayMonth,
          payments: pmts,
        ),
      );
    }

    return ImportPreview(format: ImportFormat.book1, records: records);
  }

  // =========================================================================
  // Operator HTML-XLS parsers
  // =========================================================================

  ImportPreview _parseActivePackagesHtml(String html) {
    final rows = _htmlRows(html);
    if (rows.isEmpty) {
      return ImportPreview(format: ImportFormat.activePackages, records: []);
    }

    final headers = rows.first;
    final idx = _headerMap(headers);
    final records = <ImportRecord>[];
    final seen = <String>{};

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= 1) continue;

      final planType = _col(row, idx['PLAN_TYPE']);
      if (planType != null && planType != 'BASE') continue;

      final vc = _cleanVc(
        _col(row, idx['STB_NUMBER']) ?? _col(row, idx['VC_CARD']),
      );
      final name = _cleanName(_col(row, idx['NAME']));
      if (vc == null && name == null) continue;

      final key = vc ?? name!;
      if (seen.contains(key)) continue;
      seen.add(key);

      final startDate = _parseDate(_col(row, idx['START_DATE']));
      final area = _col(row, idx['ADDRESS3'])?.trim();
      final status = _col(row, idx['STATUS'])?.toUpperCase() == 'ACTIVE';

      records.add(
        ImportRecord(
          name: name,
          vc: vc,
          area: area?.isNotEmpty == true ? area : null,
          startYear: startDate?.year,
          startMonth: startDate?.month,
          isActive: status,
        ),
      );
    }

    return ImportPreview(
      format: ImportFormat.activePackages,
      records: records,
      sourceHeaders: rows.isNotEmpty ? rows.first : [],
    );
  }

  ImportPreview _parseTotalListHtml(String html) {
    final rows = _htmlRows(html);
    if (rows.isEmpty) {
      return ImportPreview(format: ImportFormat.totalList, records: []);
    }

    final headers = rows.first;
    final idx = _headerMap(headers);
    final records = <ImportRecord>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= 1) continue;

      final vc = _cleanVc(_col(row, idx['VC_CARD']));
      final name = _cleanName(_col(row, idx['NAME']));
      if (vc == null && name == null) continue;

      final startDate = _parseDate(_col(row, idx['STB_ISSUE_DATE']));
      final area = _col(row, idx['ADDRESS3'])?.trim();
      final status = _col(row, idx['STATUS'])?.toUpperCase() == 'ACTIVE';

      records.add(
        ImportRecord(
          name: name,
          vc: vc,
          area: area?.isNotEmpty == true ? area : null,
          startYear: startDate?.year,
          startMonth: startDate?.month,
          isActive: status,
        ),
      );
    }

    return ImportPreview(
      format: ImportFormat.totalList,
      records: records,
      sourceHeaders: rows.isNotEmpty ? rows.first : [],
    );
  }

  // =========================================================================
  // CSV parser
  // =========================================================================

  ImportPreview _parseCsv(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final lines = const LineSplitter().convert(text);
    if (lines.isEmpty) {
      return ImportPreview(format: ImportFormat.csv, records: []);
    }

    final headers = _parseCsvLine(lines.first);
    final normalized = headers.map((h) => _normalizeHeader(h)).toList();
    final idx = <String, int>{};
    for (int i = 0; i < normalized.length; i++) {
      idx[normalized[i]] = i;
    }

    // Synonym-based column resolution
    final nameCol = _resolveCol(idx, [
      'name',
      'subscriber_name',
      'subscribername',
      'customer_name',
      'customername',
    ]);
    final vcCol = _resolveCol(idx, [
      'vc_number',
      'vcnumber',
      'vc_no',
      'vcno',
      'vc',
      'stb_number',
      'stbnumber',
      'customer_nbr',
    ]);
    final rentCol = _resolveCol(idx, [
      'monthly_rent',
      'monthlyrent',
      'monthly_amount',
      'monthlyamount',
      'montly_rent',
      'montlyrent',
      'rent',
      'amount',
    ]);
    final areaCol = _resolveCol(idx, [
      'area',
      'address',
      'address3',
      'location',
    ]);
    final aliasCol = _resolveCol(idx, [
      'alias_name',
      'aliasname',
      'alias',
      'nickname',
    ]);
    final prevDueCol = _resolveCol(idx, [
      'previous_due',
      'previousdue',
      'prevdue',
      'prev_due',
      'opening_balance',
    ]);
    final accountIdCol = _resolveCol(idx, [
      'account_id',
      'accountid',
      'account',
    ]);
    final usernameCol = _resolveCol(idx, ['username', 'user_name', 'login']);
    final phoneCol = _resolveCol(idx, [
      'phone',
      'mobile',
      'contact',
      'phone_number',
    ]);
    final statusCol = _resolveCol(idx, ['status', 'is_active', 'active']);

    final records = <ImportRecord>[];

    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      final cols = _parseCsvLine(lines[i]);

      final name = _getCol(cols, nameCol);
      final vc = _getCol(cols, vcCol);
      if (name == null && vc == null) continue;

      final rentStr = _getCol(cols, rentCol);
      final prevDueStr = _getCol(cols, prevDueCol);
      final statusStr = _getCol(cols, statusCol);

      records.add(
        ImportRecord(
          name: name,
          vc: vc,
          area: _getCol(cols, areaCol),
          alias: _getCol(cols, aliasCol),
          rent: rentStr != null ? double.tryParse(rentStr) : null,
          prevDue: prevDueStr != null ? double.tryParse(prevDueStr) : null,
          accountId: _getCol(cols, accountIdCol),
          username: _getCol(cols, usernameCol),
          phone: _getCol(cols, phoneCol),
          isActive: statusStr != null
              ? statusStr.toLowerCase() == 'active' || statusStr == '1'
              : null,
        ),
      );
    }

    return ImportPreview(
      format: ImportFormat.csv,
      records: records,
      sourceHeaders: headers,
    );
  }

  String _normalizeHeader(String h) {
    return h
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  int? _resolveCol(Map<String, int> idx, List<String> synonyms) {
    for (final syn in synonyms) {
      if (idx.containsKey(syn)) return idx[syn];
    }
    return null;
  }

  String? _getCol(List<String> cols, int? idx) {
    if (idx == null || idx >= cols.length) return null;
    final v = cols[idx].trim();
    return v.isEmpty ? null : v;
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        result.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    result.add(buf.toString());
    return result;
  }

  // =========================================================================
  // HTML helpers
  // =========================================================================

  List<List<String>> _htmlRows(String html) {
    final doc = html_parser.parse(html);
    final trs = doc.querySelectorAll('tr');
    return trs
        .map(
          (tr) =>
              tr.querySelectorAll('td, th').map((c) => c.text.trim()).toList(),
        )
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

  // =========================================================================
  // Excel cell helpers
  // =========================================================================

  String? _cellRawString(CellValue? v) {
    if (v == null) return null;
    if (v is TextCellValue) return v.value.toString();
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) return v.value.toStringAsFixed(0);
    return null;
  }

  String? _str(List<Data?> row, int col) {
    if (col >= row.length) return null;
    final s = _cellRawString(
      row[col]?.value,
    )?.trim().replaceAll(RegExp(r"^'+|'+$"), '');
    return (s == null || s.isEmpty) ? null : s;
  }

  String? _vcStr(List<Data?> row, int col) {
    if (col >= row.length) return null;
    final v = row[col]?.value;
    if (v == null) return null;
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) return v.value.toStringAsFixed(0);
    if (v is TextCellValue) {
      final s = v.value.toString().trim().replaceAll(RegExp(r"^'+|'+$"), '');
      if (s.isEmpty) return null;
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
    if (v is IntCellValue) return v.value.toDouble();
    if (v is DoubleCellValue) return v.value;
    if (v is TextCellValue) return double.tryParse(v.value.toString());
    return null;
  }

  // =========================================================================
  // Shared string cleaners
  // =========================================================================

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
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (_) {}
    return null;
  }

  // =========================================================================
  // Transaction-safe DB helpers
  // =========================================================================

  Future<int?> _resolveAreaId(dynamic txn, String name) async {
    await txn.rawInsert('INSERT OR IGNORE INTO areas (name) VALUES (?)', [
      name,
    ]);
    final rows = await txn.rawQuery('SELECT id FROM areas WHERE name = ?', [
      name,
    ]);
    return rows.isEmpty ? null : rows.first['id'] as int?;
  }

  Future<int?> _findSubscriberInTxn(
    dynamic txn,
    String serviceType,
    String? vc,
    String? accountId,
    String? username,
    String? phone,
    String? name,
  ) async {
    // Try strong ID first
    if (serviceType == 'tv' && vc != null && vc.isNotEmpty) {
      final r = await txn.rawQuery(
        'SELECT id FROM subscribers WHERE vc_number = ? AND service_type = ?',
        [vc, serviceType],
      );
      if (r.isNotEmpty) return r.first['id'] as int;
    }

    if (serviceType == 'fiber') {
      if (accountId != null && accountId.isNotEmpty) {
        final r = await txn.rawQuery(
          'SELECT id FROM subscribers WHERE account_id = ? AND service_type = ?',
          [accountId, serviceType],
        );
        if (r.isNotEmpty) return r.first['id'] as int;
      }
      if (username != null && username.isNotEmpty) {
        final r = await txn.rawQuery(
          'SELECT id FROM subscribers WHERE username = ? AND service_type = ?',
          [username, serviceType],
        );
        if (r.isNotEmpty) return r.first['id'] as int;
      }
      if (phone != null && phone.isNotEmpty) {
        final r = await txn.rawQuery(
          'SELECT id FROM subscribers WHERE phone = ? AND service_type = ?',
          [phone, serviceType],
        );
        if (r.isNotEmpty) return r.first['id'] as int;
      }
    }

    // Fallback: name match within same service
    if (name != null && name.isNotEmpty) {
      final r = await txn.rawQuery(
        'SELECT id FROM subscribers WHERE name = ? AND service_type = ?',
        [name, serviceType],
      );
      if (r.isNotEmpty) return r.first['id'] as int;
    }

    return null;
  }

  Future<bool> _checkConflictInTxn(
    dynamic txn,
    String serviceType,
    String? vc,
    String? accountId,
    String? username,
  ) async {
    final opposite = serviceType == 'tv' ? 'fiber' : 'tv';

    if (vc != null && vc.isNotEmpty) {
      final r = await txn.rawQuery(
        'SELECT 1 FROM subscribers WHERE vc_number = ? AND service_type = ?',
        [vc, opposite],
      );
      if (r.isNotEmpty) return true;
    }
    if (accountId != null && accountId.isNotEmpty) {
      final r = await txn.rawQuery(
        'SELECT 1 FROM subscribers WHERE account_id = ? AND service_type = ?',
        [accountId, opposite],
      );
      if (r.isNotEmpty) return true;
    }
    if (username != null && username.isNotEmpty) {
      final r = await txn.rawQuery(
        'SELECT 1 FROM subscribers WHERE username = ? AND service_type = ?',
        [username, opposite],
      );
      if (r.isNotEmpty) return true;
    }
    return false;
  }

  Future<int> _upsertPayments(
    dynamic txn,
    int subId,
    Map<int, PaymentEntry> payments,
  ) async {
    int count = 0;
    for (final entry in payments.entries) {
      final month = entry.key;
      final p = entry.value;
      if (p.paid == 0 && p.adj == 0) continue;
      await txn.rawInsert(
        '''
        INSERT INTO payments
          (subscriber_id, year, month, amount_paid, adjustment)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(subscriber_id, year, month) DO UPDATE SET
          amount_paid = excluded.amount_paid,
          adjustment  = excluded.adjustment
      ''',
        [subId, p.year ?? _book1Year, month, p.paid, p.adj],
      );
      count++;
    }
    return count;
  }
}

// ---------------------------------------------------------------------------
// Internal data classes (now public for wizard preview access)
// ---------------------------------------------------------------------------

class ImportRecord {
  final String? name;
  final String? alias;
  final String? vc;
  final String? area;
  final double? rent;
  final double? prevDue;
  final int? startYear;
  final int? startMonth;
  final bool? isActive;
  final String? accountId;
  final String? username;
  final String? phone;
  final Map<int, PaymentEntry> payments;

  const ImportRecord({
    this.name,
    this.alias,
    this.vc,
    this.area,
    this.rent,
    this.prevDue,
    this.startYear,
    this.startMonth,
    this.isActive,
    this.accountId,
    this.username,
    this.phone,
    this.payments = const {},
  });
}

class PaymentEntry {
  final double paid;
  final double adj;
  final int? year;
  const PaymentEntry({required this.paid, required this.adj, this.year});
}
