import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../../theme/app_theme.dart';
import 'sidebar.dart';
import '../network_setup_screen.dart';
import '../crm/clients_screen.dart';
import '../crm/leads_screen.dart';
import '../crm/contacts_screen.dart';
import '../recovery/batches_screen.dart';
import '../recovery/cases_screen.dart';
import '../recovery/case_detail_screen.dart';
import '../recovery/debtors_screen.dart';
import '../recovery/recovery_assignment_detail_screen.dart';
import '../recovery/debtor_detail_screen.dart';
import '../admin/users_screen.dart';
import '../admin/roles_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _currentRoute = 'Dashboard';
  String? _selectedCaseId;
  String? _selectedDebtorId;
  String? _selectedAssignmentId;

  Widget _buildBody() {
    if (_selectedAssignmentId != null) {
      return RecoveryAssignmentDetailScreen(
        assignmentId: _selectedAssignmentId!,
        onBack: () => setState(() => _selectedAssignmentId = null),
      );
    }

    if (_selectedCaseId != null) {
      return CaseDetailScreen(
        caseId: _selectedCaseId!,
        onBack: () => setState(() => _selectedCaseId = null),
      );
    }

    if (_selectedDebtorId != null) {
      return DebtorDetailScreen(
        debtorId: _selectedDebtorId!,
        onBack: () => setState(() => _selectedDebtorId = null),
      );
    }

    if (_currentRoute == 'Network Setup') {
      return const NetworkSetupScreen();
    } else if (_currentRoute == 'Clients') {
      return const ClientsScreen();
    } else if (_currentRoute == 'Leads') {
      return const LeadsScreen();
    } else if (_currentRoute == 'Contacts') {
      return const ContactsScreen();
    } else if (_currentRoute == 'Cases') {
      return CasesScreen(
        onCaseSelected: (id) => setState(() => _selectedCaseId = id),
        onAssignmentCreated: (id) =>
            setState(() => _selectedAssignmentId = id),
      );
    } else if (_currentRoute == 'Batches') {
      return BatchesScreen(
        onBatchSelected: (id) => setState(() => _selectedAssignmentId = id),
        onAssignmentCreated: (id) =>
            setState(() => _selectedAssignmentId = id),
      );
    } else if (_currentRoute == 'Debtors') {
      return DebtorsScreen(
        onDebtorSelected: (id) => setState(() => _selectedDebtorId = id),
      );
    } else if (_currentRoute == 'Users') {
      return const UsersScreen();
    } else if (_currentRoute == 'Roles') {
      return const RolesScreen();
    }
    return _PlaceholderScreen(route: _currentRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Custom title bar ───────────────────────────────────────────────
          WindowTitleBarBox(
            child: Container(
              color: AppColors.navyDark,
              child: Row(
                children: [
                  MoveWindow(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Center(
                              child: Text(
                                'R',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'RECOVERA CRM',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(child: MoveWindow()),
                  const _TitleBarButtons(),
                ],
              ),
            ),
          ),

          // ── Shell body: sidebar + content ──────────────────────────────────
          Expanded(
            child: Row(
              children: [
                AppSidebar(
                  currentRoute: _currentRoute,
                  onRouteSelected: (route) => setState(() {
                    _currentRoute = route;
                    _selectedCaseId = null;
                    _selectedDebtorId = null;
                    _selectedAssignmentId = null;
                  }),
                ),
                Expanded(
                  child: ColoredBox(
                    color: AppColors.bgPage,
                    child: _buildBody(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Placeholder for not-yet-built screens ──────────────────────────────────

class _PlaceholderScreen extends StatelessWidget {
  final String route;
  const _PlaceholderScreen({required this.route});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction_rounded, size: 72, color: AppColors.border),
          const SizedBox(height: 16),
          Text(
            route,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textHead,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This section is coming in a future phase.',
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Polished title-bar window buttons ──────────────────────────────────────

class _TitleBarButtons extends StatelessWidget {
  const _TitleBarButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MinimizeWindowButton(
          colors: WindowButtonColors(
            iconNormal: Colors.white60,
            iconMouseOver: Colors.white,
            mouseOver: AppColors.navyLight,
            mouseDown: AppColors.navy,
          ),
        ),
        MaximizeWindowButton(
          colors: WindowButtonColors(
            iconNormal: Colors.white60,
            iconMouseOver: Colors.white,
            mouseOver: AppColors.navyLight,
            mouseDown: AppColors.navy,
          ),
        ),
        CloseWindowButton(
          colors: WindowButtonColors(
            iconNormal: Colors.white60,
            iconMouseOver: Colors.white,
            mouseOver: const Color(0xFFE81123),
            mouseDown: const Color(0xFFC50F1F),
          ),
        ),
      ],
    );
  }
}
