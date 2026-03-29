class Subscriber {
  final int? id;
  final int? areaId;
  final String name;
  final String? aliasName;
  final String? vcNumber;
  final double monthlyRent;
  final double previousDue;
  final bool isActive;
  final String? createdAt;

  /// 'tv' | 'fiber' | 'both'
  final String serviceType;

  // Transient fields (not stored, computed in queries)
  final String? areaName;
  final double? currentDue;

  const Subscriber({
    this.id,
    this.areaId,
    required this.name,
    this.aliasName,
    this.vcNumber,
    required this.monthlyRent,
    this.previousDue = 0,
    this.isActive = true,
    this.createdAt,
    this.serviceType = 'tv',
    this.areaName,
    this.currentDue,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'area_id': areaId,
    'name': name,
    'alias_name': aliasName,
    'vc_number': vcNumber,
    'monthly_rent': monthlyRent,
    'previous_due': previousDue,
    'is_active': isActive ? 1 : 0,
    'service_type': serviceType,
    if (createdAt != null) 'created_at': createdAt,
  };

  factory Subscriber.fromMap(Map<String, dynamic> map) => Subscriber(
    id: map['id'] as int?,
    areaId: map['area_id'] as int?,
    name: map['name'] as String,
    aliasName: map['alias_name'] as String?,
    vcNumber: map['vc_number'] as String?,
    monthlyRent: (map['monthly_rent'] as num).toDouble(),
    previousDue: (map['previous_due'] as num?)?.toDouble() ?? 0,
    isActive: (map['is_active'] as int?) == 1,
    createdAt: map['created_at'] as String?,
    serviceType: (map['service_type'] as String?) ?? 'tv',
    areaName: map['area_name'] as String?,
    currentDue: (map['current_due'] as num?)?.toDouble(),
  );

  Subscriber copyWith({
    int? id,
    int? areaId,
    String? name,
    String? aliasName,
    String? vcNumber,
    double? monthlyRent,
    double? previousDue,
    bool? isActive,
    String? createdAt,
    String? serviceType,
    String? areaName,
    double? currentDue,
  }) => Subscriber(
    id: id ?? this.id,
    areaId: areaId ?? this.areaId,
    name: name ?? this.name,
    aliasName: aliasName ?? this.aliasName,
    vcNumber: vcNumber ?? this.vcNumber,
    monthlyRent: monthlyRent ?? this.monthlyRent,
    previousDue: previousDue ?? this.previousDue,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    serviceType: serviceType ?? this.serviceType,
    areaName: areaName ?? this.areaName,
    currentDue: currentDue ?? this.currentDue,
  );

  @override
  String toString() => 'Subscriber(id: $id, name: $name, rent: $monthlyRent, service: $serviceType)';
}
