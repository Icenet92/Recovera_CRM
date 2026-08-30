import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'theme/app_theme.dart';

import 'database/database_helper.dart';
import 'repositories/audit_repository.dart';
import 'repositories/user_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/organization_repository.dart';
import 'repositories/contact_repository.dart';
import 'repositories/lead_repository.dart';
import 'repositories/crm_activity_repository.dart';
import 'sync/lan_sync_adapter.dart';
import 'providers/auth_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/crm_provider.dart';

import 'repositories/debtor_repository.dart';
import 'repositories/case_repository.dart';
import 'providers/recovery_provider.dart';

import 'screens/login_screen.dart';
import 'screens/shell/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Database
  final dbHelper = DatabaseHelper.instance;

  // Initialize Repositories
  final auditRepo = AuditRepository(dbHelper);
  final userRepo = UserRepository(dbHelper, auditRepo);
  final orgRepo = OrganizationRepository(dbHelper, auditRepo);
  final contactRepo = ContactRepository(dbHelper, auditRepo);
  final leadRepo = LeadRepository(dbHelper, auditRepo);
  final crmActivityRepo = CrmActivityRepository(dbHelper);
  final debtorRepo = DebtorRepository(dbHelper);
  final caseRepo = CaseRepository(dbHelper);

  final authRepo = AuthRepository(
    userRepo,
    auditRepo,
    additionalRepos: [
      orgRepo,
      contactRepo,
      leadRepo,
      crmActivityRepo,
      debtorRepo,
      caseRepo,
    ],
  );

  // Initialize Sync
  final syncAdapter = LanSyncAdapter(dbHelper);
  // We mock the device ID for now, in a real app use device_info_plus or similar
  await syncAdapter.initialize(
    deviceId: 'DEVICE-1234',
    deviceName: 'Windows Desktop',
  );

  runApp(
    MultiProvider(
      providers: [
        // Repositories that screens access directly
        Provider<UserRepository>.value(value: userRepo),
        // State providers
        ChangeNotifierProvider(create: (_) => AuthProvider(authRepo)),
        ChangeNotifierProvider(create: (_) => SyncProvider(syncAdapter)),
        ChangeNotifierProvider(
          create: (_) =>
              CrmProvider(orgRepo, contactRepo, leadRepo, crmActivityRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => RecoveryProvider(caseRepo, debtorRepo),
        ),
      ],
      child: const RecoveraApp(),
    ),
  );

  doWhenWindowReady(() {
    const initialSize = Size(1280, 800);
    appWindow.minSize = const Size(1024, 768);
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.show();
  });
}

class RecoveraApp extends StatelessWidget {
  const RecoveraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recovera CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return auth.isLoggedIn ? const AppShell() : const LoginScreen();
        },
      ),
    );
  }
}
