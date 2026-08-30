class CaseModel {
  final String id;
  final String caseNumber;
  final String organizationId;
  final String debtorId;
  final String? clientReference;
  final String title;
  final String? caseType;
  final String? description;
  final String priority;
  final String status;
  final String? primaryOwnerId;
  final String? supervisorId;
  final DateTime? dateReceived;
  final DateTime? deadline;
  final DateTime? dateClosed;
  final double principal;
  final double interest;
  final double penalties;
  final double fees;
  final double totalClaim;
  final String difficulty; // Easy, Medium, Difficult, Very Difficult

  const CaseModel({
    required this.id,
    required this.caseNumber,
    required this.organizationId,
    required this.debtorId,
    this.clientReference,
    required this.title,
    this.caseType,
    this.description,
    required this.priority,
    required this.status,
    this.primaryOwnerId,
    this.supervisorId,
    this.dateReceived,
    this.deadline,
    this.dateClosed,
    required this.principal,
    required this.interest,
    required this.penalties,
    required this.fees,
    required this.totalClaim,
    required this.difficulty,
  });

  /// The dynamically computed outstanding amount. 
  /// In Phase 5, this will be: totalClaim - verifiedPayments + approvedAdjustments.
  /// For now, it's just totalClaim.
  double get outstandingAmount => totalClaim;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'case_number': caseNumber,
      'organization_id': organizationId,
      'debtor_id': debtorId,
      'client_reference': clientReference,
      'title': title,
      'case_type': caseType,
      'description': description,
      'priority': priority,
      'status': status,
      'primary_owner_id': primaryOwnerId,
      'supervisor_id': supervisorId,
      'date_received': dateReceived?.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'date_closed': dateClosed?.toIso8601String(),
      'principal': principal,
      'interest': interest,
      'penalties': penalties,
      'fees': fees,
      'total_claim': totalClaim,
      'difficulty': difficulty,
    };
  }

  factory CaseModel.fromMap(Map<String, dynamic> map) {
    return CaseModel(
      id: map['id'] as String,
      caseNumber: map['case_number'] as String,
      organizationId: map['organization_id'] as String,
      debtorId: map['debtor_id'] as String,
      clientReference: map['client_reference'] as String?,
      title: map['title'] as String,
      caseType: map['case_type'] as String?,
      description: map['description'] as String?,
      priority: map['priority'] as String,
      status: map['status'] as String,
      primaryOwnerId: map['primary_owner_id'] as String?,
      supervisorId: map['supervisor_id'] as String?,
      dateReceived: map['date_received'] != null ? DateTime.parse(map['date_received'] as String) : null,
      deadline: map['deadline'] != null ? DateTime.parse(map['deadline'] as String) : null,
      dateClosed: map['date_closed'] != null ? DateTime.parse(map['date_closed'] as String) : null,
      principal: (map['principal'] as num).toDouble(),
      interest: (map['interest'] as num).toDouble(),
      penalties: (map['penalties'] as num).toDouble(),
      fees: (map['fees'] as num).toDouble(),
      totalClaim: (map['total_claim'] as num).toDouble(),
      difficulty: map['difficulty'] as String? ?? 'Medium',
    );
  }

  CaseModel copyWith({
    String? caseNumber,
    String? organizationId,
    String? debtorId,
    String? clientReference,
    String? title,
    String? caseType,
    String? description,
    String? priority,
    String? status,
    String? primaryOwnerId,
    String? supervisorId,
    DateTime? dateReceived,
    DateTime? deadline,
    DateTime? dateClosed,
    double? principal,
    double? interest,
    double? penalties,
    double? fees,
    double? totalClaim,
    String? difficulty,
  }) {
    return CaseModel(
      id: id,
      caseNumber: caseNumber ?? this.caseNumber,
      organizationId: organizationId ?? this.organizationId,
      debtorId: debtorId ?? this.debtorId,
      clientReference: clientReference ?? this.clientReference,
      title: title ?? this.title,
      caseType: caseType ?? this.caseType,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      primaryOwnerId: primaryOwnerId ?? this.primaryOwnerId,
      supervisorId: supervisorId ?? this.supervisorId,
      dateReceived: dateReceived ?? this.dateReceived,
      deadline: deadline ?? this.deadline,
      dateClosed: dateClosed ?? this.dateClosed,
      principal: principal ?? this.principal,
      interest: interest ?? this.interest,
      penalties: penalties ?? this.penalties,
      fees: fees ?? this.fees,
      totalClaim: totalClaim ?? this.totalClaim,
      difficulty: difficulty ?? this.difficulty,
    );
  }
}
