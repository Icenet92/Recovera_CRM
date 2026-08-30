import 'user_repository.dart';
import 'audit_repository.dart';
import '../models/auth_session.dart';
import '../services/auth_service.dart';
import 'base_repository.dart';

class AuthRepository {
  final UserRepository _userRepo;
  final AuditRepository _auditRepo;
  final List<BaseRepository> _allRepos;
  AuthSession? _currentSession;

  AuthRepository(
    this._userRepo,
    this._auditRepo, {
    List<BaseRepository> additionalRepos = const [],
  }) : _allRepos = [_userRepo, _auditRepo, ...additionalRepos];

  AuthSession? get currentSession => _currentSession;
  bool get isLoggedIn => _currentSession != null;

  Future<AuthSession> login(String username, String password) async {
    final user = await _userRepo.getUserByUsernameInternal(username);
    if (user == null) {
      throw Exception('Invalid credentials');
    }

    if (!user.isActive) {
      throw Exception('Account is disabled. Contact your administrator.');
    }

    final isValid = AuthService.verifyPassword(
      password,
      user.passwordHash,
      user.passwordSalt,
    );
    if (!isValid) {
      throw Exception('Invalid credentials');
    }

    final permissions = await _userRepo.getPermissionsForRole(user.roleId);
    final roleName =
        await _userRepo.getRoleNameForUser(user.roleId) ?? 'Unknown Role';
    final now = DateTime.now().toUtc();

    final db = await _userRepo.database;
    await db.update(
      'users',
      {
        'last_login': now.toIso8601String(),
        'SyncUpdatedAt': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [user.id],
    );

    _currentSession = AuthSession(
      userId: user.id,
      username: user.username,
      roleId: user.roleId,
      roleName: roleName,
      permissions: permissions,
      loginTime: now,
      isSuperAdmin: roleName == 'Super Administrator',
    );

    for (final repo in _allRepos) {
      repo.setSession(_currentSession);
    }

    await _auditRepo.log(userId: user.id, action: 'login');

    return _currentSession!;
  }

  Future<void> logout() async {
    if (_currentSession != null) {
      await _auditRepo.log(userId: _currentSession!.userId, action: 'logout');
      _currentSession = null;
      for (final repo in _allRepos) {
        repo.setSession(null);
      }
    }
  }
}
