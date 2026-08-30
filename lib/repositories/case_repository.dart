import 'package:uuid/uuid.dart';
import '../models/case_model.dart';
import '../models/case_assignment_model.dart'; // includes CaseAssignmentModel, CaseStatusHistoryModel, CaseSupportingEmployeeModel
import 'base_repository.dart';

/// Aggregated stats for a client workspace.
class ClientCaseStats {
  final int totalDebtors;
  final int totalCases;
  final double totalClaimed;
  final double totalRecovered;
  final double totalOutstanding;
  final int overdueCount;

  const ClientCaseStats({
    required this.totalDebtors,
    required this.totalCases,
    required this.totalClaimed,
    required this.totalOutstanding,
    required this.totalRecovered,
    required this.overdueCount,
  });
}

/// Per-debtor stats for the Debtors tab inside Client Workspace.
class DebtorCaseStats {
  final String debtorId;
  final String debtorName;
  final int caseCount;
  final double outstandingTotal;

  const DebtorCaseStats({
    required this.debtorId,
    required this.debtorName,
    required this.caseCount,
    required this.outstandingTotal,
  });
}

class CaseRepository extends BaseRepository {
  CaseRepository(super.db);

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<List<CaseModel>> getAll() async {
    requirePermission('case.view');
    final results = await (await database).query(
      'cases',
      where: 'IsDeleted = ?',
      whereArgs: [0],
    );
    return results.map((e) => CaseModel.fromMap(e)).toList();
  }

  /// All cases belonging to a specific client (organization).
  Future<List<CaseModel>> getByClientId(String clientId) async {
    requirePermission('case.view');
    final results = await (await database).query(
      'cases',
      where: 'organization_id = ? AND IsDeleted = ?',
      whereArgs: [clientId, 0],
      orderBy: 'SyncUpdatedAt DESC',
    );
    return results.map((e) => CaseModel.fromMap(e)).toList();
  }

  /// All cases belonging to a specific debtor.
  Future<List<CaseModel>> getByDebtorId(String debtorId) async {
    requirePermission('case.view');
    final results = await (await database).query(
      'cases',
      where: 'debtor_id = ? AND IsDeleted = ?',
      whereArgs: [debtorId, 0],
      orderBy: 'SyncUpdatedAt DESC',
    );
    return results.map((e) => CaseModel.fromMap(e)).toList();
  }

  Future<CaseModel?> getById(String id) async {
    requirePermission('case.view');
    final results = await (await database).query(
      'cases',
      where: 'id = ? AND IsDeleted = ?',
      whereArgs: [id, 0],
    );
    if (results.isEmpty) return null;
    return CaseModel.fromMap(results.first);
  }

  Future<List<CaseAssignmentModel>> getAssignments(String caseId) async {
    requirePermission('case.view');
    final results = await (await database).query(
      'case_assignments',
      where: 'case_id = ? AND IsDeleted = ?',
      whereArgs: [caseId, 0],
      orderBy: 'assignment_date DESC',
    );
    return results.map((e) => CaseAssignmentModel.fromMap(e)).toList();
  }

  Future<List<CaseStatusHistoryModel>> getStatusHistory(String caseId) async {
    requirePermission('case.view');
    final results = await (await database).query(
      'case_status_history',
      where: 'case_id = ? AND IsDeleted = ?',
      whereArgs: [caseId, 0],
      orderBy: 'change_date DESC',
    );
    return results.map((e) => CaseStatusHistoryModel.fromMap(e)).toList();
  }

  /// Auto-generates the CASE-YYYY-XXXXXX number
  Future<String> _generateCaseNumber() async {
    final year = DateTime.now().year;
    final prefix = 'CASE-$year-';

    // Find the highest sequence number this year
    final results = await (await database).rawQuery(
      "SELECT case_number FROM cases WHERE case_number LIKE ? ORDER BY case_number DESC LIMIT 1",
      ['$prefix%'],
    );

    int nextSeq = 1;
    if (results.isNotEmpty) {
      final lastNum = results.first['case_number'] as String;
      final seqStr = lastNum.substring(prefix.length);
      final seq = int.tryParse(seqStr);
      if (seq != null) {
        nextSeq = seq + 1;
      }
    }

    return '$prefix${nextSeq.toString().padLeft(6, '0')}';
  }

  /// Validates that the debtor belongs to the specified client (organization).
  Future<void> _validateDebtorBelongsToClient(
    String clientId,
    String debtorId,
  ) async {
    final debtorRows = await (await database).query(
      'debtors',
      columns: ['client_id'],
      where: 'id = ? AND IsDeleted = ?',
      whereArgs: [debtorId, 0],
    );
    if (debtorRows.isEmpty) {
      throw Exception('Debtor not found.');
    }
    final debtorClientId = debtorRows.first['client_id'] as String;
    if (debtorClientId != clientId) {
      throw Exception(
        'Cannot assign a case to a debtor belonging to a different client. '
        'The selected debtor belongs to a different organization.',
      );
    }
  }

