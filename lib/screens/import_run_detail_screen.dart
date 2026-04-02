import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/import_run.dart';
import '../models/import_result.dart';
import '../services/database_service.dart';

class ImportRunDetailScreen extends StatefulWidget {
  final ImportRun run;
  const ImportRunDetailScreen({super.key, required this.run});

  @override
  State<ImportRunDetailScreen> createState() => _ImportRunDetailScreenState();
}

class _ImportRunDetailScreenState extends State<ImportRunDetailScreen> {
  final _db = DatabaseService();
  List<ImportRowError> _errors = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadErrors();
  }

  Future<void> _loadErrors() async {
    if (widget.run.id == null) {
      setState(() => _loading = false);
      return;
    }
    final errors = await _db.getImportErrors(widget.run.id!);
    if (!mounted) return;
    setState(() {
      _errors = errors;
      _loading = false;
    });
  }

  List<ImportRowError> get _filteredErrors {
    if (_searchQuery.isEmpty) return _errors;
    final q = _searchQuery.toLowerCase();
    return _errors.where((e) {
      return e.reason.toLowerCase().contains(q) ||
          'row ${e.rowNumber}'.contains(q) ||
          (e.sourceColumn?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final statusColor = switch (run.status) {
      'success' => const Color(0xFF2E7D32),
      'partial' => Colors.orange.shade700,
      _ => Colors.red.shade700,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Import Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                run.fileName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                run.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _detailRow(
                          'Service',
                          run.serviceType == 'tv' ? 'Cable TV' : 'Internet',
                        ),
                        _detailRow('Added', '${run.insertCount}'),
                        _detailRow('Updated', '${run.updateCount}'),
                        if (run.rejectCount > 0)
                          _detailRow('Rejected', '${run.rejectCount}'),
                        if (run.conflictCount > 0)
                          _detailRow('Conflicts', '${run.conflictCount}'),
                        if (run.paymentCount > 0)
                          _detailRow('Payments', '${run.paymentCount}'),
                      ],
                    ),
                  ),
                ),

                // Error list
                if (_errors.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Error Rows (${_errors.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search errors…',
                      prefixIcon: Icon(
                        PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold),
                        size: 18,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._filteredErrors.map(_buildErrorTile),
                  if (_filteredErrors.isEmpty && _searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No matching errors.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                ] else
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No errors recorded for this import.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildErrorTile(ImportRowError error) {
    final severityColor = switch (error.severity) {
      ImportSeverity.fatal => Colors.red.shade700,
      ImportSeverity.error => Colors.orange.shade700,
      ImportSeverity.warning => Colors.amber.shade700,
    };
    final severityIcon = switch (error.severity) {
      ImportSeverity.fatal => PhosphorIcons.xCircle(PhosphorIconsStyle.bold),
      ImportSeverity.error => PhosphorIcons.warning(PhosphorIconsStyle.bold),
      ImportSeverity.warning => PhosphorIcons.info(PhosphorIconsStyle.bold),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: severityColor.withAlpha(8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: severityColor.withAlpha(40)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(severityIcon, size: 16, color: severityColor),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Row ${error.rowNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: severityColor,
                  ),
                ),
                if (error.sourceColumn != null)
                  Text(
                    error.sourceColumn!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error.reason,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
