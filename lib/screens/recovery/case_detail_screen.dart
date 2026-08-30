import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/case_model.dart';
import '../../../providers/recovery_provider.dart';
import '../../../providers/crm_provider.dart';
import '../../../theme/app_theme.dart';
import '../crm/clients_screen.dart'; // For StatusBadge
import 'reassign_case_dialog.dart';
import 'close_case_dialog.dart';
import '../../../widgets/officer_picker.dart';

class CaseDetailScreen extends StatefulWidget {
  final String caseId;
  final VoidCallback onBack;
  const CaseDetailScreen({
    super.key,
    required this.caseId,
    required this.onBack,
  });

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecoveryProvider>().loadCaseDetails(widget.caseId);
      context
          .read<CrmProvider>()
          .loadOrganizations(); // So we can resolve org names
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _reassign(CaseModel c) {
    showDialog(
      context: context,
      builder: (_) => ReassignCaseDialog(caseModel: c),
    );
  }

  void _changeStatus(CaseModel c) {
    final isClosed = c.status.toLowerCase().contains('closed');
    showDialog(
      context: context,
      builder: (_) => CloseCaseDialog(caseModel: c, isReopening: isClosed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recProv = context.watch<RecoveryProvider>();
    final crmProv = context.watch<CrmProvider>();

    // The case is resolved by id via loadCaseDetails (initState) -> works
    // whether the global cases list was pre-loaded (Cases screen) or not
    // (opened from a client's Cases tab via MaterialPageRoute). While it loads
    // we show a spinner instead of throwing 'Case not found'.
    final cModel = recProv.currentCase;
    if (cModel == null) {
      // loadCaseDetails (initState) fetches the case by id. Show a spinner while
      // it loads; only show 'Case not found' once loading has finished without
      // resolving — covers the ClientDetail MaterialPageRoute path where the
      // cases list isn't pre-loaded.
      return Scaffold(
        body: Center(
          child: recProv.caseDetailsLoaded
              ? const Text(
                  'Case not found.',
                  style: TextStyle(color: AppColors.textMuted),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    // Organizations/debtors may not be cached yet on a given entry path;
    // resolve best-effort and degrade to a placeholder instead of throwing.
    final org = crmProv.organizations
        .where((e) => e.id == cModel.organizationId)
        .firstOrNull;
    final debtor = recProv.debtors
        .where((e) => e.id == cModel.debtorId)
        .firstOrNull;

    final isClosed = cModel.status.toLowerCase().contains('closed');

    return Scaffold(
      body: Column(
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
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    onPressed: widget.onBack,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    cModel.caseNumber,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('•', style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(width: 8),
                  Text(
                    org?.companyName ?? '—',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  StatusBadge(cModel.status),
                  const SizedBox(width: 8),
                  if (cModel.priority == 'Critical')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'CRITICAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cModel.title,
                          style: AppTypography.pageTitle(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Debtor: ${debtor?.name ?? 'Loading...'}',
                          style: AppTypography.labelSmall(context),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'OUTSTANDING BALANCE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        'RWF ${cModel.outstandingAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.statusRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () => _changeStatus(cModel),
                    icon: Icon(
                      isClosed ? Icons.lock_open : Icons.lock_outline,
                      size: 16,
                    ),
                    label: Text(isClosed ? 'Reopen Case' : 'Close Case'),
                    style: FilledButton.styleFrom(
                      backgroundColor: isClosed
                          ? AppColors.statusAmber
                          : AppColors.statusGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _reassign(cModel),
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Reassign'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {}, // For Phase 4/6
                    icon: const Icon(Icons.note_add, size: 16),
                    label: const Text('Add Note'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tabs
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.navy,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.navy,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Timeline & History'),
              Tab(text: 'Financials'),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildOverview(cModel, recProv),
              _buildTimeline(recProv),
              _buildFinancials(context, cModel),
            ],
          ),
        ),
      ],
      ),
    );
  }

  void _addSupportingEmployee(
    BuildContext ctx,
    String caseId,
    RecoveryProvider prov,
  ) {
    // Held outside the picker; the Add button reads it. The OfficerPicker is
    // seeded from the same provider officers the Reassign dialog uses.
    String? selectedId;
    showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Supporting Officer'),
          content: SizedBox(
            width: 400,
            child: OfficerPicker(
              onChanged: (id) {
                selectedId = id;
                setDialogState(() {});
              },
              decoration: const InputDecoration(
                labelText: 'Employee ID',
                hintText: 'Search officer…',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedId == null || selectedId!.isEmpty
                  ? null
                  : () {
                      final id = selectedId!.trim();
                      if (id.isEmpty) return;
                      Navigator.pop(context);
                      prov.addSupportingEmployee(caseId, id);
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(CaseModel c, RecoveryProvider recProv) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _InfoCard(
                  title: 'Case Details',
                  children: [
                    _InfoRow(
                      'Description',
                      c.description ?? 'No description provided',
                    ),
                    _InfoRow('Client Ref', c.clientReference ?? '-'),
                    _InfoRow('Type', c.caseType ?? '-'),
                    _InfoRow('Difficulty', c.difficulty),
                  ],
                ),
                const SizedBox(height: 24),
                _InfoCard(
                  title: 'Dates',
                  children: [
                    _InfoRow(
                      'Date Received',
                      c.dateReceived?.toIso8601String().split('T').first ?? '-',
                    ),
                    _InfoRow(
                      'Deadline',
                      c.deadline?.toIso8601String().split('T').first ?? '-',
                    ),
                    _InfoRow(
                      'Date Closed',
                      c.dateClosed?.toIso8601String().split('T').first ??
                          'Still Open',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _InfoCard(
              title: 'Team Assignment',
              children: [
                _InfoRow('Primary Owner', c.primaryOwnerId ?? 'Unassigned'),
                _InfoRow('Supervisor', c.supervisorId ?? 'Unassigned'),
                const SizedBox(height: 8),
                const Text(
                  'SUPPORTING EMPLOYEES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                ...recProv.supportingEmployees.map(
                  (se) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            se.employeeId,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        InkWell(
                          onTap: () => recProv.removeSupportingEmployee(
                            c.id,
                            se.employeeId,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (recProv.supportingEmployees.isEmpty)
                  const Text(
                    'No supporting officers assigned',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      _addSupportingEmployee(context, c.id, recProv),
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('Add Supporting Officer'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(RecoveryProvider prov) {
    final combined = <Map<String, dynamic>>[];
    for (var a in prov.assignments) {
      combined.add({
        'date': a.assignmentDate,
        'type': 'Assignment',
        'desc': 'Assigned to ${a.assignedToEmployeeId}',
        'reason': a.reason,
      });
    }
    for (var h in prov.statusHistory) {
      combined.add({
        'date': h.changeDate,
        'type': 'Status Change',
        'desc': '${h.oldStatus ?? "None"} → ${h.newStatus}',
        'reason': h.reason,
      });
    }

    combined.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );

    if (combined.isEmpty) {
      return const Center(child: Text('No history found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(32),
      itemCount: combined.length,
      itemBuilder: (context, i) {
        final item = combined[i];
        final dt = item['date'] as DateTime;
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  dt.toIso8601String().split('T').first,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4, right: 16),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.navy,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['type'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['desc'] as String,
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (item['reason'] != null &&
                        (item['reason'] as String).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Reason: ${item['reason']}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFinancials(BuildContext context, CaseModel c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.account_balance_wallet,
            size: 64,
            color: AppColors.border,
          ),
          const SizedBox(height: 16),
          Text('Financial Breakdown', style: AppTypography.pageTitle(context)),
          const SizedBox(height: 24),
          SizedBox(
            width: 300,
            child: Column(
              children: [
                _buildFinRow('Principal', c.principal),
                _buildFinRow('Interest', c.interest),
                _buildFinRow('Penalties', c.penalties),
                _buildFinRow('Fees', c.fees),
                const Divider(height: 32),
                _buildFinRow('Total Claim', c.totalClaim, isBold: true),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Payments & Adjustments coming in Phase 5.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            amount.toStringAsFixed(0),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.sectionHeader(context)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppColors.textBody),
          ),
        ],
      ),
    );
  }
}
