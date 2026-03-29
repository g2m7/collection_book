import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/subscriber.dart';
import '../models/payment.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class SubscriberDetailScreen extends StatefulWidget {
  final int subscriberId;
  const SubscriberDetailScreen({super.key, required this.subscriberId});

  @override
  State<SubscriberDetailScreen> createState() => _SubscriberDetailScreenState();
}

class _SubscriberDetailScreenState extends State<SubscriberDetailScreen> {
  final _db = DatabaseService();
  Subscriber? _subscriber;
  List<Payment> _payments = [];
  bool _loading = true;
  late int _year;

  static const _monthShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final sub = await _db.getSubscriber(widget.subscriberId);
    final payments = await _db.getPaymentsForSubscriber(
      widget.subscriberId,
      year: _year,
    );
    setState(() {
      _subscriber = sub;
      _payments = payments;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subscriber')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sub = _subscriber;
    if (sub == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subscriber')),
        body: const Center(child: Text('Subscriber not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(sub.name),
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold)),
            tooltip: 'Edit',
            onPressed: () => Navigator.pushNamed(
              context,
              '/add-subscriber',
              arguments: sub.id,
            ).then((_) => _loadData()),
          ),
          IconButton(
            icon: Icon(PhosphorIcons.trash(PhosphorIconsStyle.bold)),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(sub),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            _buildInfoSection(sub),
            _buildYearSelector(),
            _buildPaymentGrid(sub),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(
          context,
          '/record-payment',
          arguments: {'subscriberId': sub.id, 'subscriberName': sub.name},
        ).then((_) => _loadData()),
        icon: Icon(PhosphorIcons.currencyInr(PhosphorIconsStyle.bold)),
        label: const Text('Record Payment'),
      ),
    );
  }

  Widget _buildInfoSection(Subscriber sub) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    sub.name.isNotEmpty ? sub.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (sub.aliasName != null && sub.aliasName!.isNotEmpty)
                      Text(
                        sub.aliasName!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: sub.isActive
                      ? AppTheme.paid.withAlpha(25)
                      : Colors.grey.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  sub.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sub.isActive ? AppTheme.paid : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _infoRow('Area', sub.areaName ?? 'N/A'),
          _infoRow('Monthly Rent', _currencyFormat.format(sub.monthlyRent)),
          _infoRow('Previous Due', _currencyFormat.format(sub.previousDue)),
          if (sub.vcNumber != null && sub.vcNumber!.isNotEmpty)
            _infoRow('VC Number', sub.vcNumber!),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.bold)),
            onPressed: () {
              setState(() => _year--);
              _loadData();
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Year $_year',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1565C0),
              ),
            ),
          ),
          IconButton(
            icon: Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold)),
            onPressed: () {
              setState(() => _year++);
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentGrid(Subscriber sub) {
    final paymentMap = {for (final p in _payments) p.month: p};
    double runningDue = sub.previousDue;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Month',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Paid',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Adj',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Due',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...List.generate(12, (i) {
            final month = i + 1;
            final payment = paymentMap[month];
            final paid = payment?.amountPaid ?? 0;
            final adj = payment?.adjustment ?? 0;
            runningDue = runningDue + sub.monthlyRent + adj - paid;
            final dueColor = AppTheme.dueColor(runningDue);
            final isCurrentMonth =
                month == DateTime.now().month && _year == DateTime.now().year;

            return InkWell(
              onTap: () => Navigator.pushNamed(
                context,
                '/record-payment',
                arguments: {
                  'subscriberId': sub.id,
                  'subscriberName': sub.name,
                  'month': month,
                  'year': _year,
                },
              ).then((_) => _loadData()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isCurrentMonth
                      ? const Color(0xFF1565C0).withAlpha(13)
                      : null,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade200,
                      width: i < 11 ? 1 : 0,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          if (isCurrentMonth)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1565C0),
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            _monthShort[i],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isCurrentMonth
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        payment != null ? _currencyFormat.format(paid) : '—',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          color: payment != null
                              ? AppTheme.paid
                              : Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        adj != 0 ? _currencyFormat.format(adj) : '—',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          color: adj != 0
                              ? AppTheme.partial
                              : Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _currencyFormat.format(runningDue),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: dueColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Subscriber sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subscriber?'),
        content: Text(
          'This will permanently delete ${sub.name} and all their payment history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.unpaid),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _db.deleteSubscriber(sub.id!);
      if (mounted) Navigator.pop(context);
    }
  }
}
