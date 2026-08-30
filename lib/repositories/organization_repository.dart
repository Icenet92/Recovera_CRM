import 'package:uuid/uuid.dart';
import 'base_repository.dart';
import 'audit_repository.dart';
import '../models/organization_model.dart';

class OrganizationRepository extends BaseRepository {
  final AuditRepository _auditRepo;

  OrganizationRepository(super.dbHelper, this._auditRepo);

  Future<OrganizationModel> create({
    required String companyName,
    String? registrationNumber,
    String? industry,
    String? address,
    String? phone,
    String? email,
    String status = 'Prospect',
    String? accountManagerEmployeeId,
    DateTime? dateAcquired,
    String? leadSource,
    DateTime? contractStartDate,
    DateTime? contractEndDate,
    String? notes,
  }) async {
    requirePermission('crm.create');
    final db = await database;

    // One client per company: reject if a non-deleted org with the same name exists
    final existing = await db.query(
      'organizations',
      columns: ['id'],
      where: 'LOWER(company_name) = LOWER(?) AND IsDeleted = 0',
      whereArgs: [companyName],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw Exception('A client with the name "$companyName" already exists. One client per company.');
    }

    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();

    final org = OrganizationModel(
      id: id,
      companyName: companyName,
      registrationNumber: registrationNumber,
      industry: industry,
      address: address,
      phone: phone,
      email: email,
      status: status,
      accountManagerEmployeeId: accountManagerEmployeeId,
      dateAcquired: dateAcquired,
      leadSource: leadSource,
      contractStartDate: contractStartDate,
      contractEndDate: contractEndDate,
      notes: notes,
      syncCreatedAt: now,
      syncUpdatedAt: now,
      isDeleted: false,
    );

    await db.insert('organizations', org.toMap());

    await _auditRepo.log(
      userId: currentSession.userId,
      action: 'crm.organization.create',
      entityType: 'organization',
      entityId: id,
      newValue: companyName,
    );

    return org;
  }

  Future<OrganizationModel> update(OrganizationModel org) async {
    requirePermission('crm.edit');
    final db = await database;

    final updated = org.copyWith(syncUpdatedAt: DateTime.now().toUtc());
    await db.update(
      'organizations',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [org.id],
    );

    await _auditRepo.log(
      userId: currentSession.userId,
      action: 'crm.organization.update',
      entityType: 'organization',
      entityId: org.id,
    );

    return updated;
  }

  Future<void> softDelete(String id) async {
    requirePermission('crm.delete');
    final db = await database;
    final nowStr = DateTime.now().toUtc().toIso8601String();

    await db.update(
      'organizations',
      {'IsDeleted': 1, 'DeletedAt': nowStr, 'SyncUpdatedAt': nowStr},
      where: 'id = ?',
      whereArgs: [id],
    );

    await _auditRepo.log(
      userId: currentSession.userId,
      action: 'crm.organization.delete',
      entityType: 'organization',
      entityId: id,
    );
  }

  Future<OrganizationModel?> getById(String id) async {
    requirePermission('crm.view');
    final db = await database;
    final rows = await db.query(
      'organizations',
      where: 'id = ? AND IsDeleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return OrganizationModel.fromMap(rows.first);
  }

  Future<List<OrganizationModel>> getAll({String? statusFilter}) async {
    requirePermission('crm.view');
    final db = await database;

    String where = 'IsDeleted = 0';
    List<dynamic> whereArgs = [];
    if (statusFilter != null) {
      where += ' AND status = ?';
      whereArgs.add(statusFilter);
    }

    final rows = await db.query(
      'organizations',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'company_name ASC',
    );
    return rows.map(OrganizationModel.fromMap).toList();
  }

  /// Global search: partial match on name, phone, email.
  Future<List<OrganizationModel>> search(String query) async {
    requirePermission('crm.view');
    final db = await database;
    final q = '%${query.toLowerCase()}%';
    final rows = await db.rawQuery('''
      SELECT * FROM organizations
      WHERE IsDeleted = 0
        AND (LOWER(company_name) LIKE ? OR LOWER(phone) LIKE ? OR LOWER(email) LIKE ?)
      ORDER BY company_name ASC
      LIMIT 50
    ''', [q, q, q]);
    return rows.map(OrganizationModel.fromMap).toList();
  }
}
