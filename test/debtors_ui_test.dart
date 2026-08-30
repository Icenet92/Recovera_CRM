// Headless widget tests for the real Debtors feature.
//
// Why this test file looks the way it does:
// The screens call sqflite_common_ffi (real, background-thread SQLite) from
// addPostFrameCallback / gesture handlers as fire-and-forget Futures. Under
// `flutter test`'s FakeAsync zone those Futures never settle via a plain
// `pump()`, so we drain them with `tester.runAsync(...)` (a real event-loop
// window) and then `pump()` once to render. This mirrors the real runtime.
//
// Run:  flutter test test/debtors_ui_test.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:recovera_crm/database/database_helper.dart';
import 'package:recovera_crm/providers/auth_provider.dart';
import 'package:recovera_crm/providers/crm_provider.dart';
import 'package:recovera_crm/providers/recovery_provider.dart';
import 'package:recovera_crm/repositories/audit_repository.dart';
import 'package:recovera_crm/repositories/auth_repository.dart';
import 'package:recovera_crm/repositories/case_repository.dart';
import 'package:recovera_crm/repositories/contact_repository.dart';
import 'package:recovera_crm/repositories/recovery_assignment_repository.dart';
import 'package:recovera_crm/repositories/crm_activity_repository.dart';
import 'package:recovera_crm/repositories/debtor_repository.dart';
import 'package:recovera_crm/repositories/lead_repository.dart';
import 'package:recovera_crm/repositories/organization_repository.dart';
import 'package:recovera_crm/repositories/user_repository.dart';
import 'package:recovera_crm/screens/recovery/case_form_dialog.dart';
import 'package:recovera_crm/screens/recovery/debtor_detail_screen.dart';
import 'package:recovera_crm/screens/recovery/debtor_form_dialog.dart';
import 'package:recovera_crm/screens/recovery/debtors_screen.dart';

