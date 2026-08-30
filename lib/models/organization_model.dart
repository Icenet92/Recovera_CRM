class OrganizationModel {
  final String id;
  final String companyName;
  final String? registrationNumber;
  final String? industry;
  final String? address;
  final String? phone;
  final String? email;
  final String status;
  final String? accountManagerEmployeeId;
  final DateTime? dateAcquired;
  final String? leadSource;
  final DateTime? contractStartDate;
  final DateTime? contractEndDate;
  final String? notes;
  final DateTime syncCreatedAt;
  final DateTime syncUpdatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  const OrganizationModel({
    required this.id,
    required this.companyName,
    this.registrationNumber,
    this.industry,
    this.address,
    this.phone,
    this.email,
    required this.status,
    this.accountManagerEmployeeId,
    this.dateAcquired,
    this.leadSource,
    this.contractStartDate,
    this.contractEndDate,
    this.notes,
    required this.syncCreatedAt,
    required this.syncUpdatedAt,
    required this.isDeleted,
    this.deletedAt,
  });

  static const List<String> validStatuses = [
    'Prospect',
    'Contacted',
    'Negotiating',
    'Onboarding',
    'Active',
    'Dormant',
    'Suspended',
    'Lost',
    'Closed',
  ];

  factory OrganizationModel.fromMap(Map<String, dynamic> map) {
    return OrganizationModel(
      id: map['id'] as String,
      companyName: map['company_name'] as String,
      registrationNumber: map['registration_number'] as String?,
      industry: map['industry'] as String?,
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      status: map['status'] as String? ?? 'Prospect',
      accountManagerEmployeeId: map['account_manager_employee_id'] as String?,
      dateAcquired: map['date_acquired'] != null
          ? DateTime.tryParse(map['date_acquired'] as String)
          : null,
      leadSource: map['lead_source'] as String?,
      contractStartDate: map['contract_start_date'] != null
          ? DateTime.tryParse(map['contract_start_date'] as String)
          : null,
      contractEndDate: map['contract_end_date'] != null
          ? DateTime.tryParse(map['contract_end_date'] as String)
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
      'company_name': companyName,
      'registration_number': registrationNumber,
      'industry': industry,
      'address': address,
      'phone': phone,
      'email': email,
      'status': status,
      'account_manager_employee_id': accountManagerEmployeeId,
      'date_acquired': dateAcquired?.toIso8601String(),
      'lead_source': leadSource,
      'contract_start_date': contractStartDate?.toIso8601String(),
      'contract_end_date': contractEndDate?.toIso8601String(),
      'notes': notes,
      'SyncCreatedAt': syncCreatedAt.toIso8601String(),
      'SyncUpdatedAt': syncUpdatedAt.toIso8601String(),
      'IsDeleted': isDeleted ? 1 : 0,
      'DeletedAt': deletedAt?.toIso8601String(),
    };
  }

  OrganizationModel copyWith({
    String? companyName,
    String? registrationNumber,
    String? industry,
    String? address,
    String? phone,
    String? email,
    String? status,
    String? accountManagerEmployeeId,
    DateTime? dateAcquired,
    String? leadSource,
    DateTime? contractStartDate,
    DateTime? contractEndDate,
    String? notes,
    DateTime? syncUpdatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return OrganizationModel(
      id: id,
      companyName: companyName ?? this.companyName,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      industry: industry ?? this.industry,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      status: status ?? this.status,
      accountManagerEmployeeId:
          accountManagerEmployeeId ?? this.accountManagerEmployeeId,
      dateAcquired: dateAcquired ?? this.dateAcquired,
      leadSource: leadSource ?? this.leadSource,
      contractStartDate: contractStartDate ?? this.contractStartDate,
      contractEndDate: contractEndDate ?? this.contractEndDate,
      notes: notes ?? this.notes,
      syncCreatedAt: syncCreatedAt,
      syncUpdatedAt: syncUpdatedAt ?? this.syncUpdatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
