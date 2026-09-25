import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/import_result.dart';
import '../services/import_service.dart';
import '../services/app_mode_service.dart';
import '../app_keys.dart';
import '../services/app_language_service.dart';

class ImportWizardScreen extends StatefulWidget {
  /// Optionally pre-select the service type ('tv' or 'fiber').
  final String? preselectedService;

  const ImportWizardScreen({super.key, this.preselectedService});

  @override
  State<ImportWizardScreen> createState() => _ImportWizardScreenState();
}

class _ImportWizardScreenState extends State<ImportWizardScreen> {
  final _importService = ImportService();

  // Wizard state
  int _currentStep = 0;
  late String _serviceType;
  int? _startMonth;
  int? _startYear;
  String? _filePath;
  String? _fileName;
  ImportPreview? _preview;
  ImportValidationResult? _validation;
  ImportDryRunResult? _dryRunResult;
  ImportCommitResult? _commitResult;

  // Loading flags
  bool _parsing = false;
  bool _validating = false;
  bool _dryRunning = false;
  bool _importing = false;
  int _importProgress = 0;
  int _importTotal = 0;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _serviceType = widget.preselectedService ?? AppModeService().mode.key;
    _startMonth = null;
    _startYear = null;
  }

  void _nextStep() {
    if (_currentStep < 5) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _errorMessage = null;
        _currentStep--;
      });
    }
  }

  // Step 1 → 2: Pick file
  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    if (picked == null || picked.files.single.path == null) return;

    setState(() {
      _filePath = picked.files.single.path!;
      _fileName = picked.files.single.name;
      _parsing = true;
      _errorMessage = null;
    });

    try {
      final preview = await _importService.preview(_filePath!);
      if (!mounted) return;

      if (preview.format == ImportFormat.unknown ||
          preview.subscriberCount == 0) {
        setState(() {
          _parsing = false;
          _errorMessage = context.tr('unrecognized_file');
        });
        return;
      }

      setState(() {
        _preview = preview;
        _parsing = false;
      });

      // Auto-advance to mapping step
      _nextStep();
      _runValidation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _parsing = false;
        _errorMessage = context.tr('failed_read_file', {'error': e});
      });
    }
  }

  // Step 2 → 3: Validate mappings
  Future<void> _runValidation() async {
    if (_preview == null) return;

    setState(() {
      _validating = true;
      _errorMessage = null;
    });

    try {
      final validation = _importService.validate(_preview!, _serviceType);
      if (!mounted) return;

      setState(() {
        _validation = validation;
        _validating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _validating = false;
        _errorMessage = context.tr('validation_failed', {'error': e});
      });
    }
  }

  // Step 3 → 4: Dry run (with auto-ID prompt for fiber)
  Future<void> _runDryRun() async {
    if (_preview == null) return;

    // Check if fiber records are missing IDs
    final needsAutoId =
        _serviceType == 'fiber' &&
        _validation != null &&
        _validation!.missingIdCount > 0;

    if (needsAutoId) {
      final accepted = await _showAutoIdDialog(_validation!.missingIdCount);
      if (!accepted || !mounted) return;

      // Apply auto-generated IDs to the preview
      final patched = _importService.applyAutoIds(_preview!, _serviceType);
      setState(() => _preview = patched);

      // Re-validate with the patched preview
      final revalidation = _importService.validate(patched, _serviceType);
      setState(() => _validation = revalidation);
    }

    setState(() {
      _dryRunning = true;
      _errorMessage = null;
    });
    _nextStep();

    try {
      final result = await _importService.dryRun(_preview!, _serviceType);
      if (!mounted) return;

      setState(() {
        _dryRunResult = result;
        _dryRunning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dryRunning = false;
        _errorMessage = context.tr('dry_run_failed', {'error': e});
      });
    }
  }

  /// Friendly dialog explaining auto-ID to the user.
  Future<bool> _showAutoIdDialog(int count) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: Icon(
                PhosphorIcons.identificationBadge(PhosphorIconsStyle.duotone),
                size: 48,
                color: const Color(0xFFF57C00),
              ),
              title: Text(
                context.tr('some_no_id'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIcons.info(PhosphorIconsStyle.bold),
                          size: 20,
                          color: const Color(0xFFF57C00),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.tr('subscribers_without_id', {
                              'count': count,
                            }),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('auto_id_explanation'),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    context.tr('back_action'),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: Icon(
                    PhosphorIcons.sparkle(PhosphorIconsStyle.bold),
                    size: 16,
                  ),
                  label: Text(context.tr('use_auto_ids')),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // Step 4 → 5: Execute import
  Future<void> _executeImport() async {
    if (_preview == null) return;

    setState(() {
      _importing = true;
      _importProgress = 0;
      _importTotal = _preview!.subscriberCount;
      _errorMessage = null;
    });
    _nextStep();

    try {
      final result = await _importService.commit(
        _preview!,
        _serviceType,
        _fileName ?? 'unknown',
        defaultStartMonth: _startMonth!,
        defaultStartYear: _startYear!,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _importProgress = current;
              _importTotal = total;
            });
          }
        },
      );
      if (!mounted) return;

      setState(() {
        _commitResult = result;
        _importing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _errorMessage = context.tr('import_failed_error', {'error': e});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final mode = _serviceType == 'tv' ? ServiceMode.tv : ServiceMode.fiber;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(key: AppKeys.importBack),
        title: Row(
          children: [
            Icon(mode.icon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('import_subscribers_title', {
                  'service': context.tr(
                    mode == ServiceMode.tv ? 'cable_tv' : 'internet',
                  ),
                }),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Step indicator
          _buildStepIndicator(primary),
          // Content
          Expanded(child: _buildStepContent()),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(Color primary) {
    final labels = [
      context.tr('step_service'),
      context.tr('step_file'),
      context.tr('step_mapping'),
      context.tr('step_preview'),
      context.tr('step_import'),
      context.tr('done'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).appBarTheme.backgroundColor?.withAlpha(25),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isActive = i == _currentStep;
          final isPast = i < _currentStep;
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isPast
                        ? const Color(0xFF2E7D32)
                        : isActive
                        ? primary
                        : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isPast
                        ? Icon(
                            PhosphorIcons.check(PhosphorIconsStyle.bold),
                            size: 14,
                            color: Colors.white,
                          )
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? primary : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    return switch (_currentStep) {
      0 => _buildServiceStep(),
      1 => _buildFileStep(),
      2 => _buildMappingStep(),
      3 => _buildDryRunStep(),
      4 => _buildImportStep(),
      5 => _buildDoneStep(),
      _ => const SizedBox.shrink(),
    };
  }

  // ---- Step 0: Select Service ----
  Widget _buildServiceStep() {
    final primary = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            PhosphorIcons.upload(PhosphorIconsStyle.duotone),
            size: 56,
            color: primary,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('import_subscribers'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('import_service_help'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          _serviceOption(
            ServiceMode.tv,
            context.tr('cable_tv'),
            context.tr('import_tv_option'),
            primary,
          ),
          const SizedBox(height: 12),
          _serviceOption(
            ServiceMode.fiber,
            context.tr('internet'),
            context.tr('import_internet_option'),
            primary,
          ),
          const SizedBox(height: 24),
          _buildStartMonthPicker(primary),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              key: AppKeys.importContinue,
              onPressed: (_startMonth != null && _startYear != null)
                  ? _nextStep
                  : null,
              child: Text(context.tr('continue')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceOption(
    ServiceMode mode,
    String label,
    String subtitle,
    Color primary,
  ) {
    final selected = _serviceType == mode.key;
    return GestureDetector(
      key: mode == ServiceMode.tv ? AppKeys.importTv : AppKeys.importFiber,
      onTap: () => setState(() => _serviceType = mode.key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? primary.withAlpha(15) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              mode.icon,
              size: 24,
              color: selected ? primary : Colors.grey.shade500,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
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
                PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                color: primary,
                size: 22,
              )
            else
              Icon(
                PhosphorIcons.circle(PhosphorIconsStyle.bold),
                color: Colors.grey.shade300,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartMonthPicker(Color primary) {
    final now = DateTime.now();
    // Allow current year and previous year
    final years = [now.year - 1, now.year];
    final hasSelection = _startMonth != null && _startYear != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withAlpha(8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIcons.calendarBlank(PhosphorIconsStyle.bold),
                size: 18,
                color: primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr('start_counting_from'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('start_counting_help'),
            style: TextStyle(
              fontSize: 12,
              color: hasSelection
                  ? Colors.grey.shade500
                  : const Color(0xFFC62828),
              fontWeight: hasSelection ? FontWeight.normal : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      key: AppKeys.importStartMonth,
                      value: _startMonth,
                      isExpanded: true,
                      hint: Text(
                        context.tr('select_month'),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                      items: List.generate(12, (i) {
                        return DropdownMenuItem(
                          value: i + 1,
                          child: Text(context.monthName(i + 1)),
                        );
                      }),
                      onChanged: (v) {
                        if (v != null) setState(() => _startMonth = v);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      key: AppKeys.importStartYear,
                      value: _startYear,
                      isExpanded: true,
                      hint: Text(
                        context.tr('select_year'),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                      items: years.map((y) {
                        return DropdownMenuItem(value: y, child: Text('$y'));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _startYear = v);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Step 1: Pick File ----
  Widget _buildFileStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('select_file'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('select_file_help'),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),

          if (_parsing)
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(context.tr('reading_file')),
                ],
              ),
            )
          else ...[
            GestureDetector(
              key: AppKeys.importPickFile,
              onTap: _pickFile,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1.5,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIcons.fileArrowUp(PhosphorIconsStyle.duotone),
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('tap_select_file'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '.xlsx  ·  .xls  ·  .csv',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    PhosphorIcons.fileXls(PhosphorIconsStyle.bold),
                    size: 18,
                    color: const Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _fileName!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _errorBox(_errorMessage!),
          ],

          const Spacer(),
          Row(
            children: [
              TextButton(
                onPressed: _prevStep,
                child: Text(context.tr('back_action')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Step 2: Mapping Preview ----
  Widget _buildMappingStep() {
    if (_validating) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(context.tr('validating_mappings')),
          ],
        ),
      );
    }

    final validation = _validation;
    final preview = _preview;
    if (validation == null || preview == null) {
      return Center(
        child: Text(
          _errorMessage ?? context.tr('no_data_validate'),
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('column_mapping'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _infoRow(context.tr('format'), _formatLabel(preview.format)),
          _infoRow(context.tr('total_rows'), '${validation.totalRows}'),
          _infoRow(context.tr('valid_rows'), '${validation.validRows}'),
          if (validation.errors.isNotEmpty)
            _infoRow(context.tr('issues'), '${validation.errors.length}'),

          const SizedBox(height: 16),
          Text(
            context.tr('field_mappings'),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...validation.mappings.map(_buildMappingTile),

          if (validation.errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              context.tr('validation_issues'),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.builder(
                itemCount: validation.errors.length > 20
                    ? 20
                    : validation.errors.length,
                itemBuilder: (_, i) {
                  final err = validation.errors[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIcons.warning(PhosphorIconsStyle.bold),
                          size: 14,
                          color: const Color(0xFFE65100),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.tr('row_issue', {
                              'row': err.rowNumber,
                              'reason': AppLanguageService.instance
                                  .importReason(err.reason),
                            }),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (validation.errors.length > 20)
              Text(
                context.tr('and_more_issues', {
                  'count': validation.errors.length - 20,
                }),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
          ],

          // Hint about missing IDs for fiber
          if (_serviceType == 'fiber' && validation.missingIdCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.identificationBadge(PhosphorIconsStyle.bold),
                    size: 18,
                    color: const Color(0xFFF57C00),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('missing_ids_next', {
                        'count': validation.missingIdCount,
                      }),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),
          Row(
            children: [
              TextButton(
                onPressed: _prevStep,
                child: Text(context.tr('back_action')),
              ),
              const Spacer(),
              FilledButton(
                onPressed: validation.canProceed ? _runDryRun : null,
                child: Text(context.tr('analyze_import')),
              ),
            ],
          ),
          if (!validation.canProceed) ...[
            const SizedBox(height: 8),
            Text(
              context.tr('too_many_invalid'),
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMappingTile(FieldMapping mapping) {
    final color = mapping.isResolved
        ? const Color(0xFF2E7D32)
        : mapping.isRequired
        ? Colors.red.shade700
        : Colors.orange.shade700;
    final icon = mapping.isResolved
        ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
        : mapping.isRequired
        ? PhosphorIcons.xCircle(PhosphorIconsStyle.fill)
        : PhosphorIcons.warning(PhosphorIconsStyle.fill);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLanguageService.instance.importField(
                      mapping.targetField,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  if (mapping.sourceColumn != null)
                    Text(
                      '← ${AppLanguageService.instance.importSourceColumn(mapping.sourceColumn!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '${(mapping.confidence * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Step 3: Dry Run Results ----
  Widget _buildDryRunStep() {
    if (_dryRunning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(context.tr('analyzing_import')),
          ],
        ),
      );
    }

    final result = _dryRunResult;
    if (result == null) {
      return Center(child: Text(_errorMessage ?? context.tr('no_results')));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('import_preview'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('review_import'),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          _countCard(
            context.tr('new_subscribers'),
            result.insertCount,
            PhosphorIcons.userPlus(PhosphorIconsStyle.bold),
            const Color(0xFF2E7D32),
          ),
          _countCard(
            context.tr('updates'),
            result.updateCount,
            PhosphorIcons.arrowsClockwise(PhosphorIconsStyle.bold),
            const Color(0xFF1565C0),
          ),
          if (result.rejectCount > 0)
            _countCard(
              context.tr('rejected'),
              result.rejectCount,
              PhosphorIcons.xCircle(PhosphorIconsStyle.bold),
              Colors.red.shade700,
            ),
          if (result.conflictCount > 0)
            _countCard(
              context.tr('conflicts'),
              result.conflictCount,
              PhosphorIcons.warning(PhosphorIconsStyle.bold),
              Colors.orange.shade700,
            ),

          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              context.tr('issues_found'),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: result.errors.length,
                itemBuilder: (_, i) {
                  final err = result.errors[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      context.tr('row_issue', {
                        'row': err.rowNumber,
                        'reason': AppLanguageService.instance.importReason(
                          err.reason,
                        ),
                      }),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else
            const Spacer(),

          Row(
            children: [
              TextButton(
                onPressed: _prevStep,
                child: Text(context.tr('back_action')),
              ),
              const Spacer(),
              FilledButton(
                onPressed: (result.insertCount + result.updateCount > 0)
                    ? _executeImport
                    : null,
                child: Text(
                  context.tr('import_n_subscribers', {
                    'count': result.insertCount + result.updateCount,
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatLabel(ImportFormat format) {
    final key = switch (format) {
      ImportFormat.book1 => 'format_book1',
      ImportFormat.activePackages => 'format_active_packages',
      ImportFormat.totalList => 'format_total_list',
      ImportFormat.csv => 'format_csv',
      ImportFormat.unknown => 'format_unknown',
    };
    return context.tr(key);
  }

  Widget _countCard(String label, int count, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withAlpha(10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
            const Spacer(),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Step 4: Import Progress ----
  Widget _buildImportStep() {
    if (_importing) {
      final progress = _importTotal > 0 ? _importProgress / _importTotal : 0.0;

      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('importing'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('rows_progress', {
                'current': _importProgress,
                'total': _importTotal,
              }),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // Completed (this shouldn't show long — auto-advance to done)
    if (_commitResult != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_currentStep == 4 && mounted) {
          _nextStep();
        }
      });
    }

    if (_errorMessage != null) {
      return Center(child: _errorBox(_errorMessage!));
    }

    return const Center(child: CircularProgressIndicator());
  }

  // ---- Step 5: Done ----
  Widget _buildDoneStep() {
    final result = _commitResult;
    if (result == null) {
      return Center(
        child: _errorMessage != null
            ? _errorBox(_errorMessage!)
            : Text(context.tr('no_results')),
      );
    }

    final success = result.inserted + result.updated > 0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Icon(
            success
                ? PhosphorIcons.checkCircle(PhosphorIconsStyle.duotone)
                : PhosphorIcons.xCircle(PhosphorIconsStyle.duotone),
            size: 64,
            color: success ? const Color(0xFF2E7D32) : Colors.red.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(success ? 'import_complete' : 'import_failed'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: success ? const Color(0xFF2E7D32) : Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 24),
          _countCard(
            context.tr('added'),
            result.inserted,
            PhosphorIcons.userPlus(PhosphorIconsStyle.bold),
            const Color(0xFF2E7D32),
          ),
          _countCard(
            context.tr('updated'),
            result.updated,
            PhosphorIcons.arrowsClockwise(PhosphorIconsStyle.bold),
            const Color(0xFF1565C0),
          ),
          if (result.payments > 0)
            _countCard(
              context.tr('payments'),
              result.payments,
              PhosphorIcons.currencyInr(PhosphorIconsStyle.bold),
              Colors.purple,
            ),
          if (result.rejected > 0)
            _countCard(
              context.tr('rejected'),
              result.rejected,
              PhosphorIcons.xCircle(PhosphorIconsStyle.bold),
              Colors.red.shade700,
            ),
          if (result.conflicts > 0)
            _countCard(
              context.tr('conflicts'),
              result.conflicts,
              PhosphorIcons.warning(PhosphorIconsStyle.bold),
              Colors.orange.shade700,
            ),

          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              context.tr('issues_logged', {'count': result.errors.length}),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],

          const Spacer(),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('done')),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Shared Helpers ----

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            PhosphorIcons.warning(PhosphorIconsStyle.bold),
            size: 18,
            color: Colors.red.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.red.shade800),
            ),
          ),
        ],
      ),
    );
  }
}
