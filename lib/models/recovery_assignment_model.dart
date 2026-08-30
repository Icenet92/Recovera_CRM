/// A recovery assignment (a "case pool"): a batch of cases pooled for a single
/// Recovery Officer, with a target recovery amount and a deadline.
///
/// Per the Phase 3B design:
/// - `assignedEmployeeId` holds a **user id** (Recovering Officer user), matching
///   the existing convention where `cases.primary_owner_id` /
///   `case_assignments.assigned_to_employee_id` store user ids.
/// - `status` persists only `Active|Completed|Cancelled`. `Overdue` is a
///   read-time computed value (see [isOverdue]) — never written, exactly like the
///   app's task/SLA overdue handling.
class RecoveryAssignmentModel {
  final String id;
  final String assignedEmployeeId;
  final String assignedBy;
  final double targetAmount;
  final DateTime startDate;
  final DateTime deadlineDate;
  final String status; // Active | Completed | Cancelled
  final String? notes;

  const RecoveryAssignmentModel({
    required this.id,
    required this.assignedEmployeeId,
    required this.assignedBy,
    required this.targetAmount,
    required this.startDate,
    required this.deadlineDate,
    required this.status,
    this.notes,
  });

  /// Overdue is computed at read time: an Active assignment whose deadline has
  /// passed. Never persisted.
  bool get isOverdue =>
      status == 'Active' && deadlineDate.isBefore(DateTime.now());

  bool get isActive => status == 'Active';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'assigned_employee_id': assignedEmployeeId,
      'assigned_by': assignedBy,
      'target_amount': targetAmount,
      'start_date': startDate.toIso8601String(),
      'deadline_date': deadlineDate.toIso8601String(),
      'status': status,
      'notes': notes,
    };
  }

  factory RecoveryAssignmentModel.fromMap(Map<String, dynamic> map) {
    return RecoveryAssignmentModel(
      id: map['id'] as String,
      assignedEmployeeId: map['assigned_employee_id'] as String,
      assignedBy: map['assigned_by'] as String,
      targetAmount: (map['target_amount'] as num?)?.toDouble() ?? 0.0,
      startDate: DateTime.parse(map['start_date'] as String),
      deadlineDate: DateTime.parse(map['deadline_date'] as String),
      status: map['status'] as String? ?? 'Active',
      notes: map['notes'] as String?,
    );
  }

  RecoveryAssignmentModel copyWith({
    String? id,
    String? assignedEmployeeId,
    String? assignedBy,
    double? targetAmount,
    DateTime? startDate,
    DateTime? deadlineDate,
    String? status,
    String? notes,
  }) {
    return RecoveryAssignmentModel(
      id: id ?? this.id,
      assignedEmployeeId: assignedEmployeeId ?? this.assignedEmployeeId,
      assignedBy: assignedBy ?? this.assignedBy,
      targetAmount: targetAmount ?? this.targetAmount,
      startDate: startDate ?? this.startDate,
      deadlineDate: deadlineDate ?? this.deadlineDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}

/// One case pooled into a [RecoveryAssignmentModel] batch.
///
/// `removedDate` is null while the case is actively in the batch; setting it
/// soft-removes the case from the pool (used by `removeCaseFromBatch` and the
/// active-batch exclusion rule).
class RecoveryAssignmentBatchHistoryModel {
  final String id;
  final String recoveryAssignmentId;
  final String caseId;
  final DateTime addedDate;
  final DateTime? removedDate;

  const RecoveryAssignmentBatchHistoryModel({
    required this.id,
    required this.recoveryAssignmentId,
    required this.caseId,
    required this.addedDate,
    this.removedDate,
  });

  bool get isPresent => removedDate == null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recovery_assignment_id': recoveryAssignmentId,
      'case_id': caseId,
      'added_date': addedDate.toIso8601String(),
      'removed_date': removedDate?.toIso8601String(),
    };
  }

  factory RecoveryAssignmentBatchHistoryModel.fromMap(Map<String, dynamic> map) {
    return RecoveryAssignmentBatchHistoryModel(
      id: map['id'] as String,
      recoveryAssignmentId: map['recovery_assignment_id'] as String,
      caseId: map['case_id'] as String,
      addedDate: DateTime.parse(map['added_date'] as String),
      removedDate: map['removed_date'] != null
          ? DateTime.parse(map['removed_date'] as String)
          : null,
    );
  }

  RecoveryAssignmentBatchHistoryModel copyWith({
    String? id,
    String? recoveryAssignmentId,
    String? caseId,
    DateTime? addedDate,
    DateTime? removedDate,
  }) {
    return RecoveryAssignmentBatchHistoryModel(
      id: id ?? this.id,
      recoveryAssignmentId: recoveryAssignmentId ?? this.recoveryAssignmentId,
      caseId: caseId ?? this.caseId,
      addedDate: addedDate ?? this.addedDate,
      removedDate: removedDate ?? this.removedDate,
    );
  }
}
