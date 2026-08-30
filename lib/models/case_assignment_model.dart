class CaseAssignmentModel {
  final String id;
  final String caseId;
  final String assignedByEmployeeId;
  final String assignedToEmployeeId;
  final String? supervisorId;
  final DateTime assignmentDate;
  final String? reason;

  const CaseAssignmentModel({
    required this.id,
    required this.caseId,
    required this.assignedByEmployeeId,
    required this.assignedToEmployeeId,
    this.supervisorId,
    required this.assignmentDate,
    this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'case_id': caseId,
      'assigned_by_employee_id': assignedByEmployeeId,
      'assigned_to_employee_id': assignedToEmployeeId,
      'supervisor_id': supervisorId,
      'assignment_date': assignmentDate.toIso8601String(),
      'reason': reason,
    };
  }

  factory CaseAssignmentModel.fromMap(Map<String, dynamic> map) {
    return CaseAssignmentModel(
      id: map['id'] as String,
      caseId: map['case_id'] as String,
      assignedByEmployeeId: map['assigned_by_employee_id'] as String,
      assignedToEmployeeId: map['assigned_to_employee_id'] as String,
      supervisorId: map['supervisor_id'] as String?,
      assignmentDate: DateTime.parse(map['assignment_date'] as String),
      reason: map['reason'] as String?,
    );
  }
}

class CaseStatusHistoryModel {
  final String id;
  final String caseId;
  final String changedByEmployeeId;
  final String? oldStatus;
  final String newStatus;
  final DateTime changeDate;
  final String? reason;

  const CaseStatusHistoryModel({
    required this.id,
    required this.caseId,
    required this.changedByEmployeeId,
    this.oldStatus,
    required this.newStatus,
    required this.changeDate,
    this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'case_id': caseId,
      'changed_by_employee_id': changedByEmployeeId,
      'old_status': oldStatus,
      'new_status': newStatus,
      'change_date': changeDate.toIso8601String(),
      'reason': reason,
    };
  }

  factory CaseStatusHistoryModel.fromMap(Map<String, dynamic> map) {
    return CaseStatusHistoryModel(
      id: map['id'] as String,
      caseId: map['case_id'] as String,
      changedByEmployeeId: map['changed_by_employee_id'] as String,
      oldStatus: map['old_status'] as String?,
      newStatus: map['new_status'] as String,
      changeDate: DateTime.parse(map['change_date'] as String),
      reason: map['reason'] as String?,
    );
  }
}

class CaseSupportingEmployeeModel {
  final String id;
  final String caseId;
  final String employeeId;
  final String addedByEmployeeId;
  final DateTime addedDate;

  const CaseSupportingEmployeeModel({
    required this.id,
    required this.caseId,
    required this.employeeId,
    required this.addedByEmployeeId,
    required this.addedDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'case_id': caseId,
      'employee_id': employeeId,
      'added_by_employee_id': addedByEmployeeId,
      'added_date': addedDate.toIso8601String(),
    };
  }

  factory CaseSupportingEmployeeModel.fromMap(Map<String, dynamic> map) {
    return CaseSupportingEmployeeModel(
      id: map['id'] as String,
      caseId: map['case_id'] as String,
      employeeId: map['employee_id'] as String,
      addedByEmployeeId: map['added_by_employee_id'] as String,
      addedDate: DateTime.parse(map['added_date'] as String),
    );
  }
}
