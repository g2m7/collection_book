/// Persisted record of a single import execution.
class ImportRun {
  final int? id;
  final String fileName;
  final String serviceType; // 'tv' | 'fiber'
  final String status; // 'success' | 'failed' | 'partial'
  final int insertCount;
  final int updateCount;
  final int rejectCount;
  final int conflictCount;
  final int paymentCount;
  final String? startedAt;
  final String? completedAt;

  const ImportRun({
    this.id,
    required this.fileName,
    required this.serviceType,
    this.status = 'success',
    this.insertCount = 0,
    this.updateCount = 0,
    this.rejectCount = 0,
    this.conflictCount = 0,
    this.paymentCount = 0,
    this.startedAt,
    this.completedAt,
  });

  bool get hasErrors => rejectCount > 0 || conflictCount > 0;
  int get totalRows => insertCount + updateCount + rejectCount + conflictCount;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'file_name': fileName,
    'service_type': serviceType,
    'status': status,
    'insert_count': insertCount,
    'update_count': updateCount,
    'reject_count': rejectCount,
    'conflict_count': conflictCount,
    'payment_count': paymentCount,
    'started_at': startedAt ?? DateTime.now().toIso8601String(),
    'completed_at': completedAt,
  };

  factory ImportRun.fromMap(Map<String, dynamic> map) => ImportRun(
    id: map['id'] as int?,
    fileName: map['file_name'] as String,
    serviceType: map['service_type'] as String,
    status: map['status'] as String? ?? 'success',
    insertCount: (map['insert_count'] as num?)?.toInt() ?? 0,
    updateCount: (map['update_count'] as num?)?.toInt() ?? 0,
    rejectCount: (map['reject_count'] as num?)?.toInt() ?? 0,
    conflictCount: (map['conflict_count'] as num?)?.toInt() ?? 0,
    paymentCount: (map['payment_count'] as num?)?.toInt() ?? 0,
    startedAt: map['started_at'] as String?,
    completedAt: map['completed_at'] as String?,
  );

  @override
  String toString() =>
      'ImportRun(id: $id, file: $fileName, status: $status, '
      'inserted: $insertCount, updated: $updateCount)';
}
