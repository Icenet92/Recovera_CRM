import 'package:uuid/uuid.dart';
import '../models/case_model.dart';
import '../models/recovery_assignment_model.dart';
import 'base_repository.dart';

/// Repository for Phase 3B — Recovery Assignments (Case Pools).
///
/// A recovery assignment (a "batch") pools one or more cases for a single
/// Recovery Officer and tracks a target recovery amount + deadline.
///
/// Permission model (granular, no wildcards):
/// - `assignment.create` — create a batch + pool cases.
/// - `assignment.edit` — change status / remove a case from a batch.
/// - `assignment.view`  — read batches / cases / officers.
/// - `assignment.delete` — (reserved for future soft-delete).
/// Super-admins bypass all checks via [AuthSession.hasPermission].
///
/// Row scoping: a Recovery Officer only ever sees their own batches through
/// [getByEmployee], and [getById] enforces an ownership guard for them.
class RecoveryAssignmentRepository extends BaseRepository {
  RecoveryAssignmentRepository(super.db);

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Creates a recovery assignment and pools [caseIds] into it.
  ///
  /// Active-batch guard: each case may belong to at most one *active* batch
  /// (a `case_assignment_batch_history` row with `removed_date IS NULL`). If
  /// any case is already pooled into another active batch, this throws.
  Future<RecoveryAssignmentModel> create(
    RecoveryAssignmentModel assignment,
    List<String> caseIds,
  ) async {
    requirePermission('assignment.create');

    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();

    // Active-batch exclusion rule.
    for (final cid in caseIds) {
      final existing = await db.query(
        'case_assignment_batch_history',
        columns: ['id'],
        where:
            'case_id = ? AND removed_date IS NULL AND IsDeleted = 0',
        whereArgs: [cid],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw Exception(
          "Case '$cid' is already pooled into an active recovery batch; "
          'remove it from that batch before assigning it elsewhere.',
        );
      }
    }

    await db.transaction((txn) async {
      await txn.insert('recovery_assignments', {
        ...assignment.toMap(),
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });

      for (final cid in caseIds) {
        await txn.insert('case_assignment_batch_history', {
          'id': const Uuid().v4(),
          'recovery_assignment_id': assignment.id,
          'case_id': cid,
          'added_date': now,
          'removed_date': null,
          'SyncCreatedAt': now,
          'SyncUpdatedAt': now,
          'IsDeleted': 0,
          'DeletedAt': null,
        });
      }

      // Audit log (mirrors case.assign / case.status_change).
      await txn.insert('audit_logs', {
        'id': const Uuid().v4(),
        'user_id': currentSession.userId,
        'action': 'assignment.create',
        'entity_type': 'recovery_assignments',
        'entity_id': assignment.id,
        'new_value': '${caseIds.length} cases pooled',
        'timestamp': now,
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });
    });

    return assignment;
  }

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Loads a single batch by id.
  ///
  /// Ownership guard: a non-superadmin Recovery Officer may only load batches
  /// assigned to them. Managers (assignment.view without the officer role)
  /// may view any batch in their scope.
  Future<RecoveryAssignmentModel?> getById(String id) async {
    requirePermission('assignment.view');
    final db = await database;

    final rows = await db.query(
      'recovery_assignments',
      where: 'id = ? AND IsDeleted = 0',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;

    final assignment = RecoveryAssignmentModel.fromMap(rows.first);
    final isOfficer = currentSession.roleName == 'Recovery Officer';
    if (!currentSession.isSuperAdmin &&
        isOfficer &&
        assignment.assignedEmployeeId != currentSession.userId) {
      throw Exception('Not authorized to view this recovery assignment.');
    }
    return assignment;
  }

  /// Active cases currently pooled in this batch.
  Future<List<CaseModel>> getAssignmentCases(String assignmentId) async {
    requirePermission('assignment.view');
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT c.* FROM case_assignment_batch_history bah
      INNER JOIN cases c ON c.id = bah.case_id
      WHERE bah.recovery_assignment_id = ?
        AND bah.removed_date IS NULL
        AND bah.IsDeleted = 0
        AND c.IsDeleted = 0
      ORDER BY c.SyncUpdatedAt DESC
    ''', [assignmentId]);
    return rows.map((r) => CaseModel.fromMap(r)).toList();
  }

  /// Row-scoped list for an officer (their own batches).
  Future<List<RecoveryAssignmentModel>> getByEmployee(
    String employeeId, {
    bool activeOnly = true,
  }) async {
    requirePermission('assignment.view');
    final db = await database;
    final where = activeOnly
        ? "assigned_employee_id = ? AND IsDeleted = 0 AND status = 'Active'"
        : 'assigned_employee_id = ? AND IsDeleted = 0';
    final rows = await db.query(
      'recovery_assignments',
      where: where,
      whereArgs: [employeeId],
      orderBy: 'SyncUpdatedAt DESC',
    );
    return rows.map((r) => RecoveryAssignmentModel.fromMap(r)).toList();
  }

  /// Manager scope: all active batches whose pooled cases belong to a client.
  Future<List<RecoveryAssignmentModel>> getByClient(String clientId) async {
    requirePermission('assignment.view');
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT ra.* FROM recovery_assignments ra
      INNER JOIN case_assignment_batch_history bah
        ON bah.recovery_assignment_id = ra.id
      INNER JOIN cases c ON c.id = bah.case_id
      WHERE c.organization_id = ?
        AND ra.IsDeleted = 0
        AND bah.removed_date IS NULL
        AND bah.IsDeleted = 0
        AND c.IsDeleted = 0
      ORDER BY ra.SyncUpdatedAt DESC
    ''', [clientId]);
    return rows.map((r) => RecoveryAssignmentModel.fromMap(r)).toList();
  }

