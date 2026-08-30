import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repositories/user_repository.dart';
import '../../theme/app_theme.dart';

// ─── Users Screen ─────────────────────────────────────────────────────────────

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _roles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<UserRepository>();
      final rawUsers = await _fetchUsersWithDetails(repo);
      final roles = await repo.getAllRoles();
      setState(() {
        _users = rawUsers;
        _roles = roles;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUsersWithDetails(
    UserRepository repo,
  ) async {
    final db = await repo.database;
    final rows = await db.rawQuery('''
      SELECT u.id, u.username, u.is_active, u.last_login,
             e.first_name, e.last_name, e.email, e.job_title,
             r.name as role_name
      FROM users u
      LEFT JOIN employees e ON u.employee_id = e.id
      LEFT JOIN roles r ON u.role_id = r.id
      WHERE u.IsDeleted = 0
      ORDER BY u.username ASC
    ''');
    return rows.cast<Map<String, dynamic>>();
  }

  void _openCreate() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateUserDialog(roles: _roles),
    );
    if (created == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Users', style: AppTypography.pageTitle(context)),
                  const SizedBox(height: 4),
                  Text(
                    'Manage user accounts and employee profiles',
                    style: AppTypography.labelSmall(context),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: _openCreate,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('New User'),
              ),
            ],
          ),
        ),

        // Error banner
        if (_error != null)
          Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.statusRedBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.statusRed),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.statusRed),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() => _error = null),
                ),
              ],
            ),
          ),

        // Table
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.manage_accounts,
                        size: 64,
                        color: AppColors.border,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No users found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHead,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _openCreate,
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Create First User'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingTextStyle: AppTypography.tableHeader(context),
                      columns: const [
                        DataColumn(label: Text('NAME')),
                        DataColumn(label: Text('USERNAME')),
                        DataColumn(label: Text('ROLE')),
                        DataColumn(label: Text('JOB TITLE')),
                        DataColumn(label: Text('STATUS')),
                        DataColumn(label: Text('LAST LOGIN')),
                      ],
                      rows: _users.map((u) {
                        final fullName =
                            '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'
                                .trim();
                        final isActive = (u['is_active'] as int?) == 1;
                        final lastLogin = u['last_login'] as String?;
                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  _Avatar(
                                    name: fullName.isEmpty
                                        ? (u['username'] as String)
                                        : fullName,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    fullName.isEmpty ? '—' : fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(Text(u['username'] as String? ?? '')),
                            DataCell(Text(u['role_name'] as String? ?? '—')),
                            DataCell(Text(u['job_title'] as String? ?? '—')),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.statusGreenBg
                                      : AppColors.statusGrayBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isActive ? 'ACTIVE' : 'DISABLED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isActive
                                        ? AppColors.statusGreen
                                        : AppColors.statusGray,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                lastLogin != null
                                    ? DateTime.parse(lastLogin)
                                          .toLocal()
                                          .toIso8601String()
                                          .split('T')
                                          .first
                                    : 'Never',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Avatar helper ─────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.accentBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
      ),
    );
  }
}

// ─── Create User Dialog ────────────────────────────────────────────────────────

class CreateUserDialog extends StatefulWidget {
  final List<Map<String, dynamic>> roles;
  const CreateUserDialog({super.key, required this.roles});

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _jobTitleCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String? _selectedRoleId;
  bool _obscurePass = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.roles.isNotEmpty) {
      _selectedRoleId = widget.roles.first['id'] as String;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _jobTitleCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoleId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a role.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = context.read<UserRepository>();
      await repo.createEmployeeAndUser(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        jobTitle: _jobTitleCtrl.text.trim().isEmpty
            ? null
            : _jobTitleCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        plainPassword: _passwordCtrl.text,
        roleId: _selectedRoleId!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User created successfully.')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 640,
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create User Account',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHead,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Creates both an employee profile and a linked login account in one step.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 28),

              // ── Employee Details ──────────────────────────────────────────
              const Text(
                'EMPLOYEE DETAILS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _field('First Name', _firstNameCtrl, required: true),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _field('Last Name', _lastNameCtrl, required: true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      'Email',
                      _emailCtrl,
                      hint: 'name@company.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _field('Phone', _phoneCtrl, hint: '+250...')),
                ],
              ),
              const SizedBox(height: 12),
              _field('Job Title', _jobTitleCtrl, hint: 'e.g. Recovery Officer'),
              const SizedBox(height: 24),

              // ── Account Details ───────────────────────────────────────────
              const Text(
                'ACCOUNT DETAILS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _field(
                      'Username',
                      _usernameCtrl,
                      required: true,
                      hint: 'Must be unique',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Role',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRoleId,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          items: widget.roles
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r['id'] as String,
                                  child: Text(
                                    r['name'] as String,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _selectedRoleId = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _passwordField(
                      'Password',
                      _passwordCtrl,
                      required: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _confirmField()),
                ],
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create User'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool required = false,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint),
          validator: required
              ? (v) => v!.trim().isEmpty ? 'Required' : null
              : null,
        ),
      ],
    );
  }

  Widget _passwordField(
    String label,
    TextEditingController ctrl, {
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          obscureText: _obscurePass,
          decoration: InputDecoration(
            hintText: 'Min 8 characters',
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePass ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
          validator: required
              ? (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 8) return 'Min 8 characters';
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _confirmField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confirm Password',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: _confirmCtrl,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Re-enter password'),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            if (v != _passwordCtrl.text) return 'Passwords do not match';
            return null;
          },
        ),
      ],
    );
  }
}
