import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/area.dart';
import '../services/database_service.dart';
import '../services/backup_service.dart';
import '../services/app_mode_service.dart';
import '../services/app_reset_service.dart';
import '../services/receipt_settings_service.dart';
import 'import_wizard_screen.dart';
import 'import_history_screen.dart';
import '../app_keys.dart';
import '../services/app_language_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseService();
  final _backup = BackupService();
  final _modeService = AppModeService();
  final _receiptSettings = ReceiptSettingsService();
  final _resetService = AppResetService();
  List<Area> _areas = [];
  DateTime? _lastBackup;
  String _referralCode = '';
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
    await _receiptSettings.init();
    final referralCode = await _receiptSettings.getReferralCode();
    if (!mounted) return;
    setState(() {
      _areas = areas;
      _lastBackup = lastBackup;
      _referralCode = referralCode;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = _modeService.mode;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // ---- Service Mode ----
                _sectionHeader(context.tr('service_mode')),
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
                          context.tr('cable_tv_description'),
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
                          context.tr('internet_description'),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: Text(
                    context.tr('service_mode_help'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),

                const Divider(height: 1),

                // ---- Receipts ----
                _sectionHeader(context.tr('whatsapp_receipts')),
                _tile(
                  key: AppKeys.settingsAppLanguage,
                  icon: PhosphorIcons.translate(PhosphorIconsStyle.bold),
                  title: context.tr('app_language'),
                  subtitle: AppLanguageService
                      .languageNames[AppLanguageService.instance.languageCode],
                  onTap: _chooseAppLanguage,
                ),
                _tile(
                  key: AppKeys.settingsBusinessName,
                  icon: PhosphorIcons.buildings(PhosphorIconsStyle.bold),
                  title: context.tr('business_name'),
                  subtitle: _receiptSettings.businessNameNotifier.value,
                  onTap: _editBusinessName,
                ),
                _tile(
                  icon: PhosphorIcons.link(PhosphorIconsStyle.bold),
                  title: context.tr('anonymous_referral_code'),
                  subtitle: _referralCode,
                ),

                const Divider(height: 1),

                // ---- Import Center ----
                _sectionHeader(context.tr('import_center')),
                _tile(
                  key: AppKeys.settingsImportTv,
                  icon: PhosphorIcons.televisionSimple(PhosphorIconsStyle.bold),
                  title: context.tr('import_tv_subscribers'),
                  subtitle: context.tr('import_tv_description'),
                  onTap: () => _openImportWizard('tv'),
                ),
                _tile(
                  key: AppKeys.settingsImportFiber,
                  icon: PhosphorIcons.globeHemisphereWest(
                    PhosphorIconsStyle.bold,
                  ),
                  title: context.tr('import_internet_subscribers'),
                  subtitle: context.tr('import_internet_description'),
                  onTap: () => _openImportWizard('fiber'),
                ),
                _tile(
                  key: AppKeys.settingsImportHistory,
                  icon: PhosphorIcons.clockCounterClockwise(
                    PhosphorIconsStyle.bold,
                  ),
                  title: context.tr('import_history'),
                  subtitle: context.tr('import_history_description'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ImportHistoryScreen(),
                    ),
                  ).then((_) => _loadData()),
                ),

                const Divider(height: 1),

                // ---- Backup & Restore ----
                _sectionHeader(context.tr('backup_restore')),
                _tile(
                  key: AppKeys.settingsBackup,
                  icon: PhosphorIcons.archive(PhosphorIconsStyle.bold),
                  title: context.tr('backup_now'),
                  subtitle: _lastBackup != null
                      ? context.tr('last_backup', {
                          'date': DateFormat(
                            'dd MMM yyyy, hh:mm a',
                            AppLanguageService.instance.languageCode,
                          ).format(_lastBackup!),
                        })
                      : context.tr('no_backups_yet'),
                  onTap: _doBackup,
                ),
                _tile(
                  key: AppKeys.settingsShareBackup,
                  icon: PhosphorIcons.shareNetwork(PhosphorIconsStyle.bold),
                  title: context.tr('share_backup'),
                  subtitle: context.tr('share_backup_description'),
                  onTap: _shareBackup,
                ),
                _tile(
                  key: AppKeys.settingsRestore,
                  icon: PhosphorIcons.arrowsClockwise(PhosphorIconsStyle.bold),
                  title: context.tr('restore_backup'),
                  subtitle: context.tr('restore_backup_description'),
                  onTap: _doRestore,
                ),
                const Divider(height: 1),

                _sectionHeader(context.tr('areas')),
                ..._areas.map(
                  (a) => _tile(
                    key: AppKeys.settingsAreaTile(a.name),
                    icon: PhosphorIcons.mapPin(PhosphorIconsStyle.bold),
                    title: a.name,
                    onTap: () => _editArea(a),
                    trailing: IconButton(
                      key: AppKeys.settingsAreaDelete(a.name),
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
                    key: AppKeys.settingsAddArea,
                    onPressed: _addArea,
                    icon: Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold)),
                    label: Text(context.tr('add_area')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const Divider(height: 1),
                _sectionHeader(context.tr('about')),
                _tile(
                  icon: PhosphorIcons.info(PhosphorIconsStyle.bold),
                  title: context.tr('app_name'),
                  subtitle: context.tr('version', {'version': '1.0.0'}),
                ),

                const Divider(height: 1),
                _sectionHeader(context.tr('danger_zone')),
                _tile(
                  key: AppKeys.settingsReset,
                  icon: PhosphorIcons.warning(PhosphorIconsStyle.bold),
                  title: context.tr('reset_app'),
                  subtitle: context.tr('reset_app_description'),
                  onTap: _resetApp,
                  trailing: Icon(
                    PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                    color: const Color(0xFFC62828),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Future<void> _chooseAppLanguage() async {
    final languageService = AppLanguageService.instance;
    final selected = await showDialog<Locale>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.tr('choose_language')),
        children: [
          RadioGroup<Locale>(
            groupValue: languageService.locale,
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: AppLanguageService.supportedLocales
                  .map(
                    (locale) => RadioListTile<Locale>(
                      key: switch (locale.languageCode) {
                        'en' => AppKeys.appLanguageEnglish,
                        'hi' => AppKeys.appLanguageHindi,
                        'mr' => AppKeys.appLanguageMarathi,
                        'bn' => AppKeys.appLanguageBengali,
                        _ => AppKeys.appLanguageTamil,
                      },
                      value: locale,
                      title: Text(
                        AppLanguageService.languageNames[locale.languageCode]!,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
    if (selected == null) return;
    await languageService.setLocale(selected);
    if (mounted) setState(() {});
  }

  Future<void> _editBusinessName() async {
    final initialName = _receiptSettings.businessNameNotifier.value;
    var editedName = initialName;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('business_name')),
        content: TextFormField(
          key: AppKeys.receiptBusinessNameField,
          initialValue: initialName,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: context.tr('business_name_hint'),
          ),
          onChanged: (value) => editedName = value,
          onFieldSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            key: AppKeys.receiptBusinessNameSave,
            onPressed: () => Navigator.pop(context, editedName),
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
    if (name == null) return;
    await _receiptSettings.setBusinessName(name);
    if (mounted) setState(() {});
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
      key: option == ServiceMode.tv
          ? AppKeys.settingsModeTv
          : AppKeys.settingsModeFiber,
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
                    context.tr(
                      option == ServiceMode.tv ? 'cable_tv' : 'internet',
                    ),
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
    Key? key,
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      key: key,
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
          SnackBar(
            content: Text(context.tr('backup_created')),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('backup_failed', {'error': e})),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('share_failed', {'error': e}))),
        );
      }
    }
  }

  Future<void> _doRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('restore_backup_title')),
        content: Text(context.tr('restore_warning')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFC62828),
            ),
            child: Text(context.tr('restore')),
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
          SnackBar(
            content: Text(context.tr('restored_successfully')),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('restore_failed', {'error': e})),
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
        title: Text(context.tr('add_area')),
        content: TextField(
          key: AppKeys.areaNameField,
          controller: controller,
          decoration: InputDecoration(hintText: context.tr('area_name_hint')),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            key: AppKeys.areaNameSave,
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.tr('add')),
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
        title: Text(context.tr('rename_area')),
        content: TextField(
          key: AppKeys.areaNameField,
          controller: controller,
          decoration: InputDecoration(hintText: context.tr('area_name_hint')),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.tr('save')),
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
        title: Text(context.tr('delete_area')),
        content: Text(context.tr('delete_area_message', {'name': area.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFC62828),
            ),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.deleteArea(area.id!);
      _loadData();
    }
  }

  Future<void> _resetApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _ResetConfirmationDialog(),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _resetService.reset();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('all_data_cleared')),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        // Navigate to home and clear the stack
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('reset_failed', {'error': e})),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
  }
}

