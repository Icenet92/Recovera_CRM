class LeadModel {
  final String id;
  final String? organizationId;
  final String title;
  final String? ownerEmployeeId;
  final String? source;
  final double? expectedValue;
  final String currency;
  final String status;
  final String? nextAction;
  final DateTime? followupDate;
  final String? notes;
  final DateTime syncCreatedAt;
  final DateTime syncUpdatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  const LeadModel({
    required this.id,
    this.organizationId,
    required this.title,
    this.ownerEmployeeId,
    this.source,
    this.expectedValue,
    required this.currency,
    required this.status,
    this.nextAction,
    this.followupDate,
    this.notes,
    required this.syncCreatedAt,
    required this.syncUpdatedAt,
    required this.isDeleted,
    this.deletedAt,
  });

  /// Ordered pipeline stages used for the Kanban board.
  static const List<String> pipelineStages = [
    'New',
    'Qualified',
    'Contacted',
    'Meeting',
    'Proposal',
    'Negotiation',
    'Contract',
    'Onboarding',
    'Client',
  ];

  static const List<String> validSources = [
    'Referral',
    'Cold Outreach',
    'Website',
    'Event',
    'Partnership',
    'Other',
  ];

  bool get isFollowupOverdue {
    if (followupDate == null) return false;
    return followupDate!.isBefore(DateTime.now());
  }

  factory LeadModel.fromMap(Map<String, dynamic> map) {
    return LeadModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String?,
      title: map['title'] as String,
      ownerEmployeeId: map['owner_employee_id'] as String?,
      source: map['source'] as String?,
      expectedValue: (map['expected_value'] as num?)?.toDouble(),
      currency: map['currency'] as String? ?? 'RWF',
      status: map['status'] as String? ?? 'New',
      nextAction: map['next_action'] as String?,
      followupDate: map['followup_date'] != null
          ? DateTime.tryParse(map['followup_date'] as String)
          : null,
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
      'organization_id': organizationId,
      'title': title,
      'owner_employee_id': ownerEmployeeId,
      'source': source,
      'expected_value': expectedValue,
      'currency': currency,
      'status': status,
      'next_action': nextAction,
      'followup_date': followupDate?.toIso8601String(),
      'notes': notes,
      'SyncCreatedAt': syncCreatedAt.toIso8601String(),
      'SyncUpdatedAt': syncUpdatedAt.toIso8601String(),
      'IsDeleted': isDeleted ? 1 : 0,
      'DeletedAt': deletedAt?.toIso8601String(),
    };
  }

  LeadModel copyWith({
    String? organizationId,
    String? title,
    String? ownerEmployeeId,
    String? source,
    double? expectedValue,
    String? currency,
    String? status,
    String? nextAction,
    DateTime? followupDate,
    String? notes,
    DateTime? syncUpdatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return LeadModel(
      id: id,
      organizationId: organizationId ?? this.organizationId,
      title: title ?? this.title,
      ownerEmployeeId: ownerEmployeeId ?? this.ownerEmployeeId,
      source: source ?? this.source,
      expectedValue: expectedValue ?? this.expectedValue,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      nextAction: nextAction ?? this.nextAction,
      followupDate: followupDate ?? this.followupDate,
      notes: notes ?? this.notes,
      syncCreatedAt: syncCreatedAt,
      syncUpdatedAt: syncUpdatedAt ?? this.syncUpdatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
