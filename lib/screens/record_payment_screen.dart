import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/subscriber.dart';
import '../models/payment.dart';
import '../services/database_service.dart';

class RecordPaymentScreen extends StatefulWidget {
  final int? subscriberId;
  final String? subscriberName;

  const RecordPaymentScreen({
    super.key,
    this.subscriberId,
    this.subscriberName,
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
    _month = now.month;
    _year = now.year;
    _loadSubscribers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      if (args.containsKey('month')) _month = args['month'] as int;
      if (args.containsKey('year')) _year = args['year'] as int;
    }
  }

  Future<void> _loadSubscribers() async {
    final subs = await _db.getSubscribers(isActive: true);
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
    setState(() {
      _existingPayment = payment;
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
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          initialValue: _month,
                          decoration: const InputDecoration(),
                          items: List.generate(12, (i) {
                            return DropdownMenuItem(
                              value: i + 1,
                              child: Text(_monthNames[i]),
                            );
                          }),
                          onChanged: (v) {
                            setState(() => _month = v!);
                            _loadExistingPayment();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _year,
                          decoration: const InputDecoration(),
                          items: List.generate(5, (i) {
                            final y = DateTime.now().year - 2 + i;
                            return DropdownMenuItem(
                              value: y,
                              child: Text('$y'),
                            );
                          }),
                          onChanged: (v) {
                            setState(() => _year = v!);
                            _loadExistingPayment();
                          },
                        ),
                      ),
                    ],
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
                    autofocus: widget.subscriberId != null,
                  ),

                  const SizedBox(height: 20),

                  // Adjustment
                  Text(
                    'Adjustment (optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
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
                      hintText:
                          '0 (positive = extra charge, negative = discount)…',
                    ),
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
                        await _db.deletePayment(_existingPayment!.id!);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Payment deleted')),
                          );
                          Navigator.pop(context);
                        }
                      },
                      icon: Icon(PhosphorIcons.trash(PhosphorIconsStyle.bold), size: 18),
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
