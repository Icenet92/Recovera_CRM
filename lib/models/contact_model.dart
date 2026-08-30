class ContactModel {
  final String id;
  final String organizationId;
  final String firstName;
  final String lastName;
  final String? position;
  final String? phone;
  final String? email;
  final String? preferredChannel;
  final String roleType;
  final bool isDecisionMaker;
  final String? notes;
  final DateTime? lastInteractionDate;
  final DateTime? nextFollowupDate;
  final DateTime syncCreatedAt;
  final DateTime syncUpdatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  const ContactModel({
    required this.id,
    required this.organizationId,
    required this.firstName,
    required this.lastName,
    this.position,
    this.phone,
    this.email,
    this.preferredChannel,
    required this.roleType,
    required this.isDecisionMaker,
    this.notes,
    this.lastInteractionDate,
    this.nextFollowupDate,
    required this.syncCreatedAt,
    required this.syncUpdatedAt,
    required this.isDeleted,
    this.deletedAt,
  });

  String get fullName => '$firstName $lastName';

  static const List<String> validRoleTypes = [
    'Primary',
    'Finance',
    'Legal',
    'Operations',
    'Executive',
    'Other',
  ];

  static const List<String> validChannels = [
    'Email',
    'Phone',
    'WhatsApp',
    'In Person',
    'Other',
  ];

  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      position: map['position'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      preferredChannel: map['preferred_channel'] as String?,
      roleType: map['role_type'] as String? ?? 'Primary',
      isDecisionMaker: (map['is_decision_maker'] as int? ?? 0) == 1,
      notes: map['notes'] as String?,
      lastInteractionDate: map['last_interaction_date'] != null
          ? DateTime.tryParse(map['last_interaction_date'] as String)
          : null,
      nextFollowupDate: map['next_followup_date'] != null
          ? DateTime.tryParse(map['next_followup_date'] as String)
          : null,
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
      'first_name': firstName,
      'last_name': lastName,
      'position': position,
      'phone': phone,
      'email': email,
      'preferred_channel': preferredChannel,
      'role_type': roleType,
      'is_decision_maker': isDecisionMaker ? 1 : 0,
      'notes': notes,
      'last_interaction_date': lastInteractionDate?.toIso8601String(),
      'next_followup_date': nextFollowupDate?.toIso8601String(),
      'SyncCreatedAt': syncCreatedAt.toIso8601String(),
      'SyncUpdatedAt': syncUpdatedAt.toIso8601String(),
      'IsDeleted': isDeleted ? 1 : 0,
      'DeletedAt': deletedAt?.toIso8601String(),
    };
  }

  ContactModel copyWith({
    String? organizationId,
    String? firstName,
    String? lastName,
    String? position,
    String? phone,
    String? email,
    String? preferredChannel,
    String? roleType,
    bool? isDecisionMaker,
    String? notes,
    DateTime? lastInteractionDate,
    DateTime? nextFollowupDate,
    DateTime? syncUpdatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return ContactModel(
      id: id,
      organizationId: organizationId ?? this.organizationId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      position: position ?? this.position,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      preferredChannel: preferredChannel ?? this.preferredChannel,
      roleType: roleType ?? this.roleType,
      isDecisionMaker: isDecisionMaker ?? this.isDecisionMaker,
      notes: notes ?? this.notes,
      lastInteractionDate: lastInteractionDate ?? this.lastInteractionDate,
      nextFollowupDate: nextFollowupDate ?? this.nextFollowupDate,
      syncCreatedAt: syncCreatedAt,
      syncUpdatedAt: syncUpdatedAt ?? this.syncUpdatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
