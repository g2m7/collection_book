import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/subscriber.dart';
import '../models/payment.dart';
import '../services/database_service.dart';
import '../services/receipt_settings_service.dart';
import '../services/whatsapp_receipt_service.dart';
import '../theme/app_theme.dart';
import '../app_keys.dart';
import '../services/app_language_service.dart';

class SubscriberDetailScreen extends StatefulWidget {
  final int subscriberId;
  const SubscriberDetailScreen({super.key, required this.subscriberId});

  @override
  State<SubscriberDetailScreen> createState() => _SubscriberDetailScreenState();
}

class _SubscriberDetailScreenState extends State<SubscriberDetailScreen> {
  final _db = DatabaseService();
  final _receiptSettings = ReceiptSettingsService();
  final _receiptService = WhatsAppReceiptService();
  Subscriber? _subscriber;
  List<Payment> _payments = [];
  bool _loading = true;
  late int _year;
  double _yearStartDue = 0;
  int? _sendingReceiptMonth;
  bool _sendingReceipt = false;

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
    final yearStartDue = await _db.getYearStartBalance(
      widget.subscriberId,
      _year,
    );
    if (!mounted) return;
    setState(() {
      _subscriber = sub;
      _payments = payments;
      _yearStartDue = yearStartDue;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('subscriber'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sub = _subscriber;
    if (sub == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('subscriber'))),
        body: Center(child: Text(context.tr('subscriber_not_found'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(sub.name),
        actions: [
          IconButton(
            key: AppKeys.subscriberDetailEdit,
            icon: Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold)),
            tooltip: context.tr('edit'),
            onPressed: () => Navigator.pushNamed(
              context,
              '/add-subscriber',
              arguments: sub.id,
            ).then((_) => _loadData()),
          ),
          IconButton(
            key: AppKeys.subscriberDetailDelete,
            icon: Icon(PhosphorIcons.trash(PhosphorIconsStyle.bold)),
            tooltip: context.tr('delete'),
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
        key: AppKeys.subscriberDetailRecordPayment,
        onPressed: () => Navigator.pushNamed(
          context,
          '/record-payment',
          arguments: {
            'subscriberId': sub.id,
            'subscriberName': sub.name,
            'year': _year,
          },
        ).then((_) => _loadData()),
        icon: Icon(PhosphorIcons.currencyInr(PhosphorIconsStyle.bold)),
        label: Text(context.tr('record_payment')),
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
                  context.tr(sub.isActive ? 'active' : 'inactive'),
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
          _infoRow(context.tr('area'), sub.areaName ?? 'N/A'),
          _infoRow(
            context.tr('monthly_rent'),
            _currencyFormat.format(sub.monthlyRent),
          ),
          _infoRow(
            context.tr('previous_due'),
            _currencyFormat.format(sub.previousDue),
          ),
          if (sub.vcNumber != null && sub.vcNumber!.isNotEmpty)
            _infoRow(context.tr('vc_number'), sub.vcNumber!),
          if (sub.phone != null && sub.phone!.isNotEmpty)
            _infoRow(context.tr('whatsapp_phone'), sub.phone!),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Flexible(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
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
    final sub = _subscriber;
    final created = _parseCreatedAt(sub?.createdAt);
    final firstYear = sub?.startYear ?? created?.year;
    final canGoBack = firstYear == null || _year > firstYear;
    final canGoForward = _year < DateTime.now().year + 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: AppKeys.subscriberDetailYearPrevious,
            icon: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.bold)),
            onPressed: canGoBack
                ? () {
                    setState(() => _year--);
                    _loadData();
                  }
                : null,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              context.tr('year_value', {'year': _year}),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1565C0),
              ),
            ),
          ),
          IconButton(
            key: AppKeys.subscriberDetailYearNext,
            icon: Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold)),
            onPressed: canGoForward
                ? () {
                    setState(() => _year++);
                    _loadData();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentGrid(Subscriber sub) {
    final paymentMap = {for (final p in _payments) p.month: p};
    final created = _parseCreatedAt(sub.createdAt);

    // Determine effective start year/month from explicit start fields,
    // falling back to created_at timestamp.
    final effectiveStartYear = sub.startYear ?? created?.year;
    final effectiveStartMonth = sub.startMonth ?? created?.month;

    // Determine first month to display.
    final isStartYear =
        effectiveStartYear != null && _year == effectiveStartYear;
    final firstMonth = isStartYear ? (effectiveStartMonth ?? 1) : 1;
    final monthCount = 12 - firstMonth + 1;

    // If viewing a year before subscriber start, show nothing.
    if (effectiveStartYear != null && _year < effectiveStartYear) {
      final label = effectiveStartMonth != null
          ? '${context.monthName(effectiveStartMonth, short: true)} $effectiveStartYear'
          : '$effectiveStartYear';
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            context.tr('subscriber_starts_from', {'date': label}),
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    double runningDue = _yearStartDue;

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
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    context.tr('month'),
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    context.tr('paid'),
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: Text(
                    context.tr('adj'),
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: Text(
                    context.tr('due'),
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(width: 44),
              ],
            ),
          ),
          const Divider(height: 1),
          ...List.generate(monthCount, (i) {
            final month = firstMonth + i;
            final payment = paymentMap[month];
            final paid = payment?.amountPaid ?? 0;
            final adj = payment?.adjustment ?? 0;
            runningDue = runningDue + sub.monthlyRent + adj - paid;
            final dueColor = AppTheme.dueColor(runningDue);
            final isCurrentMonth =
                month == DateTime.now().month && _year == DateTime.now().year;

            return InkWell(
              key: AppKeys.subscriberDetailMonth(month, _year),
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
                      width: i < monthCount - 1 ? 1 : 0,
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
                            context.monthName(month, short: true),
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
                    SizedBox(
                      width: 44,
                      child: payment == null
                          ? null
                          : IconButton(
                              key: AppKeys.subscriberDetailSendReceipt,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 40,
                                height: 40,
                              ),
                              tooltip: context.tr('send_whatsapp_receipt'),
                              onPressed: _sendingReceipt
                                  ? null
                                  : () => _sendReceipt(payment, runningDue),
                              icon: _sendingReceiptMonth == month
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      PhosphorIcons.whatsappLogo(
                                        PhosphorIconsStyle.fill,
                                      ),
                                      size: 21,
                                      color: const Color(0xFF25D366),
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

  Future<void> _sendReceipt(Payment payment, double balanceAfterPayment) async {
    final subscriber = _subscriber;
    if (subscriber == null) return;

    final phone = WhatsAppReceiptService.normalizeIndianPhone(subscriber.phone);
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('receipt_not_sent_phone'))),
      );
      return;
    }

    setState(() {
      _sendingReceipt = true;
      _sendingReceiptMonth = payment.month;
    });
    try {
      final referralCode = await _receiptSettings.getReferralCode();
      final message = WhatsAppReceiptService.buildReceiptText(
        organizationName: _receiptSettings.businessNameNotifier.value,
        subscriber: subscriber,
        payment: payment,
        balanceAfterPayment: balanceAfterPayment,
        language: AppLanguageService.instance.receiptLanguage,
        referralCode: referralCode,
      );
      final result = await _receiptService.launch(
        phone: phone,
        message: message,
        serviceType: subscriber.serviceType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.usedWebFallback
                ? context.tr('receipt_review_browser')
                : context.tr('receipt_review_whatsapp'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('whatsapp_error', {'error': error})),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingReceipt = false;
          _sendingReceiptMonth = null;
        });
      }
    }
  }

  Future<void> _confirmDelete(Subscriber sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('delete_subscriber')),
        content: Text(
          context.tr('delete_subscriber_message', {'name': sub.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.unpaid),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _db.deleteSubscriber(sub.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  DateTime? _parseCreatedAt(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value) ??
        DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }
}
