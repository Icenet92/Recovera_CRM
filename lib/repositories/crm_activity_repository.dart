import 'package:uuid/uuid.dart';
import 'base_repository.dart';
import '../models/crm_activity_model.dart';

class CrmActivityRepository extends BaseRepository {
  CrmActivityRepository(super.dbHelper);

  /// Log a new activity. Called automatically by any action touching a lead/contact/org.
  Future<CrmActivityModel> log({
    required String activityType,
    required String subject,
    String? description,
    String? outcome,
    String? contactId,
    String? leadId,
    String? organizationId,
    DateTime? activityDate,
  }) async {
    requirePermission('crm.view'); // any CRM-visible user can log activities
    final db = await database;

    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();
    final date = activityDate ?? now;

    final activity = CrmActivityModel(
      id: id,
      activityType: activityType,
      subject: subject,
      description: description,
      outcome: outcome,
      contactId: contactId,
      leadId: leadId,
      organizationId: organizationId,
      loggedByEmployeeId: currentSession.userId,
      activityDate: date,
      syncCreatedAt: now,
      syncUpdatedAt: now,
      isDeleted: false,
    );

    await db.insert('crm_activities', activity.toMap());
    return activity;
  }

  /// Get all activities for an organization (including those on its contacts/leads).
  Future<List<CrmActivityModel>> getForOrganization(String orgId) async {
    requirePermission('crm.view');
    final db = await database;

    // Collect contact IDs for this org
    final contactRows = await db.query(
      'contacts',
      columns: ['id'],
      where: 'organization_id = ? AND IsDeleted = 0',
      whereArgs: [orgId],
    );
    final contactIds = contactRows.map((r) => r['id'] as String).toList();

    // Build placeholders
    final contactPlaceholders =
        contactIds.isEmpty ? '' : contactIds.map((_) => '?').join(',');

    String sql;
    List<dynamic> args;

    if (contactIds.isEmpty) {
      sql = '''
        SELECT a.*,
               (e.first_name || ' ' || e.last_name) AS logged_by_name
        FROM crm_activities a
        LEFT JOIN employees e ON e.id = a.logged_by_employee_id
        WHERE a.IsDeleted = 0
          AND (a.organization_id = ?)
        ORDER BY a.activity_date DESC
      ''';
      args = [orgId];
    } else {
      sql = '''
        SELECT a.*,
               (e.first_name || ' ' || e.last_name) AS logged_by_name
        FROM crm_activities a
        LEFT JOIN employees e ON e.id = a.logged_by_employee_id
        WHERE a.IsDeleted = 0
          AND (a.organization_id = ?
               OR a.contact_id IN ($contactPlaceholders))
        ORDER BY a.activity_date DESC
      ''';
      args = [orgId, ...contactIds];
    }

    final rows = await db.rawQuery(sql, args);
    return rows.map(CrmActivityModel.fromMap).toList();
  }

  Future<List<CrmActivityModel>> getForContact(String contactId) async {
    requirePermission('crm.view');
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT a.*,
             (e.first_name || ' ' || e.last_name) AS logged_by_name
      FROM crm_activities a
      LEFT JOIN employees e ON e.id = a.logged_by_employee_id
      WHERE a.IsDeleted = 0 AND a.contact_id = ?
      ORDER BY a.activity_date DESC
    ''', [contactId]);
    return rows.map(CrmActivityModel.fromMap).toList();
  }

  Future<List<CrmActivityModel>> getForLead(String leadId) async {
    requirePermission('crm.view');
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT a.*,
             (e.first_name || ' ' || e.last_name) AS logged_by_name
      FROM crm_activities a
      LEFT JOIN employees e ON e.id = a.logged_by_employee_id
      WHERE a.IsDeleted = 0 AND a.lead_id = ?
      ORDER BY a.activity_date DESC
    ''', [leadId]);
    return rows.map(CrmActivityModel.fromMap).toList();
  }
}
