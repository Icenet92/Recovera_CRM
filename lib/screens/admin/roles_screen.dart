import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repositories/user_repository.dart';
import '../../theme/app_theme.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _allPermissions = [];
  Map<String, Set<String>> _rolePermissions =
      {}; // roleId -> Set of permission codes

  String? _selectedRoleId;
  bool _loading = true;
  String? _error;
  bool _saving = false;

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

      // Load all roles and all permissions
      final roles = await repo.getAllRoles();
      final permissions = await repo.getAllPermissions();

      // Load permissions per role
      final Map<String, Set<String>> rp = {};
      for (var r in roles) {
        rp[r['id']] = await repo.getPermissionsForRole(r['id']);
      }

      setState(() {
        _roles = roles;
        _allPermissions = permissions;
        _rolePermissions = rp;
        _loading = false;
        if (_roles.isNotEmpty && _selectedRoleId == null) {
          _selectedRoleId = _roles.first['id'];
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveRolePermissions() async {
    if (_selectedRoleId == null) return;
    final isSuperAdmin =
        _roles.firstWhere((r) => r['id'] == _selectedRoleId)['name'] ==
        'Super Administrator';
    if (isSuperAdmin) return; // Super admin permissions shouldn't be edited

    setState(() => _saving = true);
    try {
      final repo = context.read<UserRepository>();
      await repo.updateRolePermissions(
        _selectedRoleId!,
        _rolePermissions[_selectedRoleId]!.toList(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(
          'Error: $_error',
          style: const TextStyle(color: AppColors.statusRed),
        ),
      );
    }

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Roles & Permissions',
                style: AppTypography.pageTitle(context),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage access control matrices for all system roles',
                style: AppTypography.labelSmall(context),
              ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Roles List (Sidebar)
              Container(
                width: 250,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: AppColors.border)),
                ),
                child: ListView.builder(
                  itemCount: _roles.length,
                  itemBuilder: (context, i) {
                    final r = _roles[i];
                    final isSelected = _selectedRoleId == r['id'];
                    return ListTile(
                      title: Text(
                        r['name'],
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.textBody,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: AppColors.accentBg,
                      onTap: () => setState(() => _selectedRoleId = r['id']),
                    );
                  },
                ),
              ),

              // Permissions Matrix (Main)
              Expanded(
                child: _selectedRoleId == null
                    ? const Center(child: Text('Select a role'))
                    : _buildPermissionEditor(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionEditor() {
    final role = _roles.firstWhere((r) => r['id'] == _selectedRoleId);
    final isSuperAdmin = role['name'] == 'Super Administrator';
    final perms = _rolePermissions[_selectedRoleId!] ?? {};

    // Group permissions by category
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var p in _allPermissions) {
      final cat = p['category'] as String;
      grouped.putIfAbsent(cat, () => []).add(p);
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          color: AppColors.bgPage,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                role['name'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!isSuperAdmin)
                FilledButton.icon(
                  onPressed: _saving ? null : _saveRolePermissions,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 16),
                  label: const Text('Save Changes'),
                ),
            ],
          ),
        ),
        if (isSuperAdmin)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.statusBlueBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.statusBlue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Super Administrator bypasses all permission checks automatically. This view shows explicitly seeded permissions, but editing is disabled as this role has implicit full access.',
                    style: TextStyle(color: AppColors.statusBlue),
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: grouped.length,
            itemBuilder: (context, i) {
              final cat = grouped.keys.elementAt(i);
              final items = grouped[cat]!;
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: items.map((p) {
                          final code = p['code'] as String;
                          final hasPerm = perms.contains(code);
                          return FilterChip(
                            label: Text(
                              p['name'],
                              style: TextStyle(
                                color: hasPerm
                                    ? AppColors.navy
                                    : AppColors.textBody,
                                fontWeight: hasPerm
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                            selected: hasPerm,
                            showCheckmark: true,
                            checkmarkColor: AppColors.navy,
                            selectedColor: AppColors.accent.withValues(
                              alpha: 0.15,
                            ),
                            backgroundColor: AppColors.bgPage,
                            side: BorderSide(
                              color: hasPerm
                                  ? AppColors.accent.withValues(alpha: 0.5)
                                  : AppColors.borderMid,
                            ),
                            onSelected: isSuperAdmin
                                ? null
                                : (selected) {
                                    setState(() {
                                      if (selected) {
                                        perms.add(code);
                                      } else {
                                        perms.remove(code);
                                      }
                                    });
                                  },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
