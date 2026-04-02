import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/import_result.dart';
import '../services/import_service.dart';
import '../services/app_mode_service.dart';

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
          _errorMessage =
              'Unrecognized file format or no data found. Try a different file.';
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
        _errorMessage = 'Failed to read file: $e';
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
        _errorMessage = 'Validation failed: $e';
      });
    }
  }

  // Step 3 → 4: Dry run
  Future<void> _runDryRun() async {
    if (_preview == null) return;

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
        _errorMessage = 'Dry run failed: $e';
      });
    }
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
        _errorMessage = 'Import failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final mode = _serviceType == 'tv' ? ServiceMode.tv : ServiceMode.fiber;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(mode.icon, size: 20),
            const SizedBox(width: 8),
            Text('Import ${mode.label} Subscribers'),
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
    const labels = ['Service', 'File', 'Mapping', 'Preview', 'Import', 'Done'];

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

    return Padding(
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
          const Text(
            'Import Subscribers',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the service type for this import. Subscribers will be imported strictly into the selected service.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          _serviceOption(
            ServiceMode.tv,
            'Cable TV',
            'Import TV subscribers with VC/STB numbers',
            primary,
          ),
          const SizedBox(height: 12),
          _serviceOption(
            ServiceMode.fiber,
            'Internet / Fiber',
            'Import Internet subscribers with account IDs',
            primary,
          ),
          const Spacer(),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _nextStep,
              child: const Text('Continue'),
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

  // ---- Step 1: Pick File ----
  Widget _buildFileStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Select File',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose an Excel (.xlsx, .xls) or CSV file to import.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),

          if (_parsing)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Reading file…'),
                ],
              ),
            )
          else ...[
            GestureDetector(
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
                        'Tap to Select File',
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
              TextButton(onPressed: _prevStep, child: const Text('Back')),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Step 2: Mapping Preview ----
  Widget _buildMappingStep() {
    if (_validating) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Validating mappings…'),
          ],
        ),
      );
    }

    final validation = _validation;
    final preview = _preview;
    if (validation == null || preview == null) {
      return Center(
        child: Text(
          _errorMessage ?? 'No data to validate.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Column Mapping',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _infoRow('Format', preview.formatLabel),
          _infoRow('Total Rows', '${validation.totalRows}'),
          _infoRow('Valid Rows', '${validation.validRows}'),
          if (validation.errors.isNotEmpty)
            _infoRow('Issues', '${validation.errors.length}'),

          const SizedBox(height: 16),
          const Text(
            'Field Mappings',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...validation.mappings.map(_buildMappingTile),

          if (validation.errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Validation Issues',
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
                            'Row ${err.rowNumber}: ${err.reason}',
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
                '…and ${validation.errors.length - 20} more issues',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
          ],

          const Spacer(),
          Row(
            children: [
              TextButton(onPressed: _prevStep, child: const Text('Back')),
              const Spacer(),
              FilledButton(
                onPressed: validation.canProceed ? _runDryRun : null,
                child: const Text('Analyze Import'),
              ),
            ],
          ),
          if (!validation.canProceed) ...[
            const SizedBox(height: 8),
            Text(
              'Too many invalid rows. Fix the file and try again.',
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
                    mapping.targetField,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  if (mapping.sourceColumn != null)
                    Text(
                      '← ${mapping.sourceColumn}',
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
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing import…'),
          ],
        ),
      );
    }

    final result = _dryRunResult;
    if (result == null) {
      return Center(child: Text(_errorMessage ?? 'No results.'));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Import Preview',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Review what will happen before importing.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          _countCard(
            'New Subscribers',
            result.insertCount,
            PhosphorIcons.userPlus(PhosphorIconsStyle.bold),
            const Color(0xFF2E7D32),
          ),
          _countCard(
            'Updates',
            result.updateCount,
            PhosphorIcons.arrowsClockwise(PhosphorIconsStyle.bold),
            const Color(0xFF1565C0),
          ),
          if (result.rejectCount > 0)
            _countCard(
              'Rejected',
              result.rejectCount,
              PhosphorIcons.xCircle(PhosphorIconsStyle.bold),
              Colors.red.shade700,
            ),
          if (result.conflictCount > 0)
            _countCard(
              'Conflicts',
              result.conflictCount,
              PhosphorIcons.warning(PhosphorIconsStyle.bold),
              Colors.orange.shade700,
            ),

          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Issues Found',
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
                      err.toString(),
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
              TextButton(onPressed: _prevStep, child: const Text('Back')),
              const Spacer(),
              FilledButton(
                onPressed: (result.insertCount + result.updateCount > 0)
                    ? _executeImport
                    : null,
                child: Text(
                  'Import ${result.insertCount + result.updateCount} Subscribers',
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
            const Text(
              'Importing…',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '$_importProgress of $_importTotal rows',
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
            : const Text('No results.'),
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
            success ? 'Import Complete' : 'Import Failed',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: success ? const Color(0xFF2E7D32) : Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 24),
          _countCard(
            'Added',
            result.inserted,
            PhosphorIcons.userPlus(PhosphorIconsStyle.bold),
            const Color(0xFF2E7D32),
          ),
          _countCard(
            'Updated',
            result.updated,
            PhosphorIcons.arrowsClockwise(PhosphorIconsStyle.bold),
            const Color(0xFF1565C0),
          ),
          if (result.payments > 0)
            _countCard(
              'Payments',
              result.payments,
              PhosphorIcons.currencyInr(PhosphorIconsStyle.bold),
              Colors.purple,
            ),
          if (result.rejected > 0)
            _countCard(
              'Rejected',
              result.rejected,
              PhosphorIcons.xCircle(PhosphorIconsStyle.bold),
              Colors.red.shade700,
            ),
          if (result.conflicts > 0)
            _countCard(
              'Conflicts',
              result.conflicts,
              PhosphorIcons.warning(PhosphorIconsStyle.bold),
              Colors.orange.shade700,
            ),

          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${result.errors.length} issue(s) logged to Import History.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],

          const Spacer(),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
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
