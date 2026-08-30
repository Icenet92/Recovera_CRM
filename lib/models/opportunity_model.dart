class OpportunityModel {
  final String id;
  final String? leadId;
  final String? organizationId;
  final String title;
  final double? expectedValue;
  final int probabilityPct;
  final DateTime? closeDate;
  final String status;
  final String? notes;
  final DateTime syncCreatedAt;
  final DateTime syncUpdatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  const OpportunityModel({
    required this.id,
    this.leadId,
    this.organizationId,
    required this.title,
    this.expectedValue,
    required this.probabilityPct,
    this.closeDate,
    required this.status,
    this.notes,
    required this.syncCreatedAt,
    required this.syncUpdatedAt,
    required this.isDeleted,
    this.deletedAt,
  });

  static const List<String> validStatuses = [
    'Open',
    'Won',
    'Lost',
    'On Hold',
  ];

  factory OpportunityModel.fromMap(Map<String, dynamic> map) {
    return OpportunityModel(
      id: map['id'] as String,
      leadId: map['lead_id'] as String?,
      organizationId: map['organization_id'] as String?,
      title: map['title'] as String,
      expectedValue: (map['expected_value'] as num?)?.toDouble(),
      probabilityPct: map['probability_pct'] as int? ?? 0,
      closeDate: map['close_date'] != null
          ? DateTime.tryParse(map['close_date'] as String)
          : null,
      status: map['status'] as String? ?? 'Open',
      notes: map['notes'] as String?,
      syncCreatedAt: DateTime.parse(map['SyncCreatedAt'] as String),
      syncUpdatedAt: DateTime.parse(map['SyncUpdatedAt'] as String),
      isDeleted: (map['IsDeleted'] as int? ?? 0) == 1,
      deletedAt: map['DeletedAt'] != null
          ? DateTime.tryParse(map['DeletedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lead_id': leadId,
      'organization_id': organizationId,
      'title': title,
      'expected_value': expectedValue,
      'probability_pct': probabilityPct,
      'close_date': closeDate?.toIso8601String(),
      'status': status,
      'notes': notes,
      'SyncCreatedAt': syncCreatedAt.toIso8601String(),
      'SyncUpdatedAt': syncUpdatedAt.toIso8601String(),
      'IsDeleted': isDeleted ? 1 : 0,
      'DeletedAt': deletedAt?.toIso8601String(),
    };
  }
}
