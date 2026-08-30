import 'package:uuid/uuid.dart';
import '../models/debtor_model.dart';
import 'base_repository.dart';

class DebtorRepository extends BaseRepository {
  DebtorRepository(super.db);

  /// Gets all debtors, applying sensitive data masking if the user lacks the `debtor.sensitive` permission.
  Future<List<DebtorModel>> getAll() async {
    requirePermission('debtor.view');
    final canViewSensitive = currentSession.hasPermission('debtor.sensitive');

    final results = await (await database).query(
      'debtors',
      where: 'IsDeleted = ?',
      whereArgs: [0],
    );

    return results.map((map) {
      final debtor = DebtorModel.fromMap(map);
      if (!canViewSensitive) {
        return debtor.copyWith(
          phone: debtor.phone != null ? '***-***-****' : null,
          email: debtor.email != null ? '***@***.***' : null,
          employerBusiness: debtor.employerBusiness != null
              ? '*** HIDDEN ***'
              : null,
        );
      }
      return debtor;
    }).toList();
  }

  /// Gets debtors belonging to a specific client (organization).
  Future<List<DebtorModel>> getByClientId(String clientId) async {
    requirePermission('debtor.view');
    final canViewSensitive = currentSession.hasPermission('debtor.sensitive');

    final results = await (await database).query(
      'debtors',
      where: 'client_id = ? AND IsDeleted = ?',
      whereArgs: [clientId, 0],
      orderBy: 'name ASC',
    );

    return results.map((map) {
      final debtor = DebtorModel.fromMap(map);
      if (!canViewSensitive) {
        return debtor.copyWith(
          phone: debtor.phone != null ? '***-***-****' : null,
          email: debtor.email != null ? '***@***.***' : null,
          employerBusiness: debtor.employerBusiness != null
              ? '*** HIDDEN ***'
              : null,
        );
      }
      return debtor;
    }).toList();
  }

  Future<DebtorModel?> getById(String id) async {
    requirePermission('debtor.view');
    final canViewSensitive = currentSession.hasPermission('debtor.sensitive');

    final results = await (await database).query(
      'debtors',
      where: 'id = ? AND IsDeleted = ?',
      whereArgs: [id, 0],
    );
    if (results.isEmpty) return null;

    final debtor = DebtorModel.fromMap(results.first);
    if (!canViewSensitive) {
      return debtor.copyWith(
        phone: debtor.phone != null ? '***-***-****' : null,
        email: debtor.email != null ? '***@***.***' : null,
        employerBusiness: debtor.employerBusiness != null
            ? '*** HIDDEN ***'
            : null,
      );
    }
    return debtor;
  }

  Future<void> create(DebtorModel debtor) async {
    requirePermission('debtor.edit');
    if (debtor.clientId.isEmpty) {
      throw Exception('Debtor must be assigned to a client.');
    }
    final now = DateTime.now().toUtc().toIso8601String();

    await (await database).insert('debtors', {
      ...debtor.toMap(),
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });

    // Log creation
    await (await database).insert('audit_logs', {
      'id': const Uuid().v4(),
      'user_id': currentSession.userId,
      'action': 'debtor.create',
      'entity_type': 'debtors',
      'entity_id': debtor.id,
      'new_value': debtor.name,
      'timestamp': now,
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });
  }

  Future<void> update(DebtorModel debtor) async {
    requirePermission('debtor.edit');
    final now = DateTime.now().toUtc().toIso8601String();

    await (await database).update(
      'debtors',
      {...debtor.toMap(), 'SyncUpdatedAt': now},
      where: 'id = ?',
      whereArgs: [debtor.id],
    );

    await (await database).insert('audit_logs', {
      'id': const Uuid().v4(),
      'user_id': currentSession.userId,
      'action': 'debtor.update',
      'entity_type': 'debtors',
      'entity_id': debtor.id,
      'new_value': debtor.name,
      'timestamp': now,
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });
  }

  Future<List<DebtorModel>> search(String query) async {
    requirePermission('debtor.view');
    final canViewSensitive = currentSession.hasPermission('debtor.sensitive');

    final q = '%$query%';
    final results = await (await database).query(
      'debtors',
      where:
          'IsDeleted = ? AND (name LIKE ? OR phone LIKE ? OR email LIKE ? OR employer_business LIKE ?)',
      whereArgs: [0, q, q, q, q],
    );

    return results.map((map) {
      final debtor = DebtorModel.fromMap(map);
      if (!canViewSensitive) {
        return debtor.copyWith(
          phone: debtor.phone != null ? '***-***-****' : null,
          email: debtor.email != null ? '***@***.***' : null,
          employerBusiness: debtor.employerBusiness != null
              ? '*** HIDDEN ***'
              : null,
        );
      }
      return debtor;
    }).toList();
  }
}
