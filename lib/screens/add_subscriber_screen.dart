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

  List<Area> _areas = [];
  int? _selectedAreaId;
  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;
  Subscriber? _existing;

  /// 'tv' | 'fiber' | 'both'
  late String _serviceType;

  bool get _isEditing => widget.subscriberId != null;

  @override
  void initState() {
    super.initState();
    _serviceType = AppModeService().mode.key;
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
        _selectedAreaId = existing.areaId;
        _isActive = existing.isActive;
        _serviceType = existing.serviceType;
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
                  _label('VC Number'),
                  TextFormField(
                    controller: _vcController,
                    decoration: const InputDecoration(
                      hintText: 'Account/card number…',
                    ),
                    keyboardType: TextInputType.text,
                    spellCheckConfiguration:
                        const SpellCheckConfiguration.disabled(),
                  ),

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

/// Three-button segmented selector for TV / Fiber / Both.
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
          'TV',
          primary,
        ),
        const SizedBox(width: 8),
        _btn(
          context,
          'fiber',
          PhosphorIcons.globeHemisphereWest(PhosphorIconsStyle.bold),
          'Fiber',
          primary,
        ),
        const SizedBox(width: 8),
        _btn(
          context,
          'both',
          PhosphorIcons.infinity(PhosphorIconsStyle.bold),
          'Both',
          Colors.purple,
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
