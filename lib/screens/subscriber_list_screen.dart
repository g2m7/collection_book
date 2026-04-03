import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/subscriber.dart';
import '../models/area.dart';
import '../services/database_service.dart';
import '../services/app_mode_service.dart';
import '../theme/app_theme.dart';

enum SortOption { nameAsc, nameDsc, dueHigh, dueLow, rentHigh, rentLow }

class SubscriberListScreen extends StatefulWidget {
  const SubscriberListScreen({super.key});

  @override
  State<SubscriberListScreen> createState() => _SubscriberListScreenState();
}

class _SubscriberListScreenState extends State<SubscriberListScreen> {
  final _db = DatabaseService();
  final _modeService = AppModeService();
  final _searchController = TextEditingController();
  List<Subscriber> _allSubscribers = []; // unfiltered (only service + search)
  List<Subscriber> _subscribers = []; // after client-side filters
  List<Area> _areas = [];
  bool _loading = true;

  // Filters
  String _paymentFilter = 'all'; // all | unpaid | paid | overpaid
  String _statusFilter = 'all'; // all | active | inactive
  int? _selectedAreaId;
  SortOption _sortOption = SortOption.nameAsc;
  bool _showFilters = false;

  final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _modeService.modeNotifier.addListener(_loadData);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('areaId') && _loading) {
      _selectedAreaId = args['areaId'] as int?;
    }
    if (_loading) _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _modeService.modeNotifier.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final areas = await _db.getAreas();
    // Fetch all subscribers for this service (no payment/status filter at DB
    // level so we can compute stats from the full set).
    final subscribers = await _db.getSubscribers(
      search: _searchController.text,
      areaId: _selectedAreaId,
      serviceType: _modeService.mode.key,
    );
    if (!mounted) return;
    setState(() {
      _areas = areas;
      _allSubscribers = subscribers;
      _applyClientFilters();
      _loading = false;
    });
  }

  void _applyClientFilters() {
    var list = List<Subscriber>.from(_allSubscribers);

    // Status filter
    if (_statusFilter == 'active') {
      list = list.where((s) => s.isActive).toList();
    } else if (_statusFilter == 'inactive') {
      list = list.where((s) => !s.isActive).toList();
    }

    // Payment filter
    if (_paymentFilter == 'paid') {
      list = list.where((s) => (s.currentDue ?? 0) <= 0).toList();
    } else if (_paymentFilter == 'unpaid') {
      list = list.where((s) => (s.currentDue ?? 0) > 0).toList();
    } else if (_paymentFilter == 'overpaid') {
      list = list.where((s) => (s.currentDue ?? 0) < 0).toList();
    }

    // Sort
    switch (_sortOption) {
      case SortOption.nameAsc:
        list.sort((a, b) => a.name.compareTo(b.name));
      case SortOption.nameDsc:
        list.sort((a, b) => b.name.compareTo(a.name));
      case SortOption.dueHigh:
        list.sort((a, b) => (b.currentDue ?? 0).compareTo(a.currentDue ?? 0));
      case SortOption.dueLow:
        list.sort((a, b) => (a.currentDue ?? 0).compareTo(b.currentDue ?? 0));
      case SortOption.rentHigh:
        list.sort((a, b) => b.monthlyRent.compareTo(a.monthlyRent));
      case SortOption.rentLow:
        list.sort((a, b) => a.monthlyRent.compareTo(b.monthlyRent));
    }

    _subscribers = list;
  }

  int get _activeFilterCount {
    int count = 0;
    if (_paymentFilter != 'all') count++;
    if (_statusFilter != 'all') count++;
    if (_selectedAreaId != null) count++;
    if (_sortOption != SortOption.nameAsc) count++;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _paymentFilter = 'all';
      _statusFilter = 'all';
      _selectedAreaId = null;
      _sortOption = SortOption.nameAsc;
      _applyClientFilters();
    });
  }

  // Stats computed from _allSubscribers (before client-side filters)
  int get _totalCount => _allSubscribers.length;

  double get _totalDue => _allSubscribers.fold(0.0, (sum, s) {
    final due = s.currentDue ?? 0;
    return due > 0 ? sum + due : sum;
  });

  @override
  Widget build(BuildContext context) {
    final mode = _modeService.mode;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final grouped = <String, List<Subscriber>>{};
    // When sorting by name, group by area; otherwise flat list
    final useGroups =
        _sortOption == SortOption.nameAsc || _sortOption == SortOption.nameDsc;
    if (useGroups) {
      for (final s in _subscribers) {
        final area = s.areaName ?? 'No Area';
        grouped.putIfAbsent(area, () => []).add(s);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Subscribers'),
            Text(
              '${mode.label} · $_totalCount total',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.userPlus(PhosphorIconsStyle.bold)),
            tooltip: 'Add Subscriber',
            onPressed: () => Navigator.pushNamed(
              context,
              '/add-subscriber',
            ).then((_) => _loadData()),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, alias, or VC number…',
                prefixIcon: Icon(
                  PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold)),
                        tooltip: 'Clear Search',
                        onPressed: () {
                          _searchController.clear();
                          _loadData();
                        },
                      )
                    : null,
              ),
              onChanged: (_) => _loadData(),
            ),
          ),

          // ── Quick Filter Chips + Filter Toggle ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _paymentChip('All', 'all'),
                        _paymentChip('Unpaid', 'unpaid'),
                        _paymentChip('Paid', 'paid'),
                        _paymentChip('Overpaid', 'overpaid'),
                        const SizedBox(width: 6),
                        Container(
                          width: 1,
                          height: 24,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(width: 6),
                        _statusChip('Active', 'active'),
                        _statusChip('Inactive', 'inactive'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Filter panel toggle
                Material(
                  color: _showFilters
                      ? primary.withAlpha(25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _showFilters = !_showFilters),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Badge(
                        isLabelVisible: _activeFilterCount > 0,
                        label: Text('$_activeFilterCount'),
                        child: Icon(
                          PhosphorIcons.funnelSimple(PhosphorIconsStyle.bold),
                          size: 20,
                          color: _showFilters ? primary : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Expandable Filter Panel ──
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _showFilters
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: _buildFilterPanel(primary),
            secondChild: const SizedBox(width: double.infinity),
          ),

          // ── Stats Summary Bar ──
          if (!_loading)
            Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.listChecks(PhosphorIconsStyle.bold),
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_subscribers.length} shown',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (_totalDue > 0) ...[
                    const Spacer(),
                    Icon(
                      PhosphorIcons.warning(PhosphorIconsStyle.bold),
                      size: 13,
                      color: AppTheme.unpaid.withAlpha(180),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Total Due: ${_currencyFormat.format(_totalDue)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.unpaid,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // ── List ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _subscribers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIcons.usersThree(PhosphorIconsStyle.bold),
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No subscribers match filters',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        if (_activeFilterCount > 0) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              _clearFilters();
                              _loadData();
                            },
                            icon: Icon(
                              PhosphorIcons.arrowCounterClockwise(
                                PhosphorIconsStyle.bold,
                              ),
                              size: 16,
                            ),
                            label: const Text('Clear Filters'),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: useGroups
                        ? ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: _buildGroupedItems(grouped).length,
                            itemBuilder: (context, index) =>
                                _buildGroupedItems(grouped)[index],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80, top: 4),
                            itemCount: _subscribers.length,
                            itemBuilder: (context, index) =>
                                _subscriberTile(_subscribers[index]),
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(
          context,
          '/add-subscriber',
        ).then((_) => _loadData()),
        child: Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold)),
      ),
    );
  }

  // ── Filter Panel (areas + sort) ──
  Widget _buildFilterPanel(Color primary) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Area filter
          if (_areas.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  PhosphorIcons.mapPin(PhosphorIconsStyle.bold),
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  'Area',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _areaChip('All Areas', null),
                ..._areas.map((a) => _areaChip(a.name, a.id)),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Sort
          Row(
            children: [
              Icon(
                PhosphorIcons.sortAscending(PhosphorIconsStyle.bold),
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                'Sort By',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _sortChip('Name ↑', SortOption.nameAsc),
              _sortChip('Name ↓', SortOption.nameDsc),
              _sortChip('Due ↑', SortOption.dueHigh),
              _sortChip('Due ↓', SortOption.dueLow),
              _sortChip('Rent ↑', SortOption.rentHigh),
              _sortChip('Rent ↓', SortOption.rentLow),
            ],
          ),

          if (_activeFilterCount > 0) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  _clearFilters();
                  _loadData();
                },
                icon: Icon(
                  PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.bold),
                  size: 14,
                ),
                label: const Text('Reset All', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Chip Builders ──

  Widget _paymentChip(String label, String value) {
    final selected = _paymentFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _paymentFilter = value;
            _applyClientFilters();
          });
        },
      ),
    );
  }

  Widget _statusChip(String label, String value) {
    final selected = _statusFilter == value;
    final isInactive = value == 'inactive';
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isInactive
                  ? PhosphorIcons.prohibit(PhosphorIconsStyle.bold)
                  : PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
              size: 14,
              color: selected
                  ? Colors.white
                  : isInactive
                  ? Colors.grey.shade500
                  : AppTheme.paid,
            ),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _statusFilter = selected ? 'all' : value;
            _applyClientFilters();
          });
        },
      ),
    );
  }

  Widget _areaChip(String label, int? areaId) {
    final selected = _selectedAreaId == areaId;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) {
        setState(() => _selectedAreaId = selected ? null : areaId);
        _loadData();
      },
    );
  }

  Widget _sortChip(String label, SortOption option) {
    final selected = _sortOption == option;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) {
        setState(() {
          _sortOption = option;
          _applyClientFilters();
        });
      },
    );
  }

  // ── List Builders ──

  List<Widget> _buildGroupedItems(Map<String, List<Subscriber>> grouped) {
    final items = <Widget>[];
    for (final entry in grouped.entries) {
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Text(
                entry.key,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${entry.value.length})',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
              const Expanded(child: Divider(indent: 12)),
            ],
          ),
        ),
      );
      for (final sub in entry.value) {
        items.add(_subscriberTile(sub));
      }
    }
    return items;
  }

  Widget _subscriberTile(Subscriber sub) {
    final due = sub.currentDue ?? 0;
    final prevDue = sub.previousDue;
    final color = AppTheme.dueColor(due);

    return Card(
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/subscriber-detail',
          arguments: sub.id,
        ).then((_) => _loadData()),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: sub.isActive
                      ? color.withAlpha(25)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: sub.isActive
                      ? Text(
                          sub.name.isNotEmpty ? sub.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        )
                      : Icon(
                          PhosphorIcons.prohibit(PhosphorIconsStyle.bold),
                          size: 18,
                          color: Colors.grey.shade400,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            sub.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: sub.isActive ? null : Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!sub.isActive)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Inactive',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (sub.serviceType == 'both')
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Both',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.purple,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (sub.aliasName != null && sub.aliasName!.isNotEmpty)
                      Text(
                        sub.aliasName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Rent: ${_currencyFormat.format(sub.monthlyRent)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (prevDue != 0) ...[
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            'Prev: ${_currencyFormat.format(prevDue)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: prevDue > 0
                                  ? AppTheme.unpaid.withAlpha(180)
                                  : AppTheme.overpaid.withAlpha(180),
                              fontWeight: FontWeight.w500,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Due amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    due == 0
                        ? 'Clear'
                        : due > 0
                        ? _currencyFormat.format(due)
                        : '+${_currencyFormat.format(-due)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    due > 0
                        ? 'due'
                        : due < 0
                        ? 'advance'
                        : '',
                    style: TextStyle(fontSize: 11, color: color.withAlpha(180)),
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
