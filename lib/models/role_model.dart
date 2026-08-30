class RoleModel {
  final String id;
  final String name;
  final String? description;
  final List<String> permissionCodes;
  final DateTime syncCreatedAt;
  final DateTime syncUpdatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  const RoleModel({
    required this.id,
    required this.name,
    this.description,
    this.permissionCodes = const [],
    required this.syncCreatedAt,
    required this.syncUpdatedAt,
    required this.isDeleted,
    this.deletedAt,
  });

  factory RoleModel.fromMap(Map<String, dynamic> map) {
    return RoleModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      permissionCodes: const [], // loaded separately
      syncCreatedAt: DateTime.parse(map['SyncCreatedAt'] as String),
      syncUpdatedAt: DateTime.parse(map['SyncUpdatedAt'] as String),
      isDeleted: (map['IsDeleted'] as int) == 1,
      deletedAt: map['DeletedAt'] != null ? DateTime.parse(map['DeletedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'SyncCreatedAt': syncCreatedAt.toIso8601String(),
      'SyncUpdatedAt': syncUpdatedAt.toIso8601String(),
      'IsDeleted': isDeleted ? 1 : 0,
      'DeletedAt': deletedAt?.toIso8601String(),
    };
  }

  RoleModel copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? permissionCodes,
    DateTime? syncCreatedAt,
    DateTime? syncUpdatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return RoleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      permissionCodes: permissionCodes ?? this.permissionCodes,
      syncCreatedAt: syncCreatedAt ?? this.syncCreatedAt,
      syncUpdatedAt: syncUpdatedAt ?? this.syncUpdatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
