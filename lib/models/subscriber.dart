/// Allowed service types for subscribers. 'both' is no longer valid.
const validServiceTypes = ['tv', 'fiber'];

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

  /// 'tv' | 'fiber' — must be one of [validServiceTypes].
  final String serviceType;

  /// The year/month when this subscription started (grid shows from here).
  final int? startYear;
  final int? startMonth;

  // Internet-specific identifiers
  final String? accountId;
  final String? username;
  final String? phone;

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
    this.startYear,
    this.startMonth,
    this.accountId,
    this.username,
    this.phone,
    this.areaName,
    this.currentDue,
  });

  /// Returns the best unique identifier for this subscriber's service type.
  String? get strongId {
    if (serviceType == 'tv') {
      return vcNumber;
    }
    return accountId ?? username ?? phone;
  }

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
    'start_year': startYear,
    'start_month': startMonth,
    'account_id': accountId,
    'username': username,
    'phone': phone,
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
    startYear: map['start_year'] as int?,
    startMonth: map['start_month'] as int?,
    accountId: map['account_id'] as String?,
    username: map['username'] as String?,
    phone: map['phone'] as String?,
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
    int? startYear,
    int? startMonth,
    String? accountId,
    String? username,
    String? phone,
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
    startYear: startYear ?? this.startYear,
    startMonth: startMonth ?? this.startMonth,
    accountId: accountId ?? this.accountId,
    username: username ?? this.username,
    phone: phone ?? this.phone,
    areaName: areaName ?? this.areaName,
    currentDue: currentDue ?? this.currentDue,
  );

  @override
  String toString() =>
      'Subscriber(id: $id, name: $name, rent: $monthlyRent, service: $serviceType)';
}
