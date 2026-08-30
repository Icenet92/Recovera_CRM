import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/organization_model.dart';
import '../../models/contact_model.dart';
import '../../models/crm_activity_model.dart';
import '../../providers/crm_provider.dart';
import '../../providers/recovery_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'client_form_dialog.dart';
import 'contact_form_dialog.dart';
import 'log_activity_dialog.dart';
import 'clients_screen.dart' show StatusBadge;
import '../recovery/case_form_dialog.dart';
import '../recovery/debtor_form_dialog.dart';
import '../recovery/debtor_detail_screen.dart';
import '../recovery/case_detail_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final String organizationId;
  const ClientDetailScreen({super.key, required this.organizationId});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  OrganizationModel? _org;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    final crm = context.read<CrmProvider>();
    final recProv = context.read<RecoveryProvider>();
    final org = crm.organizations
        .where((o) => o.id == widget.organizationId)
        .firstOrNull;
    if (!mounted) return;
    setState(() {
      _org = org;
      _loading = false;
    });
    if (org != null) {
      crm.loadContactsForOrg(org.id);
      crm.loadActivitiesForOrg(org.id);
      recProv.loadClientWorkspace(org.id);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _editOrg() async {
    if (_org == null) return;
    final result = await showDialog<OrganizationModel>(
      context: context,
      builder: (_) => ClientFormDialog(existing: _org),
    );
    if (result != null && mounted) setState(() => _org = result);
  }

  void _addContact() async {
    if (_org == null) return;
    await showDialog(
      context: context,
      builder: (_) => ContactFormDialog(organizationId: _org!.id),
    );
  }

  void _logActivity() async {
    if (_org == null) return;
    final result = await showDialog(
      context: context,
      builder: (_) => LogActivityDialog(organizationId: _org!.id),
    );
    if (result != null) {
      context.read<CrmProvider>().loadActivitiesForOrg(_org!.id);
    }
  }

  void _addDebtor() async {
    if (_org == null) return;
    final newDebtor = await showDialog(
      context: context,
      builder: (_) => DebtorFormDialog(clientId: _org!.id),
    );
    if (newDebtor != null && mounted) {
      context.read<RecoveryProvider>().loadClientWorkspace(_org!.id);
    }
  }

  void _openCase(String caseId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaseDetailScreen(
          caseId: caseId,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _openDebtor(String debtorId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DebtorDetailScreen(debtorId: debtorId)),
    );
  }

  void _newCase() async {
    if (_org == null) return;
    await showDialog(
      context: context,
      builder: (_) => CaseFormDialog(initialClientId: _org!.id),
    );
    if (mounted) {
      context.read<RecoveryProvider>().loadClientWorkspace(_org!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.watch<CrmProvider>();
    final auth = context.watch<AuthProvider>();
    final canEdit = auth.hasPermission('crm.edit');
    final canCreateCase = auth.hasPermission('case.create');

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_org == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Client Detail')),
        body: const Center(child: Text('Client not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            color: AppColors.bgCard,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 24, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Back',
                        color: AppColors.textMuted,
                        splashRadius: 20,
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.accentBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Center(
                          child: Text(
                            _org!.companyName.isNotEmpty
                                ? _org!.companyName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _org!.companyName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: AppColors.textHead,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                StatusBadge(_org!.status),
                                if (_org!.industry != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    _org!.industry!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (canEdit)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('Edit'),
                          onPressed: _editOrg,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Debtors'),
                    Tab(text: 'Cases'),
                    Tab(text: 'Contacts'),
                    Tab(text: 'Activities'),
                    Tab(text: 'Financial'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(org: _org!),
                _DebtorsTab(
                  org: _org!,
                  onAddDebtor: _addDebtor,
                  onTapDebtor: _openDebtor,
                  canEdit: canEdit,
                ),
                _CasesTab(
                  org: _org!,
                  onNewCase: _newCase,
                  onTapCase: _openCase,
                  canCreate: canCreateCase,
                ),
                _ContactsTab(
                  org: _org!,
                  contacts: crm.contacts,
                  onAddContact: _addContact,
                  canEdit: canEdit,
                ),
                _ActivitiesTab(
                  activities: crm.activities,
                  org: _org!,
                  onLogActivity: _logActivity,
                  canLog: auth.hasPermission('crm.view'),
                ),
                const _LockedTab(
                  message: 'Financial breakdown coming in Phase 5',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overview Tab (with live aggregated stats) ──────────────────────────────

class _OverviewTab extends StatelessWidget {
  final OrganizationModel org;
  const _OverviewTab({required this.org});

  @override
  Widget build(BuildContext context) {
    final recProv = context.watch<RecoveryProvider>();
    final stats = recProv.clientStats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Stat cards ───────────────────────────────────────────────────
          if (stats != null)
            Row(
              children: [
                _StatCard(
                  'Total Debtors',
                  '${stats.totalDebtors}',
                  Icons.people_outline,
                  AppColors.statusBlueBg,
                  AppColors.statusBlue,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  'Total Cases',
                  '${stats.totalCases}',
                  Icons.folder_outlined,
                  AppColors.statusAmberBg,
                  AppColors.statusAmber,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  'Total Claimed',
                  'RWF ${_fmt(stats.totalClaimed)}',
                  Icons.monetization_on_outlined,
                  AppColors.statusPurpleBg,
                  AppColors.statusPurple,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  'Outstanding',
                  'RWF ${_fmt(stats.totalOutstanding)}',
                  Icons.trending_up,
                  AppColors.statusRedBg,
                  AppColors.statusRed,
                ),
              ],
            ),
          if (stats != null && stats.overdueCount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusRedBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.statusRed.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppColors.statusRed,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${stats.overdueCount} case${stats.overdueCount == 1 ? '' : 's'} overdue — past deadline and not closed.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.statusRed,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // ── Company info ─────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _InfoCard('General Information', [
                  _row('Industry', org.industry),
                  _row('Registration No.', org.registrationNumber),
                  _row('Lead Source', org.leadSource),
                  _row(
                    'Date Acquired',
                    org.dateAcquired != null
                        ? DateFormat('dd MMM yyyy').format(org.dateAcquired!)
                        : null,
                  ),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _InfoCard('Contact Details', [
                      _row('Phone', org.phone),
                      _row('Email', org.email),
                      _row('Address', org.address),
                    ]),
                    const SizedBox(height: 16),
                    _InfoCard('Contract', [
                      _row(
                        'Contract Start',
                        org.contractStartDate != null
                            ? DateFormat(
                                'dd MMM yyyy',
                              ).format(org.contractStartDate!)
                            : null,
                      ),
                      _row(
                        'Contract End',
                        org.contractEndDate != null
                            ? DateFormat(
                                'dd MMM yyyy',
                              ).format(org.contractEndDate!)
                            : null,
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),

          if (org.notes != null && org.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _InfoCard('Notes', [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  org.notes!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textBody,
                  ),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  static String _fmt(double v) => NumberFormat('#,##0').format(v);

  static Widget _row(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '—',
              style: TextStyle(
                fontSize: 13,
                color: value != null ? AppColors.textBody : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color bgColor;
  final Color fgColor;
  const _StatCard(
    this.label,
    this.value,
    this.icon,
    this.bgColor,
    this.fgColor,
  );

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: fgColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: fgColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Debtors Tab ─────────────────────────────────────────────────────────────

class _DebtorsTab extends StatelessWidget {
  final OrganizationModel org;
  final VoidCallback onAddDebtor;
  final ValueChanged<String> onTapDebtor;
  final bool canEdit;

  const _DebtorsTab({
    required this.org,
    required this.onAddDebtor,
    required this.onTapDebtor,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final recProv = context.watch<RecoveryProvider>();
    final debtorStats = recProv.debtorCaseStats;

    return Column(
      children: [
        if (canEdit)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('Add Debtor'),
                  onPressed: onAddDebtor,
                ),
              ],
            ),
          ),
        Expanded(
          child: debtorStats.isEmpty
              ? _emptyState(context)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  itemCount: debtorStats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final ds = debtorStats[i];
                    return _DebtorRow(
                      debtorName: ds.debtorName,
                      caseCount: ds.caseCount,
                      outstanding: ds.outstandingTotal,
                      onTap: () => onTapDebtor(ds.debtorId),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: const Icon(
              Icons.people_outline,
              size: 30,
              color: AppColors.borderMid,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No debtors yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textHead,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add debtors that belong to this client.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          if (canEdit) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Debtor'),
              onPressed: onAddDebtor,
            ),
          ],
        ],
      ),
    );
  }
}

class _DebtorRow extends StatelessWidget {
  final String debtorName;
  final int caseCount;
  final double outstanding;
  final VoidCallback onTap;
  const _DebtorRow({
    required this.debtorName,
    required this.caseCount,
    required this.outstanding,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: AppColors.accentBg,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.navyLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  debtorName.isNotEmpty ? debtorName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    debtorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textHead,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$caseCount case${caseCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'OUTSTANDING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  'RWF ${NumberFormat('#,##0').format(outstanding)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.statusRed,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cases Tab ───────────────────────────────────────────────────────────────

class _CasesTab extends StatelessWidget {
  final OrganizationModel org;
  final VoidCallback onNewCase;
  final ValueChanged<String> onTapCase;
  final bool canCreate;

  const _CasesTab({
    required this.org,
    required this.onNewCase,
    required this.onTapCase,
    required this.canCreate,
  });

  @override
  Widget build(BuildContext context) {
    final recProv = context.watch<RecoveryProvider>();
    final cases = recProv.clientCases;

    return Column(
      children: [
        if (canCreate)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Case'),
                  onPressed: onNewCase,
                ),
              ],
            ),
          ),
        Expanded(
          child: cases.isEmpty
              ? _emptyCases(context)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingTextStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                      columns: const [
                        DataColumn(label: Text('CASE NO')),
                        DataColumn(label: Text('TITLE')),
                        DataColumn(label: Text('DEBTOR')),
                        DataColumn(label: Text('STATUS')),
                        DataColumn(label: Text('OUTSTANDING (RWF)')),
                        DataColumn(label: Text('DEADLINE')),
                      ],
                      rows: cases.map((c) {
                        return DataRow(
                          onSelectChanged: (_) => onTapCase(c.id),
                          cells: [
                            DataCell(
                              Text(
                                c.caseNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            DataCell(Text(c.title)),
                            DataCell(_DebtorNameCell(debtorId: c.debtorId)),
                            DataCell(StatusBadge(c.status)),
                            DataCell(
                              Text(c.outstandingAmount.toStringAsFixed(0)),
                            ),
                            DataCell(
                              Text(
                                c.deadline
                                        ?.toIso8601String()
                                        .split('T')
                                        .first ??
                                    '-',
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

  Widget _emptyCases(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: const Icon(
              Icons.cases_outlined,
              size: 30,
              color: AppColors.borderMid,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No cases yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textHead,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Create a recovery case for this client.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          if (canCreate) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Case'),
              onPressed: onNewCase,
            ),
          ],
        ],
      ),
    );
  }
}

/// Resolves and shows the debtor name for a case row in the table.
class _DebtorNameCell extends StatelessWidget {
  final String debtorId;
  const _DebtorNameCell({required this.debtorId});

  @override
  Widget build(BuildContext context) {
    final debtors = context.watch<RecoveryProvider>().clientDebtors;
    try {
      final match = debtors.firstWhere((d) => d.id == debtorId);
      return Text(match.name, style: const TextStyle(fontSize: 13));
    } catch (_) {
      return const Text('—', style: TextStyle(fontSize: 13));
    }
  }
}

// ── Contacts Tab (unchanged) ────────────────────────────────────────────────

class _ContactsTab extends StatelessWidget {
  final OrganizationModel org;
  final List<ContactModel> contacts;
  final VoidCallback onAddContact;
  final bool canEdit;

  const _ContactsTab({
    required this.org,
    required this.contacts,
    required this.onAddContact,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (canEdit)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('Add Contact'),
                  onPressed: onAddContact,
                ),
              ],
            ),
          ),
        Expanded(
          child: contacts.isEmpty
              ? _emptyContacts(context)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ContactCard(contact: contacts[i]),
                ),
        ),
      ],
    );
  }

  Widget _emptyContacts(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 30,
              color: AppColors.borderMid,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No contacts yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textHead,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add people from this organization.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          if (canEdit) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Contact'),
              onPressed: onAddContact,
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final ContactModel contact;
  const _ContactCard({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                contact.firstName.isNotEmpty
                    ? contact.firstName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      contact.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textHead,
                      ),
                    ),
                    if (contact.isDecisionMaker) ...[
                      const SizedBox(width: 6),
                      const Tooltip(
                        message: 'Decision Maker',
                        child: Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${contact.roleType}${contact.position != null ? " · ${contact.position}" : ""}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (contact.phone != null)
                Text(
                  contact.phone!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textBody,
                  ),
                ),
              if (contact.email != null)
                Text(
                  contact.email!,
                  style: const TextStyle(fontSize: 12, color: AppColors.accent),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Activities Tab (unchanged) ─────────────────────────────────────────────

class _ActivitiesTab extends StatelessWidget {
  final List<CrmActivityModel> activities;
  final OrganizationModel org;
  final VoidCallback onLogActivity;
  final bool canLog;

  const _ActivitiesTab({
    required this.activities,
    required this.org,
    required this.onLogActivity,
    required this.canLog,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (canLog)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.add_comment_outlined, size: 16),
                  label: const Text('Log Activity'),
                  onPressed: onLogActivity,
                ),
              ],
            ),
          ),
        Expanded(
          child: activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.bgPage,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 2),
                        ),
                        child: const Icon(
                          Icons.timeline_outlined,
                          size: 30,
                          color: AppColors.borderMid,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No activities yet',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHead,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Log the first interaction with this client.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  itemCount: activities.length,
                  itemBuilder: (_, i) => _ActivityTile(activity: activities[i]),
                ),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final CrmActivityModel activity;
  const _ActivityTile({required this.activity});

  static Color _typeColor(String type) {
    switch (type) {
      case 'Call':
        return AppColors.statusBlue;
      case 'Meeting':
        return AppColors.statusGreen;
      case 'Note':
        return AppColors.statusGray;
      case 'Email':
        return AppColors.statusPurple;
      case 'Decision':
        return AppColors.statusGreen;
      case 'FollowUp':
        return AppColors.statusAmber;
      default:
        return AppColors.statusGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(activity.activityType);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    CrmActivityModel.iconForType(activity.activityType),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          activity.subject,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textHead,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          activity.activityType,
                          style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (activity.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      activity.description!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textBody,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (activity.outcome != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusGreenBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 12,
                            color: AppColors.statusGreen,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              activity.outcome!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.statusGreen,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    DateFormat(
                      'dd MMM yyyy, HH:mm',
                    ).format(activity.activityDate.toLocal()),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helper widgets ──────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textHead,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedTab extends StatelessWidget {
  final String message;
  const _LockedTab({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: const Icon(
              Icons.construction_rounded,
              size: 30,
              color: AppColors.borderMid,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
