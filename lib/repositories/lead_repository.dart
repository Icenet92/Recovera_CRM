import 'package:uuid/uuid.dart';
import 'base_repository.dart';
import 'audit_repository.dart';
import '../models/lead_model.dart';

class LeadRepository extends BaseRepository {
  final AuditRepository _auditRepo;

  LeadRepository(super.dbHelper, this._auditRepo);

  Future<LeadModel> create({
    String? organizationId,
    required String title,
    String? ownerEmployeeId,
    String? source,
    double? expectedValue,
    String currency = 'RWF',
    String status = 'New',
    String? nextAction,
    DateTime? followupDate,
    String? notes,
  }) async {
    requirePermission('lead.manage');
    final db = await database;

    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();

    final lead = LeadModel(
      id: id,
      organizationId: organizationId,
      title: title,
      ownerEmployeeId: ownerEmployeeId,
      source: source,
      expectedValue: expectedValue,
      currency: currency,
      status: status,
      nextAction: nextAction,
      followupDate: followupDate,
      notes: notes,
      syncCreatedAt: now,
      syncUpdatedAt: now,
      isDeleted: false,
    );

    await db.insert('leads', lead.toMap());

    await _auditRepo.log(
      userId: currentSession.userId,
      action: 'crm.lead.create',
      entityType: 'lead',
      entityId: id,
      newValue: title,
    );

    return lead;
  }

  Future<LeadModel> update(LeadModel lead) async {
    requirePermission('lead.manage');
    final db = await database;

    final updated = lead.copyWith(syncUpdatedAt: DateTime.now().toUtc());
    await db.update(
      'leads',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [lead.id],
    );

    await _auditRepo.log(
      userId: currentSession.userId,
      action: 'crm.lead.update',
      entityType: 'lead',
      entityId: lead.id,
    );

    return updated;
  }

  /// Move a lead to a different pipeline stage and log the transition.
  Future<LeadModel> moveToStage(String leadId, String newStatus) async {
    requirePermission('lead.manage');
    final db = await database;

    final rows = await db.query(
      'leads',
      where: 'id = ? AND IsDeleted = 0',
      whereArgs: [leadId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('Lead not found: $leadId');

    final lead = LeadModel.fromMap(rows.first);
    final oldStatus = lead.status;
    final nowStr = DateTime.now().toUtc().toIso8601String();

    await db.update(
      'leads',
      {'status': newStatus, 'SyncUpdatedAt': nowStr},
      where: 'id = ?',
      whereArgs: [leadId],
    );

    await _auditRepo.log(
      userId: currentSession.userId,
      action: 'crm.lead.stage_change',
      entityType: 'lead',
      entityId: leadId,
      oldValue: oldStatus,
      newValue: newStatus,
    );

    return lead.copyWith(status: newStatus, syncUpdatedAt: DateTime.parse(nowStr));
  }

  Future<void> softDelete(String id) async {
    requirePermission('lead.manage');
    final db = await database;
    final nowStr = DateTime.now().toUtc().toIso8601String();

    await db.update(
      'leads',
      {'IsDeleted': 1, 'DeletedAt': nowStr, 'SyncUpdatedAt': nowStr},
      where: 'id = ?',
      whereArgs: [id],
    );

    await _auditRepo.log(
      userId: currentSession.userId,
      action: 'crm.lead.delete',
      entityType: 'lead',
      entityId: id,
    );
  }

  Future<LeadModel?> getById(String id) async {
    requirePermission('crm.view');
    final db = await database;
    final rows = await db.query(
      'leads',
      where: 'id = ? AND IsDeleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LeadModel.fromMap(rows.first);
  }

  Future<List<LeadModel>> getAll() async {
    requirePermission('crm.view');
    final db = await database;
    final rows = await db.query(
      'leads',
      where: 'IsDeleted = 0',
      orderBy: 'SyncCreatedAt DESC',
    );
    return rows.map(LeadModel.fromMap).toList();
  }

  Future<List<LeadModel>> getByStatus(String status) async {
    requirePermission('crm.view');
    final db = await database;
    final rows = await db.query(
      'leads',
      where: 'IsDeleted = 0 AND status = ?',
      whereArgs: [status],
      orderBy: 'SyncCreatedAt DESC',
    );
    return rows.map(LeadModel.fromMap).toList();
  }
}
