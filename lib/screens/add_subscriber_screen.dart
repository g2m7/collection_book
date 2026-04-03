import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/area.dart';
import '../models/subscriber.dart';
import '../services/database_service.dart';
import '../services/app_mode_service.dart';

class AddSubscriberScreen extends StatefulWidget {
  final int? subscriberId;
  const AddSubscriberScreen({super.key, this.subscriberId});

  @override
  State<AddSubscriberScreen> createState() => _AddSubscriberScreenState();
}

class _AddSubscriberScreenState extends State<AddSubscriberScreen> {
  final _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _aliasController = TextEditingController();
  final _vcController = TextEditingController();
  final _rentController = TextEditingController();
  final _prevDueController = TextEditingController(text: '0');
  final _accountIdController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  List<Area> _areas = [];
  int? _selectedAreaId;
  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;
  Subscriber? _existing;

  int? _startMonth;
  int? _startYear;

  /// 'tv' | 'fiber'
  late String _serviceType;

  bool get _isEditing => widget.subscriberId != null;
  bool get _isFiber => _serviceType == 'fiber';

  @override
  void initState() {
    super.initState();
    _serviceType = AppModeService().mode.key;
    final now = DateTime.now();
    _startMonth = now.month;
    _startYear = now.year;
    _loadData();
  }

