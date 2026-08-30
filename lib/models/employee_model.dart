class EmployeeModel {
  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? departmentId;
  final String? teamId;
  final String? jobTitle;
  final DateTime syncCreatedAt;
  final DateTime syncUpdatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  String get fullName => '$firstName $lastName';

  const EmployeeModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.departmentId,
    this.teamId,
    this.jobTitle,
    required this.syncCreatedAt,
    required this.syncUpdatedAt,
    required this.isDeleted,
    this.deletedAt,
  });

  factory EmployeeModel.fromMap(Map<String, dynamic> map) {
    return EmployeeModel(
      id: map['id'] as String,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      departmentId: map['department_id'] as String?,
      teamId: map['team_id'] as String?,
      jobTitle: map['job_title'] as String?,
      syncCreatedAt: DateTime.parse(map['SyncCreatedAt'] as String),
      syncUpdatedAt: DateTime.parse(map['SyncUpdatedAt'] as String),
      isDeleted: (map['IsDeleted'] as int) == 1,
      deletedAt: map['DeletedAt'] != null ? DateTime.parse(map['DeletedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'department_id': departmentId,
      'team_id': teamId,
      'job_title': jobTitle,
      'SyncCreatedAt': syncCreatedAt.toIso8601String(),
      'SyncUpdatedAt': syncUpdatedAt.toIso8601String(),
      'IsDeleted': isDeleted ? 1 : 0,
      'DeletedAt': deletedAt?.toIso8601String(),
    };
  }

  EmployeeModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? departmentId,
    String? teamId,
    String? jobTitle,
    DateTime? syncCreatedAt,
    DateTime? syncUpdatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      departmentId: departmentId ?? this.departmentId,
      teamId: teamId ?? this.teamId,
      jobTitle: jobTitle ?? this.jobTitle,
      syncCreatedAt: syncCreatedAt ?? this.syncCreatedAt,
      syncUpdatedAt: syncUpdatedAt ?? this.syncUpdatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
