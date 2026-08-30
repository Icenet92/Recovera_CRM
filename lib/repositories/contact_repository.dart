import 'package:uuid/uuid.dart';
import 'base_repository.dart';
import 'audit_repository.dart';
import '../models/contact_model.dart';

class ContactRepository extends BaseRepository {
  final AuditRepository _auditRepo;

  ContactRepository(super.dbHelper, this._auditRepo);

  Future<ContactModel> create({
    required String organizationId,
    required String firstName,
    required String lastName,
    String? position,
    String? phone,
    String? email,
    String? preferredChannel,
    String roleType = 'Primary',
    bool isDecisionMaker = false,
    String? notes,
    DateTime? nextFollowupDate,
  }) async {
    requirePermission('crm.create');
    final db = await database;

    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();

    final contact = ContactModel(
      id: id,
      organizationId: organizationId,
      firstName: firstName,
      lastName: lastName,
      position: position,
      phone: phone,
      email: email,
      preferredChannel: preferredChannel,
      roleType: roleType,
      isDecisionMaker: isDecisionMaker,
      notes: notes,
      nextFollowupDate: nextFollowupDate,
      syncCreatedAt: now,
      syncUpdatedAt: now,
      isDeleted: false,
    );

    await db.insert('contacts', contact.toMap());

    await _auditRepo.log(
      userId: currentSession.userId,
      action: 'crm.contact.create',
      entityType: 'contact',
      entityId: id,
      newValue: contact.fullName,
    );

    return contact;
  }

  Future<ContactModel> update(ContactModel contact) async {
    requirePermission('crm.edit');
    final db = await database;

    final updated = contact.copyWith(syncUpdatedAt: DateTime.now().toUtc());
    await db.update(
      'contacts',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );

    await _auditRepo.log(
      userId: currentSession.userId,
      action: 'crm.contact.update',
      entityType: 'contact',
      entityId: contact.id,
    );

    return updated;
  }

  Future<void> softDelete(String id) async {
    requirePermission('crm.delete');
    final db = await database;
    final nowStr = DateTime.now().toUtc().toIso8601String();

    await db.update(
      'contacts',
      {'IsDeleted': 1, 'DeletedAt': nowStr, 'SyncUpdatedAt': nowStr},
      where: 'id = ?',
      whereArgs: [id],
    );

    await _auditRepo.log(
      userId: currentSession.userId,
      action: 'crm.contact.delete',
      entityType: 'contact',
      entityId: id,
    );
  }

  Future<ContactModel?> getById(String id) async {
    requirePermission('crm.view');
    final db = await database;
    final rows = await db.query(
      'contacts',
      where: 'id = ? AND IsDeleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ContactModel.fromMap(rows.first);
  }

  Future<List<ContactModel>> getByOrganization(String organizationId) async {
    requirePermission('crm.view');
    final db = await database;
    final rows = await db.query(
      'contacts',
      where: 'organization_id = ? AND IsDeleted = 0',
      whereArgs: [organizationId],
      orderBy: 'last_name ASC, first_name ASC',
    );
    return rows.map(ContactModel.fromMap).toList();
  }

  /// Global search across all contacts by name, phone, email.
  Future<List<ContactModel>> search(String query) async {
    requirePermission('crm.view');
    final db = await database;
    final q = '%${query.toLowerCase()}%';
    final rows = await db.rawQuery('''
      SELECT * FROM contacts
      WHERE IsDeleted = 0
        AND (LOWER(first_name || ' ' || last_name) LIKE ?
             OR LOWER(phone) LIKE ?
             OR LOWER(email) LIKE ?)
      ORDER BY last_name ASC
      LIMIT 50
    ''', [q, q, q]);
    return rows.map(ContactModel.fromMap).toList();
  }
}
