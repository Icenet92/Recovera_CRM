class CrmActivityModel {
  final String id;
  final String activityType;
  final String subject;
  final String? description;
  final String? outcome;
  final String? contactId;
  final String? leadId;
  final String? organizationId;
  final String? loggedByEmployeeId;
  final DateTime activityDate;
  final DateTime syncCreatedAt;
  final DateTime syncUpdatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  // Optional denormalized display fields (joined from query, not stored)
  final String? contactName;
  final String? loggedByName;

  const CrmActivityModel({
    required this.id,
    required this.activityType,
    required this.subject,
    this.description,
    this.outcome,
    this.contactId,
    this.leadId,
    this.organizationId,
    this.loggedByEmployeeId,
    required this.activityDate,
    required this.syncCreatedAt,
    required this.syncUpdatedAt,
    required this.isDeleted,
    this.deletedAt,
    this.contactName,
    this.loggedByName,
  });

  static const List<String> validTypes = [
    'Call',
    'Meeting',
    'Note',
    'Email',
    'Decision',
    'FollowUp',
  ];

  static String iconForType(String type) {
    switch (type) {
      case 'Call':
        return '📞';
      case 'Meeting':
        return '🤝';
      case 'Note':
        return '📝';
      case 'Email':
        return '✉️';
      case 'Decision':
        return '✅';
      case 'FollowUp':
        return '🔔';
      default:
        return '📋';
    }
  }

  factory CrmActivityModel.fromMap(Map<String, dynamic> map) {
    return CrmActivityModel(
      id: map['id'] as String,
      activityType: map['activity_type'] as String,
      subject: map['subject'] as String,
      description: map['description'] as String?,
      outcome: map['outcome'] as String?,
      contactId: map['contact_id'] as String?,
      leadId: map['lead_id'] as String?,
      organizationId: map['organization_id'] as String?,
      loggedByEmployeeId: map['logged_by_employee_id'] as String?,
      activityDate: DateTime.parse(map['activity_date'] as String),
      syncCreatedAt: DateTime.parse(map['SyncCreatedAt'] as String),
      syncUpdatedAt: DateTime.parse(map['SyncUpdatedAt'] as String),
      isDeleted: (map['IsDeleted'] as int? ?? 0) == 1,
      deletedAt: map['DeletedAt'] != null
          ? DateTime.tryParse(map['DeletedAt'] as String)
          : null,
      contactName: map['contact_name'] as String?,
      loggedByName: map['logged_by_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activity_type': activityType,
      'subject': subject,
      'description': description,
      'outcome': outcome,
      'contact_id': contactId,
      'lead_id': leadId,
      'organization_id': organizationId,
      'logged_by_employee_id': loggedByEmployeeId,
      'activity_date': activityDate.toIso8601String(),
      'SyncCreatedAt': syncCreatedAt.toIso8601String(),
      'SyncUpdatedAt': syncUpdatedAt.toIso8601String(),
      'IsDeleted': isDeleted ? 1 : 0,
      'DeletedAt': deletedAt?.toIso8601String(),
    };
  }
}
