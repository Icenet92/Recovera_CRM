import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/auth_service.dart';
import 'schema.dart';
import 'seeds.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  /// When non-null, the DB is opened at [_dbPath] instead of the user's
  /// documents directory. Used by tests so they don't depend on the
  /// `path_provider` platform channel (unavailable in a plain `flutter test`).
  final String? _dbPath;

  /// Instance-level cache so each [DatabaseHelper] (including test instances
  /// created via [DatabaseHelper.withPath]) owns its own connection.
  Database? _database;

  DatabaseHelper._init() : _dbPath = null;

  /// Test-only constructor: opens the DB file inside directory [dbPath].
  DatabaseHelper.withPath(String dbPath) : _dbPath = dbPath;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<String> _resolvePath() async {
    final override = _dbPath;
    if (override != null) {
      final path = join(override, 'recovera.db');
      final dir = Directory(dirname(path));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return path;
    }

    final docsPath = await getApplicationDocumentsDirectory();
    final path = join(docsPath.path, 'recovera_crm', 'recovera.db');

    // Ensure directory exists
    final dir = Directory(dirname(path));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final path = await _resolvePath();

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, version) async {
          await _createTables(db);
          await _seedData(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 4) {
            // Phase 3: Add Cases and Debtors tables
            await db.execute('''
              CREATE TABLE IF NOT EXISTS debtors (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                type TEXT NOT NULL,
                phone TEXT,
                email TEXT,
                address TEXT,
                employer_business TEXT,
                notes TEXT,
                SyncCreatedAt TEXT NOT NULL,
                SyncUpdatedAt TEXT NOT NULL,
                IsDeleted INTEGER NOT NULL DEFAULT 0,
                DeletedAt TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS cases (
                id TEXT PRIMARY KEY,
                case_number TEXT UNIQUE NOT NULL,
                organization_id TEXT NOT NULL,
                debtor_id TEXT NOT NULL,
                client_reference TEXT,
                title TEXT NOT NULL,
                case_type TEXT,
                description TEXT,
                priority TEXT NOT NULL DEFAULT 'Medium',
                status TEXT NOT NULL DEFAULT 'Open',
                primary_owner_id TEXT,
                supervisor_id TEXT,
                date_received TEXT,
                deadline TEXT,
                date_closed TEXT,
                principal REAL NOT NULL DEFAULT 0,
                interest REAL NOT NULL DEFAULT 0,
                penalties REAL NOT NULL DEFAULT 0,
                fees REAL NOT NULL DEFAULT 0,
                total_claim REAL NOT NULL DEFAULT 0,
                difficulty TEXT NOT NULL DEFAULT 'Medium',
                SyncCreatedAt TEXT NOT NULL,
                SyncUpdatedAt TEXT NOT NULL,
                IsDeleted INTEGER NOT NULL DEFAULT 0,
                DeletedAt TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS case_types (
                id TEXT PRIMARY KEY,
                name TEXT UNIQUE NOT NULL,
                description TEXT,
                SyncCreatedAt TEXT NOT NULL,
                SyncUpdatedAt TEXT NOT NULL,
                IsDeleted INTEGER NOT NULL DEFAULT 0,
                DeletedAt TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS case_statuses (
                id TEXT PRIMARY KEY,
                name TEXT UNIQUE NOT NULL,
                description TEXT,
                is_closed INTEGER NOT NULL DEFAULT 0,
                SyncCreatedAt TEXT NOT NULL,
                SyncUpdatedAt TEXT NOT NULL,
                IsDeleted INTEGER NOT NULL DEFAULT 0,
                DeletedAt TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS case_assignments (
                id TEXT PRIMARY KEY,
                case_id TEXT NOT NULL,
                assigned_by_employee_id TEXT NOT NULL,
                assigned_to_employee_id TEXT NOT NULL,
                supervisor_id TEXT,
                assignment_date TEXT NOT NULL,
                reason TEXT,
                SyncCreatedAt TEXT NOT NULL,
                SyncUpdatedAt TEXT NOT NULL,
                IsDeleted INTEGER NOT NULL DEFAULT 0,
                DeletedAt TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS case_status_history (
                id TEXT PRIMARY KEY,
                case_id TEXT NOT NULL,
                changed_by_employee_id TEXT NOT NULL,
                old_status TEXT,
                new_status TEXT NOT NULL,
                change_date TEXT NOT NULL,
                reason TEXT,
                SyncCreatedAt TEXT NOT NULL,
                SyncUpdatedAt TEXT NOT NULL,
                IsDeleted INTEGER NOT NULL DEFAULT 0,
                DeletedAt TEXT
              )
            ''');

            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_debtors_client_id ON debtors(client_id)',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_cases_organization_id ON cases(organization_id)',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_cases_debtor_id ON cases(debtor_id)',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_cases_primary_owner_id ON cases(primary_owner_id)',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_cases_status ON cases(status)',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_case_assignments_case_id ON case_assignments(case_id)',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_case_status_history_case_id ON case_status_history(case_id)',
            );

            // Re-run seed to ensure permissions exist.
            await _seedData(db);
          }
          if (oldVersion < 5) {
            // Phase 3 patch: Add supporting employees junction table
            await db.execute('''
              CREATE TABLE IF NOT EXISTS case_supporting_employees (
                id TEXT PRIMARY KEY,
                case_id TEXT NOT NULL,
                employee_id TEXT NOT NULL,
                added_by_employee_id TEXT NOT NULL,
                added_date TEXT NOT NULL,
                SyncCreatedAt TEXT NOT NULL,
                SyncUpdatedAt TEXT NOT NULL,
                IsDeleted INTEGER NOT NULL DEFAULT 0,
                DeletedAt TEXT
              )
            ''');
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_case_supporting_employees_case_id ON case_supporting_employees(case_id)',
            );
          }
          if (oldVersion < 6) {
            final oldUsers = await db.query(
              'users',
              where: 'password_salt = ?',
              whereArgs: ['seed_salt_recovera'],
            );
            if (oldUsers.isNotEmpty) {
              final salt = AuthService.generateSalt();
              final hash = AuthService.hashPassword('Admin@1234', salt);
              await db.update(
                'users',
                {'password_salt': salt, 'password_hash': hash},
                where: 'password_salt = ?',
                whereArgs: ['seed_salt_recovera'],
              );
            }
          }
          if (oldVersion < 7) {
            // Phase 3b: Add client_id to debtors and backfill from existing cases
            await db.execute('ALTER TABLE debtors ADD COLUMN client_id TEXT');
            // Backfill: set client_id from the case that references this debtor
            await db.rawUpdate('''
              UPDATE debtors
              SET client_id = (
                SELECT organization_id FROM cases
                WHERE cases.debtor_id = debtors.id AND cases.IsDeleted = 0
                LIMIT 1
              )
              WHERE client_id IS NULL OR client_id = ''
            ''');
            // Drop and recreate as NOT NULL (SQLite doesn't support ALTER COLUMN, so we rebuild)
            // For existing installs, the backfilled data is sufficient; NOT NULL enforced at app layer
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_debtors_client_id ON debtors(client_id)',
            );
          }
          if (oldVersion < 8) {
            // Phase 3B: Recovery Assignments (Case Pools)
            await db.execute('''
              CREATE TABLE IF NOT EXISTS recovery_assignments (
                id TEXT PRIMARY KEY,
                assigned_employee_id TEXT NOT NULL,
                assigned_by TEXT NOT NULL,
                target_amount REAL NOT NULL,
                start_date TEXT NOT NULL,
                deadline_date TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'Active',
                notes TEXT,
                SyncCreatedAt TEXT NOT NULL,
                SyncUpdatedAt TEXT NOT NULL,
                IsDeleted INTEGER NOT NULL DEFAULT 0,
                DeletedAt TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS case_assignment_batch_history (
                id TEXT PRIMARY KEY,
                recovery_assignment_id TEXT NOT NULL,
                case_id TEXT NOT NULL,
                added_date TEXT NOT NULL,
                removed_date TEXT,
                SyncCreatedAt TEXT NOT NULL,
                SyncUpdatedAt TEXT NOT NULL,
                IsDeleted INTEGER NOT NULL DEFAULT 0,
                DeletedAt TEXT
              )
            ''');
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_case_assignment_batch_history_assignment_id ON case_assignment_batch_history(recovery_assignment_id)',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_case_assignment_batch_history_case_id ON case_assignment_batch_history(case_id)',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_recovery_assignments_employee_id ON recovery_assignments(assigned_employee_id)',
            );
          }
        },
      ),
    );
  }

  Future<void> _createTables(Database db) async {
    await createAllTables(db);
  }

  Future<void> _seedData(Database db) async {
    await seedAll(db);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