  Future<void> _loadData() async {
    final areas = await _db.getAreas();
    Subscriber? existing;
    if (_isEditing) {
      existing = await _db.getSubscriber(widget.subscriberId!);
      if (existing != null) {
        _nameController.text = existing.name;
        _aliasController.text = existing.aliasName ?? '';
        _vcController.text = existing.vcNumber ?? '';
        _rentController.text = existing.monthlyRent.toStringAsFixed(0);
        _prevDueController.text = existing.previousDue.toStringAsFixed(0);
        _accountIdController.text = existing.accountId ?? '';
        _usernameController.text = existing.username ?? '';
        _phoneController.text = existing.phone ?? '';
        _selectedAreaId = existing.areaId;
        _isActive = existing.isActive;
        _serviceType = existing.serviceType;
        _startYear = existing.startYear;
        _startMonth = existing.startMonth;
      }
    }
    setState(() {
      _areas = areas;
      _existing = existing;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final subscriber = Subscriber(
      id: _existing?.id,
      areaId: _selectedAreaId,
      name: _nameController.text.trim(),
      aliasName: _aliasController.text.trim().isNotEmpty
          ? _aliasController.text.trim()
          : null,
      vcNumber: _vcController.text.trim().isNotEmpty
          ? _vcController.text.trim()
          : null,
      monthlyRent: double.tryParse(_rentController.text) ?? 0,
      previousDue: double.tryParse(_prevDueController.text) ?? 0,
      isActive: _isActive,
      serviceType: _serviceType,
      startYear: _startYear,
      startMonth: _startMonth,
      accountId: _accountIdController.text.trim().isNotEmpty
          ? _accountIdController.text.trim()
          : null,
      username: _usernameController.text.trim().isNotEmpty
          ? _usernameController.text.trim()
          : null,
      phone: _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null,
    );

    if (_isEditing) {
      await _db.updateSubscriber(subscriber);
    } else {
      await _db.insertSubscriber(subscriber);
    }

    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Subscriber updated' : 'Subscriber added'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasController.dispose();
    _vcController.dispose();
    _rentController.dispose();
    _prevDueController.dispose();
    _accountIdController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Subscriber' : 'Add Subscriber'),
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator(radius: 14))
          : Form(
              key: _formKey,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  _label('Name *'),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(hintText: 'Full name…'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Name is required'
                        : null,
                    autofocus: !_isEditing,
                  ),

                  const SizedBox(height: 16),
                  _label('Alias Name'),
                  TextFormField(
                    controller: _aliasController,
                    decoration: const InputDecoration(
                      hintText: 'Optional alias…',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),

                  const SizedBox(height: 16),
                  _label('Area'),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedAreaId,
                    decoration: const InputDecoration(hintText: 'Select area…'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ..._areas.map((a) {
                        return DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name),
                        );
                      }),
                    ],
                    onChanged: (v) => setState(() => _selectedAreaId = v),
                  ),

                  const SizedBox(height: 16),
                  _label(_isFiber ? 'Account ID' : 'VC Number'),
                  TextFormField(
                    controller: _vcController,
                    decoration: InputDecoration(
                      hintText: _isFiber
                          ? 'Account or card number…'
                          : 'VC / STB number…',
                    ),
                    keyboardType: TextInputType.text,
                    spellCheckConfiguration:
                        const SpellCheckConfiguration.disabled(),
                  ),

                  // Internet-specific identifier fields
                  if (_isFiber) ...[
                    const SizedBox(height: 16),
                    _label('Username'),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        hintText: 'Login username…',
                      ),
                      keyboardType: TextInputType.text,
                      autocorrect: false,
                      spellCheckConfiguration:
                          const SpellCheckConfiguration.disabled(),
                    ),
                    const SizedBox(height: 16),
                    _label('Phone'),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        hintText: 'Mobile number…',
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      spellCheckConfiguration:
                          const SpellCheckConfiguration.disabled(),
                    ),
                  ],

                  const SizedBox(height: 16),
                  _label('Monthly Rent *'),
                  TextFormField(
                    controller: _rentController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      prefixText: '₹ ',
                      hintText: '0',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter rent amount';
                      if (double.tryParse(v) == null) return 'Invalid amount';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),
                  _label('Subscription Start'),
                  Text(
                    'Dues are calculated from this month onward.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          initialValue: _startMonth,
                          decoration: const InputDecoration(hintText: 'Month…'),
                          items: List.generate(12, (i) {
                            const names = [
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
                            return DropdownMenuItem(
                              value: i + 1,
                              child: Text(names[i]),
                            );
                          }),
                          onChanged: (v) => setState(() => _startMonth = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _startYear,
                          decoration: const InputDecoration(hintText: 'Year…'),
                          items: () {
                            final now = DateTime.now().year;
                            return List.generate(5, (i) {
                              final y = now - 3 + i;
                              return DropdownMenuItem(
                                value: y,
                                child: Text('$y'),
                              );
                            });
                          }(),
                          onChanged: (v) => setState(() => _startYear = v),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  _label('Previous Due (carry forward)'),
                  TextFormField(
                    controller: _prevDueController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                    ],
                    decoration: const InputDecoration(
                      prefixText: '₹ ',
                      hintText: '0',
                    ),
                  ),

                  const SizedBox(height: 20),
                  _label('Service'),
                  _ServiceSelector(
                    value: _serviceType,
                    onChanged: (v) => setState(() => _serviceType = v),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active', style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(
                            'Inactive subscribers are hidden',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      CupertinoSwitch(
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        activeTrackColor: const Color(0xFF2E7D32),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const CupertinoActivityIndicator(
                              color: Colors.white,
                            )
                          : Text(_isEditing ? 'Update' : 'Add Subscriber'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}

/// Two-button segmented selector for TV / Fiber.
class _ServiceSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _ServiceSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        _btn(
          context,
          'tv',
          PhosphorIcons.televisionSimple(PhosphorIconsStyle.bold),
          'Cable TV',
          primary,
        ),
        const SizedBox(width: 8),
        _btn(
          context,
          'fiber',
          PhosphorIcons.globeHemisphereWest(PhosphorIconsStyle.bold),
          'Internet',
          primary,
        ),
      ],
    );
  }

  Widget _btn(
    BuildContext context,
    String key,
    IconData icon,
    String label,
    Color activeColor,
  ) {
    final selected = value == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? activeColor.withAlpha(25) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? activeColor : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? activeColor : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? activeColor : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
