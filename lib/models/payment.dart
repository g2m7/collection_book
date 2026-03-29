class Payment {
  final int? id;
  final int subscriberId;
  final int year;
  final int month;
  final double amountPaid;
  final double adjustment;
  final String? adjustmentNote;
  final String? recordedAt;

  const Payment({
    this.id,
    required this.subscriberId,
    required this.year,
    required this.month,
    required this.amountPaid,
    this.adjustment = 0,
    this.adjustmentNote,
    this.recordedAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'subscriber_id': subscriberId,
    'year': year,
    'month': month,
    'amount_paid': amountPaid,
    'adjustment': adjustment,
    'adjustment_note': adjustmentNote,
    'recorded_at': recordedAt ?? DateTime.now().toIso8601String(),
  };

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
    id: map['id'] as int?,
    subscriberId: map['subscriber_id'] as int,
    year: map['year'] as int,
    month: map['month'] as int,
    amountPaid: (map['amount_paid'] as num).toDouble(),
    adjustment: (map['adjustment'] as num?)?.toDouble() ?? 0,
    adjustmentNote: map['adjustment_note'] as String?,
    recordedAt: map['recorded_at'] as String?,
  );

  Payment copyWith({
    int? id,
    int? subscriberId,
    int? year,
    int? month,
    double? amountPaid,
    double? adjustment,
    String? adjustmentNote,
    String? recordedAt,
  }) => Payment(
    id: id ?? this.id,
    subscriberId: subscriberId ?? this.subscriberId,
    year: year ?? this.year,
    month: month ?? this.month,
    amountPaid: amountPaid ?? this.amountPaid,
    adjustment: adjustment ?? this.adjustment,
    adjustmentNote: adjustmentNote ?? this.adjustmentNote,
    recordedAt: recordedAt ?? this.recordedAt,
  );

  @override
  String toString() =>
      'Payment(id: $id, subscriber: $subscriberId, $month/$year, paid: $amountPaid)';
}
