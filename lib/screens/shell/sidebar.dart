import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class AppSidebar extends StatelessWidget {
  final String currentRoute;
  final ValueChanged<String> onRouteSelected;

  const AppSidebar({
    super.key,
    required this.currentRoute,
    required this.onRouteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    Widget item(String title, IconData icon, {String? requiredPerm}) {
      if (requiredPerm != null && !auth.hasPermission(requiredPerm)) {
        return const SizedBox.shrink();
      }
      final isSelected = currentRoute == title;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        child: InkWell(
          onTap: () => onRouteSelected(title),
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.navyLight.withValues(alpha: 0.6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accent.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: isSelected ? Colors.white : AppColors.sidebarText,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected ? Colors.white : AppColors.sidebarText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    Widget section(String title) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 16, 4),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.sidebarSection,
            letterSpacing: 1.4,
          ),
        ),
      );
    }

    final username = auth.currentSession?.username ?? '';
    final roleName = auth.currentSession?.roleName ?? '';
    final initials = username.isNotEmpty ? username[0].toUpperCase() : 'A';

    return Container(
      width: 232,
      color: AppColors.navyDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── User profile block ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        roleName,
                        style: const TextStyle(
                          color: AppColors.sidebarText,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Navigation ─────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              children: [
                item('Dashboard', Icons.grid_view_rounded),

                section('CRM'),
                item('Leads', Icons.view_kanban_rounded),
                item('Clients', Icons.business_rounded),
                item('Contacts', Icons.people_rounded),

                section('RECOVERY'),
                item('Cases', Icons.folder_special_rounded),
                item(
                  'Batches',
                  Icons.inventory_2_rounded,
                  requiredPerm: 'assignment.view',
                ),
                item('Debtors', Icons.person_search_rounded),
                item(
                  'Payments',
                  Icons.payments_rounded,
                  requiredPerm: 'payment.view',
                ),
                item('Promises', Icons.handshake_rounded),

                section('WORK'),
                item('Tasks', Icons.task_alt_rounded),
                item('Activities', Icons.local_activity_rounded),
                item('Calendar', Icons.calendar_month_rounded),

                section('PERFORMANCE'),
                item(
                  'Performance Center',
                  Icons.speed_rounded,
                  requiredPerm: 'kpi.view',
                ),
                item(
                  'Employee Performance',
                  Icons.person_pin_circle_rounded,
                  requiredPerm: 'kpi.view',
                ),
                item(
                  'Team Performance',
                  Icons.groups_rounded,
                  requiredPerm: 'kpi.view',
                ),

                section('RESOURCES'),
                item(
                  'Documents',
                  Icons.description_rounded,
                  requiredPerm: 'document.view',
                ),
                item(
                  'Reports',
                  Icons.bar_chart_rounded,
                  requiredPerm: 'report.export',
                ),

                section('ORGANIZATION'),
                item(
                  'Employees',
                  Icons.badge_rounded,
                  requiredPerm: 'user.view',
                ),
                item(
                  'Teams',
                  Icons.group_work_rounded,
                  requiredPerm: 'user.view',
                ),

                section('ADMINISTRATION'),
                item(
                  'Users',
                  Icons.manage_accounts_rounded,
                  requiredPerm: 'user.view',
                ),
                item('Roles', Icons.shield_rounded, requiredPerm: 'role.view'),
                item(
                  'Audit Log',
                  Icons.receipt_long_rounded,
                  requiredPerm: 'audit.view',
                ),
                item(
                  'Network Setup',
                  Icons.hub_rounded,
                  requiredPerm: 'network.manage',
                ),
                item(
                  'Settings',
                  Icons.settings_rounded,
                  requiredPerm: 'settings.edit',
                ),
              ],
            ),
          ),

          // ── Logout ─────────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: InkWell(
                onTap: () => auth.logout(),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.logout_rounded,
                        size: 17,
                        color: Color(0xFFEF9A9A),
                      ),
                      SizedBox(width: 11),
                      Text(
                        'Logout',
                        style: TextStyle(
                          color: Color(0xFFEF9A9A),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