  Future<CaseModel> create(CaseModel c) async {
    requirePermission('case.create');

    // Cross-client enforcement: debtor must belong to the same client as the case
    await _validateDebtorBelongsToClient(c.organizationId, c.debtorId);

    final now = DateTime.now().toUtc().toIso8601String();

    final caseNum = await _generateCaseNumber();
    final newCase = c.copyWith(caseNumber: caseNum);

    await (await database).transaction((txn) async {
      await txn.insert('cases', {
        ...newCase.toMap(),
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });

      // Log assignment if owner is set
      if (newCase.primaryOwnerId != null) {
        await txn.insert('case_assignments', {
          'id': const Uuid().v4(),
          'case_id': newCase.id,
          'assigned_by_employee_id': currentSession.userId,
          'assigned_to_employee_id': newCase.primaryOwnerId,
          'supervisor_id': newCase.supervisorId,
          'assignment_date': now,
          'reason': 'Initial case creation.',
          'SyncCreatedAt': now,
          'SyncUpdatedAt': now,
          'IsDeleted': 0,
          'DeletedAt': null,
        });
      }

      // Log status
      await txn.insert('case_status_history', {
        'id': const Uuid().v4(),
        'case_id': newCase.id,
        'changed_by_employee_id': currentSession.userId,
        'new_status': newCase.status,
        'change_date': now,
        'reason': 'Case created.',
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });

      // Audit log
      await txn.insert('audit_logs', {
        'id': const Uuid().v4(),
        'user_id': currentSession.userId,
        'action': 'case.create',
        'entity_type': 'cases',
        'entity_id': newCase.id,
        'new_value': caseNum,
        'timestamp': now,
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });
    });

    return newCase;
  }

  Future<void> update(CaseModel c) async {
    requirePermission('case.edit');

    // Also validate on update if org or debtor changed
    await _validateDebtorBelongsToClient(c.organizationId, c.debtorId);

    final now = DateTime.now().toUtc().toIso8601String();

    await (await database).update(
      'cases',
      {...c.toMap(), 'SyncUpdatedAt': now},
      where: 'id = ?',
      whereArgs: [c.id],
    );

    await (await database).insert('audit_logs', {
      'id': const Uuid().v4(),
      'user_id': currentSession.userId,
      'action': 'case.update',
      'entity_type': 'cases',
      'entity_id': c.id,
      'timestamp': now,
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });
  }

  // ── Aggregation ─────────────────────────────────────────────────────────

  /// Returns live-aggregated stats for a client's debtors and cases.
  Future<ClientCaseStats> getClientAggregatedStats(String clientId) async {
    requirePermission('case.view');
    final db = await database;

    // Total debtors for this client
    final debtorCountResult = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM debtors WHERE client_id = ? AND IsDeleted = 0",
      [clientId],
    );
    final totalDebtors = (debtorCountResult.first['cnt'] as int?) ?? 0;

    // Cases for this client
    final cases = await getByClientId(clientId);
    final totalCases = cases.length;
    final totalClaimed = cases.fold<double>(0, (sum, c) => sum + c.totalClaim);
    // Phase 5: totalRecovered will come from payments table. For now, 0.
    final totalRecovered = 0.0;
    final totalOutstanding = totalClaimed - totalRecovered;
    final overdueCount = cases
        .where(
          (c) =>
              c.deadline != null &&
              c.deadline!.isBefore(DateTime.now()) &&
              !c.status.toLowerCase().contains('closed'),
        )
        .length;

