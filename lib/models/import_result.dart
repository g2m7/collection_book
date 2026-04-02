/// Severity of an import row issue.
enum ImportSeverity { warning, error, fatal }

/// A single row-level import error.
class ImportRowError {
  final int rowNumber;
  final String? sourceColumn;
  final String reason;
  final ImportSeverity severity;

  const ImportRowError({
    required this.rowNumber,
    this.sourceColumn,
    required this.reason,
    this.severity = ImportSeverity.error,
  });

  Map<String, dynamic> toMap() => {
    'row_number': rowNumber,
    'source_column': sourceColumn,
    'reason': reason,
    'severity': severity.name,
  };

  factory ImportRowError.fromMap(Map<String, dynamic> map) => ImportRowError(
    rowNumber: map['row_number'] as int,
    sourceColumn: map['source_column'] as String?,
    reason: map['reason'] as String,
    severity: ImportSeverity.values.firstWhere(
      (s) => s.name == (map['severity'] as String? ?? 'error'),
      orElse: () => ImportSeverity.error,
    ),
  );

  @override
  String toString() =>
      'Row $rowNumber${sourceColumn != null ? ' [$sourceColumn]' : ''}: $reason';
}

/// Per-field mapping confidence result.
class FieldMapping {
  final String targetField;
  final String? sourceColumn;
  final double confidence; // 0.0–1.0
  final bool isRequired;

  const FieldMapping({
    required this.targetField,
    this.sourceColumn,
    this.confidence = 0.0,
    this.isRequired = false,
  });

  bool get isResolved => sourceColumn != null && confidence >= 0.5;

  FieldMapping copyWith({
    String? targetField,
    String? sourceColumn,
    double? confidence,
    bool? isRequired,
  }) => FieldMapping(
    targetField: targetField ?? this.targetField,
    sourceColumn: sourceColumn ?? this.sourceColumn,
    confidence: confidence ?? this.confidence,
    isRequired: isRequired ?? this.isRequired,
  );
}

/// Result of the mapping + validation phase before any DB writes.
class ImportValidationResult {
  final List<FieldMapping> mappings;
  final List<ImportRowError> errors;
  final int totalRows;
  final int validRows;
  final bool canProceed;

  const ImportValidationResult({
    required this.mappings,
    this.errors = const [],
    required this.totalRows,
    required this.validRows,
    required this.canProceed,
  });

  List<FieldMapping> get unresolvedRequired =>
      mappings.where((m) => m.isRequired && !m.isResolved).toList();
}

/// Counts from a dry-run (no DB writes).
class ImportDryRunResult {
  final int insertCount;
  final int updateCount;
  final int rejectCount;
  final int conflictCount;
  final List<ImportRowError> errors;

  const ImportDryRunResult({
    this.insertCount = 0,
    this.updateCount = 0,
    this.rejectCount = 0,
    this.conflictCount = 0,
    this.errors = const [],
  });

  int get totalProcessed =>
      insertCount + updateCount + rejectCount + conflictCount;
}

/// Final result after committing import to DB.
class ImportCommitResult {
  final int inserted;
  final int updated;
  final int payments;
  final int rejected;
  final int conflicts;
  final List<ImportRowError> errors;

  const ImportCommitResult({
    this.inserted = 0,
    this.updated = 0,
    this.payments = 0,
    this.rejected = 0,
    this.conflicts = 0,
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  int get totalProcessed => inserted + updated + rejected + conflicts;
}
