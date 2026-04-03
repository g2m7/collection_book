import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/database_service.dart';
import '../services/app_mode_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService();
  final _modeService = AppModeService();
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _areaSummary = [];
  bool _loading = true;
  late int _year;
  late int _month;
  int? _earliestYear;
  int? _earliestMonth;

  static const _months = [
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _modeService.modeNotifier.addListener(_loadData);
    _loadData();
  }

  @override
  void dispose() {
    _modeService.modeNotifier.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final mode = _modeService.mode;
    final summary = await _db.getDashboardSummary(
      _year,
      _month,
      serviceType: mode.key,
    );
    final areas = await _db.getAreaSummary(
      _year,
      _month,
      serviceType: mode.key,
    );
    final earliest = await _db.getEarliestStartDate(serviceType: mode.key);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _areaSummary = areas;
      _earliestYear = earliest?['year'];
      _earliestMonth = earliest?['month'];
      _loading = false;
    });
  }

  bool get _canGoBack {
    if (_earliestYear == null) return true;
    if (_year > _earliestYear!) return true;
    if (_year == _earliestYear! && _month > (_earliestMonth ?? 1)) return true;
    return false;
  }

  void _changeMonth(int delta) {
    if (delta < 0 && !_canGoBack) return;
    setState(() {
      _month += delta;
      if (_month > 12) {
        _month = 1;
        _year++;
      } else if (_month < 1) {
        _month = 12;
        _year--;
      }
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return ValueListenableBuilder<ServiceMode>(
      valueListenable: _modeService.modeNotifier,
      builder: (context, mode, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Collection Book'),
            actions: [
              // --- Mode toggle in AppBar ---
              _ModePill(mode: mode, onToggle: _modeService.toggle),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(PhosphorIcons.users(PhosphorIconsStyle.bold)),
                tooltip: 'All Subscribers',
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/subscribers',
                ).then((_) => _loadData()),
              ),
              IconButton(
                icon: Icon(PhosphorIcons.gear(PhosphorIconsStyle.bold)),
                tooltip: 'Settings',
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/settings',
                ).then((_) => _loadData()),
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 80),
                    children: [
                      _buildMonthSelector(),
                      _buildSummaryCards(currencyFormat),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Text(
                          'Area-wise Collection',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      ..._areaSummary.map(
                        (a) => _buildAreaCard(a, currencyFormat),
                      ),
                      if (_areaSummary.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'No ${mode.label} subscribers yet.\nAdd subscribers and assign them to areas.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.pushNamed(
              context,
              '/record-payment',
              arguments: {'month': _month, 'year': _year},
            ).then((_) => _loadData()),
            icon: Icon(PhosphorIcons.currencyInr(PhosphorIconsStyle.bold)),
            label: const Text('Record Payment'),
          ),
        );
      },
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      color: Theme.of(context).appBarTheme.backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(
              PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
              color: _canGoBack ? Colors.white : Colors.white38,
            ),
            onPressed: _canGoBack ? () => _changeMonth(-1) : null,
          ),
          GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              setState(() {
                _year = now.year;
                _month = now.month;
              });
              _loadData();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_months[_month - 1]} $_year',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
              color: Colors.white,
            ),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(NumberFormat fmt) {
    final totalExpected = (_summary['total_expected'] as num?)?.toDouble() ?? 0;
    final totalCollected =
        (_summary['total_collected'] as num?)?.toDouble() ?? 0;
    final subscriberCount =
        (_summary['subscriber_count'] as num?)?.toInt() ?? 0;
    final paidCount = (_summary['paid_count'] as num?)?.toInt() ?? 0;
    final unpaidCount = (_summary['unpaid_count'] as num?)?.toInt() ?? 0;
    final rate = (_summary['collection_rate'] as num?)?.toDouble() ?? 0;
    final totalDues = (_summary['total_dues'] as num?)?.toDouble() ?? 0;
    final pendingThisMonth = (totalExpected - totalCollected).clamp(
      0,
      double.infinity,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _duesHeroCard(fmt, totalDues, subscriberCount),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _collectionCard(
                    fmt,
                    totalCollected,
                    totalExpected,
                    rate,
                    paidCount,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _compactStatCard(
                    label: 'Pending',
                    value: fmt.format(pendingThisMonth),
                    subtitle: '$unpaidCount unpaid',
                    subtitleIcon: PhosphorIcons.user(PhosphorIconsStyle.bold),
                    color: unpaidCount > 0 ? AppTheme.pending : AppTheme.paid,
                    icon: PhosphorIcons.clock(PhosphorIconsStyle.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Full-width hero card showing cumulative outstanding dues.
  Widget _duesHeroCard(
    NumberFormat fmt,
    double totalDues,
    int subscriberCount,
  ) {
    final hasDues = totalDues > 0;
    final color = hasDues ? AppTheme.pending : AppTheme.paid;
    final bgColor = hasDues ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9);
    final borderColor = hasDues
        ? const Color(0xFFFFE0B2)
        : const Color(0xFFC8E6C9);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIcons.receipt(PhosphorIconsStyle.bold),
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                'Outstanding Dues',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                '$subscriberCount subscribers',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              fmt.format(hasDues ? totalDues : 0),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasDues ? 'total balance to collect' : 'All dues cleared!',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  /// Collection card with inline progress bar.
  Widget _collectionCard(
    NumberFormat fmt,
    double collected,
    double expected,
    double rate,
    int paidCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(
                PhosphorIcons.wallet(PhosphorIconsStyle.bold),
                size: 18,
                color: AppTheme.paid,
              ),
              const SizedBox(width: 6),
              Text(
                'Collected',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              fmt.format(collected),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.paid,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (rate / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              color: AppTheme.paid,
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${rate.toStringAsFixed(0)}% · $paidCount paid',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  /// Compact stat card used for the Pending KPI.
  Widget _compactStatCard({
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    IconData? subtitleIcon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (subtitleIcon != null) ...[
                Icon(subtitleIcon, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 3),
              ],
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAreaCard(Map<String, dynamic> area, NumberFormat fmt) {
    final areaName = area['area_name'] as String? ?? 'Unknown';
    final subCount = (area['subscriber_count'] as num?)?.toInt() ?? 0;
    final totalRent = (area['total_rent'] as num?)?.toDouble() ?? 0;
    final collected = (area['total_collected'] as num?)?.toDouble() ?? 0;
    final paidCount = (area['paid_count'] as num?)?.toInt() ?? 0;

    return Card(
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/subscribers',
          arguments: {'areaId': area['area_id']},
        ).then((_) => _loadData()),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    areaName.isNotEmpty ? areaName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
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
                      areaName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$subCount subscribers  ·  $paidCount paid',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmt.format(collected),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.paid,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'of ${fmt.format(totalRent)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact pill button in the AppBar to toggle between TV and Fiber mode.
class _ModePill extends StatelessWidget {
  final ServiceMode mode;
  final Future<void> Function() onToggle;

  const _ModePill({required this.mode, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: GestureDetector(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(30),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(60), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(mode.icon, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                mode.shortLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
