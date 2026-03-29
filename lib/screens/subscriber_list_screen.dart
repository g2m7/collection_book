import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/subscriber.dart';
import '../models/area.dart';
import '../services/database_service.dart';
import '../services/app_mode_service.dart';
import '../theme/app_theme.dart';

class SubscriberListScreen extends StatefulWidget {
  const SubscriberListScreen({super.key});

  @override
  State<SubscriberListScreen> createState() => _SubscriberListScreenState();
}

class _SubscriberListScreenState extends State<SubscriberListScreen> {
  final _db = DatabaseService();
  final _modeService = AppModeService();
  final _searchController = TextEditingController();
  List<Subscriber> _subscribers = [];
  List<Area> _areas = [];
  bool _loading = true;
  String _filter = 'all';
  int? _selectedAreaId;

  final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _modeService.modeNotifier.addListener(_loadData);
    _loadData();
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
    final subscribers = await _db.getSubscribers(
      search: _searchController.text,
      filter: _filter == 'all' ? null : _filter,
      areaId: _selectedAreaId,
      serviceType: _modeService.mode.key,
    );
    if (!mounted) return;
    setState(() {
      _areas = areas;
      _subscribers = subscribers;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = _modeService.mode;
    final grouped = <String, List<Subscriber>>{};
    for (final s in _subscribers) {
      final area = s.areaName ?? 'No Area';
      grouped.putIfAbsent(area, () => []).add(s);
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Subscribers'),
            // Subtle mode indicator under the title
            Text(
              '${mode.label} mode',
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
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, alias, or VC number…',
                prefixIcon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold)),
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
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All', 'all'),
                  _filterChip('Unpaid', 'unpaid'),
                  _filterChip('Paid', 'paid'),
                  _filterChip('Overpaid', 'overpaid'),
                  const SizedBox(width: 8),
                  const VerticalDivider(width: 1),
                  const SizedBox(width: 8),
                  ..._areas.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(a.name),
                        selected: _selectedAreaId == a.id,
                        onSelected: (sel) {
                          setState(() => _selectedAreaId = sel ? a.id : null);
                          _loadData();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                          'No ${mode.label} subscribers found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _buildListItems(grouped).length,
                      itemBuilder: (context, index) =>
                          _buildListItems(grouped)[index],
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

  Widget _filterChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) {
          setState(() => _filter = value);
          _loadData();
        },
      ),
    );
  }

  List<Widget> _buildListItems(Map<String, List<Subscriber>> grouped) {
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    sub.name.isNotEmpty ? sub.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sub.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Show 'both' badge for subscribers in both services
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
                      ),
                    Text(
                      'Rent: ${_currencyFormat.format(sub.monthlyRent)}',
                      style: TextStyle(
                        fontSize: 12,
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
