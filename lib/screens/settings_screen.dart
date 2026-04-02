import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/area.dart';
import '../services/database_service.dart';
import '../services/backup_service.dart';
import '../services/app_mode_service.dart';
import 'import_wizard_screen.dart';
import 'import_history_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseService();
  final _backup = BackupService();
  final _modeService = AppModeService();
  List<Area> _areas = [];
  DateTime? _lastBackup;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _modeService.modeNotifier.addListener(_rebuild);
    _loadData();
  }

  @override
  void dispose() {
    _modeService.modeNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _loadData() async {
    final areas = await _db.getAreas();
    final lastBackup = await _backup.getLastBackupTime();
    setState(() {
      _areas = areas;
      _lastBackup = lastBackup;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = _modeService.mode;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // ---- Service Mode ----
                _sectionHeader('Service Mode'),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _modeOption(
                          ServiceMode.tv,
                          mode,
                          primary,
                          'Cable TV subscribers & payments',
                        ),
                        Divider(
                          height: 1,
                          indent: 56,
                          color: Colors.grey.shade100,
                        ),
                        _modeOption(
                          ServiceMode.fiber,
                          mode,
                          primary,
                          'Internet / Fiber subscribers & payments',
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: Text(
                    'Switching mode shows only that service\'s data.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),

                const Divider(height: 1),

                // ---- Import Center ----
                _sectionHeader('Import Center'),
                _tile(
                  icon: PhosphorIcons.televisionSimple(PhosphorIconsStyle.bold),
                  title: 'Import TV Subscribers',
                  subtitle: 'Import from spreadsheet into Cable TV',
                  onTap: () => _openImportWizard('tv'),
                ),
                _tile(
                  icon: PhosphorIcons.globeHemisphereWest(
                    PhosphorIconsStyle.bold,
                  ),
                  title: 'Import Internet Subscribers',
                  subtitle: 'Import from spreadsheet into Internet/Fiber',
                  onTap: () => _openImportWizard('fiber'),
                ),
                _tile(
                  icon: PhosphorIcons.clockCounterClockwise(
                    PhosphorIconsStyle.bold,
                  ),
                  title: 'Import History',
                  subtitle: 'View past imports and error details',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ImportHistoryScreen(),
                    ),
                  ).then((_) => _loadData()),
                ),

                const Divider(height: 1),

                // ---- Backup & Restore ----
                _sectionHeader('Backup & Restore'),
                _tile(
                  icon: PhosphorIcons.archive(PhosphorIconsStyle.bold),
                  title: 'Backup Now',
                  subtitle: _lastBackup != null
                      ? 'Last: ${DateFormat('dd MMM yyyy, hh:mm a').format(_lastBackup!)}'
                      : 'No backups yet',
                  onTap: _doBackup,
                ),
                _tile(
                  icon: PhosphorIcons.shareNetwork(PhosphorIconsStyle.bold),
                  title: 'Share Backup',
                  subtitle: 'Share database file via any app',
                  onTap: _shareBackup,
                ),
                _tile(
                  icon: PhosphorIcons.arrowsClockwise(PhosphorIconsStyle.bold),
                  title: 'Restore from Backup',
                  subtitle: 'Pick a backup file to restore',
                  onTap: _doRestore,
                ),
                const Divider(height: 1),

                _sectionHeader('Areas'),
                ..._areas.map(
                  (a) => _tile(
                    icon: PhosphorIcons.mapPin(PhosphorIconsStyle.bold),
                    title: a.name,
                    onTap: () => _editArea(a),
                    trailing: IconButton(
                      icon: Icon(
                        PhosphorIcons.trash(PhosphorIconsStyle.bold),
                        size: 20,
                      ),
                      onPressed: () => _deleteArea(a),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: _addArea,
                    icon: Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold)),
                    label: const Text('Add Area'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const Divider(height: 1),
                _sectionHeader('About'),
                _tile(
                  icon: PhosphorIcons.info(PhosphorIconsStyle.bold),
                  title: 'Collection Book',
                  subtitle: 'Version 1.0.0',
                ),
              ],
            ),
    );
  }

  void _openImportWizard(String serviceType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImportWizardScreen(preselectedService: serviceType),
      ),
    ).then((_) => _loadData());
  }

  Widget _modeOption(
    ServiceMode option,
    ServiceMode current,
    Color primary,
    String subtitle,
  ) {
    final selected = option == current;
    return InkWell(
      onTap: () => _modeService.setMode(option),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(option.icon, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected ? primary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
                color: primary,
                size: 20,
              )
            else
              Icon(
                PhosphorIcons.circle(PhosphorIconsStyle.bold),
                color: Colors.grey.shade300,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1565C0)),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 13))
          : null,
      trailing:
          trailing ??
          (onTap != null
              ? Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold))
              : null),
      onTap: onTap,
    );
  }

  Future<void> _doBackup() async {
    try {
      await _backup.backup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup created successfully'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
  }

  Future<void> _shareBackup() async {
    try {
      await _backup.shareBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    }
  }

  Future<void> _doRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from Backup?'),
        content: const Text(
          'This will replace all current data with the backup. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFC62828),
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result == null || result.files.single.path == null) return;

    try {
      await _backup.restoreFromFile(result.files.single.path!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restored successfully! Restarting…'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
  }

  Future<void> _addArea() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Area'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Area name…'),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      await _db.insertArea(Area(name: name.trim()));
      _loadData();
    }
  }

  Future<void> _editArea(Area area) async {
    final controller = TextEditingController(text: area.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Area'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Area name…'),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      await _db.updateArea(area.copyWith(name: name.trim()));
      _loadData();
    }
  }

  Future<void> _deleteArea(Area area) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Area?'),
        content: Text(
          'Delete "${area.name}"? Subscribers in this area will need to be reassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFC62828),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.deleteArea(area.id!);
      _loadData();
    }
  }
}