/// A dialog with a 10-second countdown timer before the user can confirm.
class _ResetConfirmationDialog extends StatefulWidget {
  const _ResetConfirmationDialog();

  @override
  State<_ResetConfirmationDialog> createState() =>
      _ResetConfirmationDialogState();
}

class _ResetConfirmationDialogState extends State<_ResetConfirmationDialog> {
  int _remainingSeconds = 10;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
      }
      setState(() => _remainingSeconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _remainingSeconds <= 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(
        PhosphorIcons.warning(PhosphorIconsStyle.duotone),
        size: 48,
        color: const Color(0xFFC62828),
      ),
      title: Text(
        context.tr('reset_app'),
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.warning(PhosphorIconsStyle.bold),
                  size: 20,
                  color: const Color(0xFFC62828),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('reset_warning_short'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB71C1C),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('reset_warning'),
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
          ),
          if (!canConfirm) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: (10 - _remainingSeconds) / 10,
                    strokeWidth: 4,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFC62828),
                    ),
                  ),
                  Center(
                    child: Text(
                      '$_remainingSeconds',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC62828),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('please_wait'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            context.tr('cancel'),
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        FilledButton(
          key: AppKeys.resetConfirm,
          onPressed: canConfirm ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFC62828),
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          child: Text(
            canConfirm
                ? context.tr('reset_everything')
                : context.tr('wait_seconds', {'seconds': _remainingSeconds}),
          ),
        ),
      ],
    );
  }
}
