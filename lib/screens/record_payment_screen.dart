import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/subscriber.dart';
import '../models/payment.dart';
import '../services/database_service.dart';
import '../services/app_mode_service.dart';

class RecordPaymentScreen extends StatefulWidget {
  final int? subscriberId;
  final String? subscriberName;
  final int? initialMonth;
  final int? initialYear;

  const RecordPaymentScreen({
    super.key,
    this.subscriberId,
    this.subscriberName,
    this.initialMonth,
    this.initialYear,
  });

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _adjustmentController = TextEditingController();
  final _noteController = TextEditingController();

  List<Subscriber> _subscribers = [];
  Subscriber? _selectedSubscriber;
  late int _month;
  late int _year;
  bool _loading = true;
  bool _saving = false;
  Payment? _existingPayment;
  double _dueBeforePayment = 0;

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = widget.initialMonth ?? now.month;
    _year = widget.initialYear ?? now.year;
    _loadSubscribers();
  }

  Future<void> _loadSubscribers() async {
    final serviceType = AppModeService().mode.key;
    final subs = await _db.getSubscribers(
      isActive: true,
      serviceType: serviceType,
    );
    setState(() {
      _subscribers = subs;
      if (widget.subscriberId != null) {
        _selectedSubscriber = subs.firstWhere(
          (s) => s.id == widget.subscriberId,
          orElse: () => subs.first,
        );
      }
      _loading = false;
    });
    _loadExistingPayment();
  }

  Future<void> _loadExistingPayment() async {
    if (_selectedSubscriber == null) return;
    final payment = await _db.getPayment(
      _selectedSubscriber!.id!,
      _year,
      _month,
    );

    final dueAtMonthEnd = await _db.calculateDue(
      _selectedSubscriber!.id!,
      _year,
      _month,
    );

    final dueBeforePayment = payment == null
        ? dueAtMonthEnd
        : dueAtMonthEnd + payment.amountPaid - payment.adjustment;

    if (!mounted) return;

    setState(() {
      _existingPayment = payment;
      _dueBeforePayment = dueBeforePayment;
      if (payment != null) {
        _amountController.text = payment.amountPaid.toStringAsFixed(0);
        _adjustmentController.text = payment.adjustment != 0
            ? payment.adjustment.toStringAsFixed(0)
            : '';
        _noteController.text = payment.adjustmentNote ?? '';
      } else {
        _amountController.text = _selectedSubscriber!.monthlyRent
            .toStringAsFixed(0);
        _adjustmentController.clear();
        _noteController.clear();
      }
    });
  }

  void _setAmountToClearDue() {
    final adj = double.tryParse(_adjustmentController.text) ?? 0;
    final amount = (_dueBeforePayment + adj).clamp(0, double.infinity);
    setState(() {
      _amountController.text = amount.toStringAsFixed(0);
    });
  }

  Future<void> _openClearDueHelper() async {
    final adj = double.tryParse(_adjustmentController.text) ?? 0;
    final amount = (_dueBeforePayment + adj).clamp(0, double.infinity);

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Clear Due Helper',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  'Current due: ₹${_dueBeforePayment.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                Text(
                  'Adjustment: ₹${adj.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Suggested amount to make due 0: ₹${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, 'apply'),
                    icon: Icon(
                      PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
                      size: 16,
                    ),
                    label: const Text('Set This Amount'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, 'apply_note'),
                    icon: Icon(
                      PhosphorIcons.notePencil(PhosphorIconsStyle.bold),
                      size: 16,
                    ),
                    label: const Text('Set Amount + Add Note'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    _setAmountToClearDue();

    if (action == 'apply_note' && _noteController.text.trim().isEmpty) {
      _noteController.text = 'Auto-set amount to clear due';
    }

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Amount set to ₹${amount.toStringAsFixed(0)} to clear due.',
        ),
      ),
    );
  }

  double _projectedDueAfterSave() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final adjustment = double.tryParse(_adjustmentController.text) ?? 0;
    return _dueBeforePayment + adjustment - amount;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubscriber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a subscriber')),
      );
      return;
    }

    setState(() => _saving = true);

    final payment = Payment(
      subscriberId: _selectedSubscriber!.id!,
      year: _year,
      month: _month,
      amountPaid: double.tryParse(_amountController.text) ?? 0,
      adjustment: double.tryParse(_adjustmentController.text) ?? 0,
      adjustmentNote: _noteController.text.isNotEmpty
          ? _noteController.text
          : null,
    );

    await _db.insertOrUpdatePayment(payment);

    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment recorded for ${_selectedSubscriber!.name}'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _adjustmentController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _existingPayment != null ? 'Edit Payment' : 'Record Payment',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Subscriber selector
                  Text(
                    'Subscriber',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedSubscriber?.id,
                    decoration: const InputDecoration(
                      hintText: 'Select subscriber…',
                    ),
                    isExpanded: true,
                    items: _subscribers.map((s) {
                      return DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          '${s.name}${s.aliasName != null ? ' (${s.aliasName})' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (id) {
                      setState(() {
                        _selectedSubscriber = _subscribers.firstWhere(
                          (s) => s.id == id,
                        );
                        // Clamp to subscriber's start date
                        final sub = _selectedSubscriber!;
                        final sY = sub.startYear;
                        final sM = sub.startMonth ?? 1;
                        if (sY != null) {
                          if (_year < sY || (_year == sY && _month < sM)) {
                            _year = sY;
                            _month = sM;
                          }
                        }
                      });
                      _loadExistingPayment();
                    },
                    validator: (v) => v == null ? 'Required' : null,
                  ),

                  if (_selectedSubscriber != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Monthly Rent: ₹${_selectedSubscriber!.monthlyRent.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current due till ${_monthNames[_month - 1]} $_year: ₹${_dueBeforePayment.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Month / Year
                  Text(
                    'Month & Year',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      final sub = _selectedSubscriber;
                      final startY = sub?.startYear;
                      final startM = sub?.startMonth ?? 1;

                      // Build year list — from subscriber start year (or 3yrs back) to next year
                      final now = DateTime.now().year;
                      final minYear = startY ?? (now - 3);
                      final years = <int>{};
                      for (int y = minYear; y <= now + 1; y++) {
                        years.add(y);
                      }
                      years.add(_year);
                      final sortedYears = years.toList()..sort();

                      // Build month list — constrain if viewing the start year
                      final firstMonth = (startY != null && _year == startY)
                          ? startM
                          : 1;
                      final monthItems = List.generate(12 - firstMonth + 1, (
                        i,
                      ) {
                        final m = firstMonth + i;
                        return DropdownMenuItem(
                          value: m,
                          child: Text(_monthNames[m - 1]),
                        );
                      });

                      return Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int>(
                              key: ValueKey('month_${sub?.id}_$_year'),
                              initialValue: _month,
                              decoration: const InputDecoration(),
                              items: monthItems,
                              onChanged: (v) {
                                setState(() => _month = v!);
                                _loadExistingPayment();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              key: ValueKey('year_${sub?.id}'),
                              initialValue: _year,
                              decoration: const InputDecoration(),
                              items: sortedYears.map((y) {
                                return DropdownMenuItem(
                                  value: y,
                                  child: Text('$y'),
                                );
                              }).toList(),
                              onChanged: (v) {
                                setState(() {
                                  _year = v!;
                                  // If the month is now before the start, bump it
                                  if (startY != null &&
                                      _year == startY &&
                                      _month < startM) {
                                    _month = startM;
                                  }
                                });
                                _loadExistingPayment();
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Amount
                  Text(
                    'Amount Paid',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      prefixText: '₹ ',
                      hintText: '0',
                    ),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter amount';
                      if (double.tryParse(v) == null) return 'Invalid amount';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                    autofocus: widget.subscriberId != null,
                  ),

                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _openClearDueHelper,
                      icon: Icon(
                        PhosphorIcons.magicWand(PhosphorIconsStyle.bold),
                        size: 16,
                      ),
                      label: const Text('Clear Due Helper'),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Adjustment
                  Text(
                    'Adjustments (optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Use positive to add due (charge/previous due), negative to reduce due (discount).',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _adjustmentController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                    ],
                    decoration: const InputDecoration(
                      prefixText: '₹ ',
                      hintText: 'e.g. 1000 or -200',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      'Examples: +1000 (carry forward old due), +250 (one-time charge), -200 (discount/waiver).',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final projected = _projectedDueAfterSave();
                      final isAdvance = projected < 0;
                      final amount = projected.abs().toStringAsFixed(0);
                      final color = isAdvance
                          ? const Color(0xFF2E7D32)
                          : projected > 0
                          ? const Color(0xFFC62828)
                          : const Color(0xFF1565C0);
                      final text = projected == 0
                          ? 'After save: due becomes 0 (fully clear).'
                          : isAdvance
                          ? 'After save: advance will be ₹$amount.'
                          : 'After save: remaining due will be ₹$amount.';
                      return Row(
                        children: [
                          Icon(
                            PhosphorIcons.info(PhosphorIconsStyle.bold),
                            size: 16,
                            color: color,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              text,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Note
                  Text(
                    'Note (optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      hintText: 'e.g., new connection charge…',
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _existingPayment != null
                                  ? 'Update Payment'
                                  : 'Save Payment',
                            ),
                    ),
                  ),

                  if (_existingPayment != null) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Payment?'),
                            content: Text(
                              'This will permanently delete the payment for ${_monthNames[_month - 1]} $_year.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFC62828),
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !mounted) return;
                        await _db.deletePayment(_existingPayment!.id!);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Payment deleted')),
                          );
                          Navigator.pop(context);
                        }
                      },
                      icon: Icon(
                        PhosphorIcons.trash(PhosphorIconsStyle.bold),
                        size: 18,
                      ),
                      label: const Text('Delete this payment'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFC62828),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
