import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/import_run.dart';
import '../services/database_service.dart';
import 'import_run_detail_screen.dart';

class ImportHistoryScreen extends StatefulWidget {
  const ImportHistoryScreen({super.key});

  @override
  State<ImportHistoryScreen> createState() => _ImportHistoryScreenState();
}

class _ImportHistoryScreenState extends State<ImportHistoryScreen> {
  final _db = DatabaseService();
  List<ImportRun> _runs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final runs = await _db.getImportRuns();
    if (!mounted) return;
    setState(() {
      _runs = runs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _runs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIcons.clockCounterClockwise(
                      PhosphorIconsStyle.duotone,
                    ),
                    size: 56,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No imports yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Import history will appear here.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _runs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _buildRunCard(_runs[i]),
              ),
            ),
    );
  }

  Widget _buildRunCard(ImportRun run) {
    final statusColor = switch (run.status) {
      'success' => const Color(0xFF2E7D32),
      'partial' => Colors.orange.shade700,
      _ => Colors.red.shade700,
    };
    final statusIcon = switch (run.status) {
      'success' => PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
      'partial' => PhosphorIcons.warning(PhosphorIconsStyle.fill),
      _ => PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
    };
    final serviceIcon = run.serviceType == 'tv'
        ? PhosphorIcons.televisionSimple(PhosphorIconsStyle.bold)
        : PhosphorIcons.globeHemisphereWest(PhosphorIconsStyle.bold);

    String timeLabel = '';
    if (run.startedAt != null) {
      final dt = DateTime.tryParse(run.startedAt!);
      if (dt != null) {
        timeLabel = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
      }
    }

    return Card(
      child: InkWell(
        onTap: run.hasErrors && run.id != null
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImportRunDetailScreen(run: run),
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(serviceIcon, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      run.fileName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(statusIcon, size: 18, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    run.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _miniStat('Added', run.insertCount, const Color(0xFF2E7D32)),
                  const SizedBox(width: 12),
                  _miniStat(
                    'Updated',
                    run.updateCount,
                    const Color(0xFF1565C0),
                  ),
                  if (run.rejectCount > 0) ...[
                    const SizedBox(width: 12),
                    _miniStat('Rejected', run.rejectCount, Colors.red.shade700),
                  ],
                  if (run.conflictCount > 0) ...[
                    const SizedBox(width: 12),
                    _miniStat(
                      'Conflicts',
                      run.conflictCount,
                      Colors.orange.shade700,
                    ),
                  ],
                ],
              ),
              if (timeLabel.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  timeLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