  /// Manager scope: all recovery assignments visible to the current session.
  /// Recovery Officers see only their own batches (mirrors [getById]'s
  /// ownership guard); Managers / Execs / Directors / SuperAdmins see all.
  Future<List<RecoveryAssignmentModel>> getAll({bool activeOnly = true}) async {
    requirePermission('assignment.view');
    final isOfficer = currentSession.roleName == 'Recovery Officer';
    final statusClause = activeOnly ? " AND status = 'Active'" : '';
    final db = await database;

    final rows = await db.query(
      'recovery_assignments',
      where: isOfficer
          ? 'assigned_employee_id = ? AND IsDeleted = 0$statusClause'
          : 'IsDeleted = 0$statusClause',
      whereArgs: isOfficer ? [currentSession.userId] : [],
      orderBy: 'SyncUpdatedAt DESC',
    );
    return rows.map((r) => RecoveryAssignmentModel.fromMap(r)).toList();
  }

  /// Picker source for the Create flow: all active Recovery Officer users.
  Future<List<Map<String, dynamic>>> listRecoveryOfficers() async {
    requirePermission('assignment.view');
    final db = await database;
    return db.rawQuery('''
      SELECT u.id AS id, u.username AS username,
             e.first_name AS first_name, e.last_name AS last_name
      FROM users u
      INNER JOIN roles r ON r.id = u.role_id
      LEFT JOIN employees e ON e.id = u.employee_id
      WHERE r.name = 'Recovery Officer'
        AND u.is_active = 1
        AND u.IsDeleted = 0
      ORDER BY u.username ASC
    ''');
  }

  /// The `added_date` for a case within a batch — used for time-to-recovery.
  Future<DateTime?> getCaseAddedDate(String assignmentId, String caseId) async {
    requirePermission('assignment.view');
    final db = await database;
    final rows = await db.query(
      'case_assignment_batch_history',
      columns: ['added_date'],
      where:
          'recovery_assignment_id = ? AND case_id = ? '
          'AND removed_date IS NULL AND IsDeleted = 0',
      whereArgs: [assignmentId, caseId],
    );
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['added_date'] as String);
  }

  // ── Mutate status / membership ─────────────────────────────────────────────

  /// Persists only `Active|Completed|Cancelled`. `Overdue` is computed read-time.
  Future<void> updateStatus(String id, String status) async {
    requirePermission('assignment.edit');
    if (status == 'Overdue') {
      throw Exception(
        'Status "Overdue" is computed read-time and cannot be persisted.',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final db = await database;

    await db.update(
      'recovery_assignments',
      {'status': status, 'SyncUpdatedAt': now},
      where: 'id = ? AND IsDeleted = 0',
      whereArgs: [id],
    );

    await db.insert('audit_logs', {
      'id': const Uuid().v4(),
      'user_id': currentSession.userId,
      'action': 'assignment.update_status',
      'entity_type': 'recovery_assignments',
      'entity_id': id,
      'new_value': status,
      'timestamp': now,
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });
  }

  /// Soft-removes a case from the batch (sets `removed_date`).
  Future<void> removeCaseFromBatch(String assignmentId, String caseId) async {
    requirePermission('assignment.edit');
    final now = DateTime.now().toUtc().toIso8601String();
    final db = await database;

    await db.update(
      'case_assignment_batch_history',
      {'removed_date': now, 'SyncUpdatedAt': now},
      where:
          'recovery_assignment_id = ? AND case_id = ? '
          'AND removed_date IS NULL AND IsDeleted = 0',
      whereArgs: [assignmentId, caseId],
    );

    // Audit ownership/assignment-state change (mirrors case.assign/reassign).
    await db.insert('audit_logs', {
      'id': const Uuid().v4(),
      'user_id': currentSession.userId,
      'action': 'assignment.remove_case',
      'entity_type': 'case_assignment_batch_history',
      'entity_id': caseId,
      'new_value': 'removed from assignment $assignmentId',
      'timestamp': now,
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });
  }
}