    return ClientCaseStats(
      totalDebtors: totalDebtors,
      totalCases: totalCases,
      totalClaimed: totalClaimed,
      totalOutstanding: totalOutstanding,
      totalRecovered: totalRecovered,
      overdueCount: overdueCount,
    );
  }

  /// Returns per-debtor case counts and outstanding totals for a client.
  Future<List<DebtorCaseStats>> getDebtorCaseStatsForClient(
    String clientId,
  ) async {
    requirePermission('case.view');
    final db = await database;

    final results = await db.rawQuery(
      '''
      SELECT
        d.id AS debtor_id,
        d.name AS debtor_name,
        COUNT(c.id) AS case_count,
        COALESCE(SUM(c.total_claim), 0) AS outstanding_total
      FROM debtors d
      LEFT JOIN cases c ON c.debtor_id = d.id AND c.IsDeleted = 0
      WHERE d.client_id = ? AND d.IsDeleted = 0
      GROUP BY d.id
      ORDER BY d.name ASC
    ''',
      [clientId],
    );

    return results
        .map(
          (row) => DebtorCaseStats(
            debtorId: row['debtor_id'] as String,
            debtorName: row['debtor_name'] as String,
            caseCount: (row['case_count'] as int?) ?? 0,
            outstandingTotal:
                (row['outstanding_total'] as num?)?.toDouble() ?? 0.0,
          ),
        )
        .toList();
  }

  /// Returns a map of debtorId -> open case count across ALL clients.
  /// Used by the Debtors list screen to show a case count per debtor.
  Future<Map<String, int>> getCaseCountsByDebtor() async {
    requirePermission('case.view');
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT debtor_id, COUNT(*) AS cnt FROM cases
      WHERE IsDeleted = 0
      GROUP BY debtor_id
    ''');
    return {
      for (var r in rows) r['debtor_id'] as String: (r['cnt'] as int?) ?? 0,
    };
  }

  // ── Assignment & Status ─────────────────────────────────────────────────

  Future<void> assignCase(
    String caseId,
    String newOwnerId,
    String? supervisorId,
    String reason,
  ) async {
    requirePermission('case.assign');
    final now = DateTime.now().toUtc().toIso8601String();

    await (await database).transaction((txn) async {
      await txn.update(
        'cases',
        {
          'primary_owner_id': newOwnerId,
          'supervisor_id': supervisorId,
          'SyncUpdatedAt': now,
        },
        where: 'id = ?',
        whereArgs: [caseId],
      );

      await txn.insert('case_assignments', {
        'id': const Uuid().v4(),
        'case_id': caseId,
        'assigned_by_employee_id': currentSession.userId,
        'assigned_to_employee_id': newOwnerId,
        'supervisor_id': supervisorId,
        'assignment_date': now,
        'reason': reason,
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });

      await txn.insert('audit_logs', {
        'id': const Uuid().v4(),
        'user_id': currentSession.userId,
        'action': 'case.assign',
        'entity_type': 'cases',
        'entity_id': caseId,
        'new_value': newOwnerId,
        'timestamp': now,
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });
    });
  }

  Future<void> changeStatus(
    String caseId,
    String newStatus,
    String reason,
  ) async {
    final isClosing = newStatus.toLowerCase().contains('closed');
    if (isClosing) {
      requirePermission('case.close');
    } else {
      requirePermission('case.edit');
    }

    final now = DateTime.now().toUtc().toIso8601String();

    await (await database).transaction((txn) async {
      final old = await txn.query(
        'cases',
        where: 'id = ?',
        whereArgs: [caseId],
      );
      final oldStatus = old.isNotEmpty ? old.first['status'] as String : null;

      final isReopening =
          (oldStatus?.toLowerCase().contains('closed') ?? false) && !isClosing;
      if (isReopening && !currentSession.hasPermission('case.reopen')) {
        throw Exception(
          'Action requires authentication (requires: case.reopen)',
        );
      }

      await txn.update(
        'cases',
        {
          'status': newStatus,
          if (isClosing) 'date_closed': now,
          if (isReopening) 'date_closed': null,
          'SyncUpdatedAt': now,
        },
        where: 'id = ?',
        whereArgs: [caseId],
      );

      await txn.insert('case_status_history', {
        'id': const Uuid().v4(),
        'case_id': caseId,
        'changed_by_employee_id': currentSession.userId,
        'old_status': oldStatus,
        'new_status': newStatus,
        'change_date': now,
        'reason': reason,
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });

      await txn.insert('audit_logs', {
        'id': const Uuid().v4(),
        'user_id': currentSession.userId,
        'action': 'case.status_change',
        'entity_type': 'cases',
        'entity_id': caseId,
        'old_value': oldStatus,
        'new_value': newStatus,
        'timestamp': now,
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });
    });
  }

  // ── Supporting Employees ────────────────────────────────────────────────────

  Future<List<CaseSupportingEmployeeModel>> getSupportingEmployees(
    String caseId,
  ) async {
    requirePermission('case.view');
    final results = await (await database).query(
      'case_supporting_employees',
      where: 'case_id = ? AND IsDeleted = ?',
      whereArgs: [caseId, 0],
      orderBy: 'added_date ASC',
    );
    return results.map((e) => CaseSupportingEmployeeModel.fromMap(e)).toList();
  }

  Future<void> addSupportingEmployee(String caseId, String employeeId) async {
    requirePermission('case.assign');
    final now = DateTime.now().toUtc().toIso8601String();
    final id = const Uuid().v4();

    await (await database).transaction((txn) async {
      await txn.insert('case_supporting_employees', {
        'id': id,
        'case_id': caseId,
        'employee_id': employeeId,
        'added_by_employee_id': currentSession.userId,
        'added_date': now,
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });

      await txn.insert('audit_logs', {
        'id': const Uuid().v4(),
        'user_id': currentSession.userId,
        'action': 'case.supporting_employee_added',
        'entity_type': 'cases',
        'entity_id': caseId,
        'new_value': employeeId,
        'timestamp': now,
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });
    });
  }

  Future<void> removeSupportingEmployee(
    String caseId,
    String employeeId,
  ) async {
    requirePermission('case.assign');
    final now = DateTime.now().toUtc().toIso8601String();

    await (await database).transaction((txn) async {
      await txn.update(
        'case_supporting_employees',
        {'IsDeleted': 1, 'DeletedAt': now, 'SyncUpdatedAt': now},
        where: 'case_id = ? AND employee_id = ? AND IsDeleted = ?',
        whereArgs: [caseId, employeeId, 0],
      );

      await txn.insert('audit_logs', {
        'id': const Uuid().v4(),
        'user_id': currentSession.userId,
        'action': 'case.supporting_employee_removed',
        'entity_type': 'cases',
        'entity_id': caseId,
        'old_value': employeeId,
        'timestamp': now,
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });
    });
  }
}