void main() {
  // FFI factory, no platform channels -> usable from the plain test VM.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Captures the binding's FlutterError.onError so we can restore it.
  void Function(FlutterErrorDetails)? previousOnError;

  // Shared fixtures for every testWidget. Recreated in setUp so each test gets
  // a fresh on-disk DB and a fresh logged-in session.
  late Directory dir;
  late DatabaseHelper dbHelper;
  late AuditRepository auditRepo;
  late UserRepository userRepo;
  late OrganizationRepository orgRepo;
  late ContactRepository contactRepo;
  late LeadRepository leadRepo;
  late CrmActivityRepository crmActivityRepo;
  late DebtorRepository debtorRepo;
  late CaseRepository caseRepo;
  late RecoveryAssignmentRepository recoveryAssignmentRepo;
  late AuthRepository authRepo;

  setUp(() async {
    // Initialize the test binding NOW so it installs its (fatal) FlutterError
    // handler before we capture and downgrade it. RenderFlex overflow from the
    // screens' intrinsic dropdown sizing in a test viewport is cosmetic and
    // must not fail these tests; dump-only keeps real exceptions visible.
    TestWidgetsFlutterBinding.ensureInitialized();
    previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
    };

    dir = Directory.systemTemp.createTempSync('recovera_ui_test_');
    dbHelper = DatabaseHelper.withPath(dir.path);
    await dbHelper.database; // opens + runs the seed migrations

    auditRepo = AuditRepository(dbHelper);
    userRepo = UserRepository(dbHelper, auditRepo);
    orgRepo = OrganizationRepository(dbHelper, auditRepo);
    contactRepo = ContactRepository(dbHelper, auditRepo);
    leadRepo = LeadRepository(dbHelper, auditRepo);
    crmActivityRepo = CrmActivityRepository(dbHelper);
    debtorRepo = DebtorRepository(dbHelper);
    caseRepo = CaseRepository(dbHelper);
    recoveryAssignmentRepo = RecoveryAssignmentRepository(dbHelper);

    authRepo = AuthRepository(
      userRepo,
      auditRepo,
      additionalRepos: [
        orgRepo,
        contactRepo,
        leadRepo,
        crmActivityRepo,
        debtorRepo,
        caseRepo,
        recoveryAssignmentRepo,
      ],
    );
    final session = await authRepo.login('admin', 'Admin@1234');
    expect(session.username, 'admin');
  });

  tearDown(() async {
    FlutterError.onError = previousOnError;
    await dbHelper.close();
    await dir.delete(recursive: true);
  });

  /// Drain real FFI-backed Futures (sqflite_common_ffi runs on a background
  /// thread whose completion events are not delivered by FakeAsync pumps).
  /// `runAsync` opens a real event-loop window so those Futures complete.
  Future<void> drain(WidgetTester t, {int ms = 800}) async {
    await t.runAsync(() async {
      await Future.delayed(Duration(milliseconds: ms));
    });
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
  }

  /// `TestWidgetsFlutterBinding` (re)installs its fatal `FlutterError.onError`
  /// during `pumpWidget`/`init`. We call this AFTER pumpWidget, before the first
  /// pump, to downgrade cosmetic RenderFlex overflow (intrinsic dropdown sizing
  /// in a 1920 test viewport) to a printed warning so real exceptions stay fatal.
  void silenceLayoutOverflow() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
    };
  }

  /// Providers are created by the widget (create:) but wrap the external,
  /// already-logged-in repositories, so they share the seeded session + DB.
  Widget app(Widget child) {
    return MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider(authRepo)),
          ChangeNotifierProvider(
            create: (_) => RecoveryProvider(
              caseRepo,
              debtorRepo,
              recoveryAssignmentRepo,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                CrmProvider(orgRepo, contactRepo, leadRepo, crmActivityRepo),
          ),
        ],
        child: MaterialApp(home: child),
      ),
    );
  }

  /// A host that swaps between the Debtors list and the Debtor detail page,
  /// mirroring how AppShell wires the 'Debtors' route (_selectedDebtorId).
  Widget host() {
    String? selectedDebtorId;
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return Scaffold(
          body: selectedDebtorId == null
              ? DebtorsScreen(
                  onDebtorSelected: (id) =>
                      setState(() => selectedDebtorId = id),
                )
              : DebtorDetailScreen(
                  debtorId: selectedDebtorId!,
                  onBack: () => setState(() => selectedDebtorId = null),
                ),
        );
      },
    );
  }

  testWidgets('renders the list (placeholder gone) with client names', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(host()));
    silenceLayoutOverflow();
    // First frame fires DebtorsScreen.addPostFrameCallback (loadDebtors/CaseCounts/Orgs).
    await tester.pump();
    await drain(tester, ms: 900);

    // The placeholder text must NOT be present anywhere in the tree.
    expect(
      find.text('This section is coming in a future phase.'),
      findsNothing,
    );
    expect(find.byType(DebtorsScreen), findsOneWidget);
    // Seeded debtor shows up.
    expect(find.text('Acme Trading Corp'), findsOneWidget);
    // Client name is rendered on the SAME row as the debtor (cross-client list).
    final row = find.ancestor(
      of: find.text('Acme Trading Corp'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: row, matching: find.text('Telco One Rwanda')),
      findsOneWidget,
    );
    // Header proves clients were loaded for the count summary.
    expect(find.text('1 debtor across 2 clients'), findsOneWidget);
    // Search + New Debtor controls are present.
    expect(find.text('Search debtors by name…'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'New Debtor'), findsOneWidget);
  });

  testWidgets('tapping a debtor row opens its detail page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(host()));
    silenceLayoutOverflow();
    await tester.pump();
    await drain(tester, ms: 900);

    expect(find.text('Acme Trading Corp'), findsOneWidget);
    await tester.tap(find.text('Acme Trading Corp').first);
    await tester.pump();
    // Host swapped list -> detail.
    expect(find.byType(DebtorDetailScreen), findsOneWidget);
    expect(find.byType(DebtorsScreen), findsNothing);
    // Detail loads the debtor + its cases (FFI) then renders the header.
    await drain(tester, ms: 900);
    expect(find.text('Acme Trading Corp'), findsOneWidget);
  });

  testWidgets('New Debtor form creates a debtor that appears in the list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(host()));
    silenceLayoutOverflow();
    await tester.pump();
    await drain(tester, ms: 900);

    // Filter to Metro so the New-Debtor form is locked to Metro (no client
    // picker); then the first TextFormField is the NAME field.
    // bySubtype<DropdownButton<String>>() matches the generic instantiation;
    // find.byType(DropdownButton) would miss it (byType uses exact
    // runtimeType ==, which never equals the erased bare type Dropdown<dynamic>).
    final filterDropdown = find.bySubtype<DropdownButton<String>>().first;
    await tester.tap(filterDropdown);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.text('Metro Insurance Ltd'));
    await tester.pump(const Duration(milliseconds: 150));

    await tester.tap(find.widgetWithText(FilledButton, 'New Debtor'));
    await tester.pump();
    await drain(tester, ms: 400);

    expect(find.byType(DebtorFormDialog), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Metro Debtor Inc',
    );
    await tester.tap(find.text('Save Debtor'));

    // createDebtor (insert + reload) and the follow-up _openNewDebtor
    // loadDebtors are FFI-backed; under FakeAsync each statement only advances
    // when a real-time window (runAsync) is followed by a pump, so a single
    // drain can only progress ONE FFI op. Interleave runAsync + pump until the
    // form is dismissed, which proves the whole insert->reload->pop chain ran.
    for (int i = 0; i < 80; i++) {
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 25));
      });
      await tester.pump();
      if (find.byType(DebtorFormDialog).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();

    expect(find.text('Metro Debtor Inc'), findsOneWidget);
    final row = find.ancestor(
      of: find.text('Metro Debtor Inc'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: row, matching: find.text('Metro Insurance Ltd')),
      findsOneWidget,
    );
  });

  testWidgets(
    'New Case debtor dropdown contains "+ New Debtor" and opens the form',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        app(Scaffold(body: Center(child: CaseFormDialog()))),
      );
      silenceLayoutOverflow();
      await tester.pump();
      await drain(
        tester,
        ms: 900,
      ); // loads organizations into the client dropdown

      // Select a CLIENT (first dropdown) -> enables the debtor dropdown + the
      // quick-create sentinel.
      final dropdowns = find.bySubtype<DropdownButtonFormField<String>>();
      await tester.tap(dropdowns.first);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.text('Telco One Rwanda'));
      // Selecting a client triggers loadDebtorsForClient (2 FFI reads). Settle
      // them here, while the provider is still mounted, so their late
      // notifyListeners does not fire during tearDown ("used after being
      // disposed").
      await drain(tester, ms: 900);

      // Open the DEBTOR dropdown (second dropdown) and confirm the quick-create.
      final debtorDropdown = dropdowns.at(1);
      await tester.ensureVisible(debtorDropdown);
      await tester.tap(debtorDropdown);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('+ New Debtor'), findsOneWidget);

      // Tapping it opens the debtor form pre-locked to the selected client.
      await tester.tap(find.text('+ New Debtor'));
      await tester.pump();
      await drain(tester, ms: 400);
      expect(find.byType(DebtorFormDialog), findsOneWidget);
      // Locked to Telco -> the client picker is hidden, so the first field is Name.
      final nameField = find
          .descendant(
            of: find.byType(DebtorFormDialog),
            matching: find.byType(TextFormField),
          )
          .first;
      expect(nameField, findsOneWidget);
      // And the "+ New" inline label is also surfaced next to the DEBTOR label.
      expect(find.text('+ New'), findsOneWidget);
    },
  );
}
