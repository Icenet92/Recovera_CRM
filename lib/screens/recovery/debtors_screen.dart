import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/recovery_provider.dart';
import '../../../providers/crm_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/debtor_model.dart';
import '../../../theme/app_theme.dart';
import 'debtor_form_dialog.dart';
import '../crm/clients_screen.dart'; // Re-exports StatusBadge (public)

/// Top-level Debtors screen: lists every debtor across ALL clients, with the
/// owning client name shown per row, a client filter, search, a "New Debtor"
/// creation flow and click-to-detail.
class DebtorsScreen extends StatefulWidget {
  /// Fired when a debtor row is tapped so the shell can show the detail page.
  final ValueChanged<String>? onDebtorSelected;
  const DebtorsScreen({super.key, this.onDebtorSelected});

  @override
  State<DebtorsScreen> createState() => _DebtorsScreenState();
}

class _DebtorsScreenState extends State<DebtorsScreen> {
  final _searchCtrl = TextEditingController();
  String? _clientFilter; // null => "All Clients"

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rec = context.read<RecoveryProvider>();
      if (rec.debtors.isEmpty) rec.loadDebtors();
      rec.loadCaseCounts();
      context.read<CrmProvider>().loadOrganizations();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openNewDebtor() async {
    final rec = context.read<RecoveryProvider>();
    // If a client is filtered, the debtor is locked to that client; otherwise
    // DebtorFormDialog shows a client selector so the user must pick one.
    final result = await showDialog<DebtorModel>(
      context: context,
      builder: (_) => DebtorFormDialog(clientId: _clientFilter),
    );
    if (result == null) return;
    await rec.loadDebtors();
    await rec.loadCaseCounts();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Debtor "${result.name}" created')));
  }

  void _onSearchChanged(String q) {
    setState(() {}); // re-applies the name filter
  }

  List<DebtorModel> _displayList(RecoveryProvider rec) {
    final byClient = _clientFilter == null
        ? rec.debtors
        : rec.debtors.where((d) => d.clientId == _clientFilter);
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return byClient.toList();
    final lower = q.toLowerCase();
    return byClient.where((d) => d.name.toLowerCase().contains(lower)).toList();
  }

  String _clientNameOf(CrmProvider crm, String clientId) {
    for (final o in crm.organizations) {
      if (o.id == clientId) return o.companyName;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final rec = context.watch<RecoveryProvider>();
    final crm = context.watch<CrmProvider>();
    final auth = context.watch<AuthProvider>();
    final canCreate = auth.hasPermission('debtor.edit');
    final displayList = _displayList(rec);
    final filterLabel = _clientFilter != null
        ? _clientNameOf(crm, _clientFilter!)
        : 'All Clients';

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Page header ──────────────────────────────────────────────────
          Container(
            color: AppColors.bgCard,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Debtors', style: AppTypography.pageTitle(context)),
                    const SizedBox(height: 2),
                    Text(
                      '${rec.debtors.length} debtor${rec.debtors.length == 1 ? '' : 's'} across ${crm.organizations.length} client${crm.organizations.length == 1 ? '' : 's'}',
                      style: AppTypography.labelSmall(context),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                if (rec.isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const Spacer(),
                // Client filter.
                // NB: a DropdownButtonFormField with isDense:true shrink-wraps to
                // the hint's intrinsic width while its own trigger content (hint +
                // icon + paddings) is wider, producing a 138px RenderFlex overflow
                // that also shows as yellow stripes on desktop. Using an
                // isExpanded DropdownButton forces it to fill the 200-wide box so
                // trigger + menu items always fit.
                SizedBox(
                  width:
                      280, // > widest hint+icon+paddings so no intrinsic overflow
                  child: DropdownButton<String>(
                    value: _clientFilter,
                    isExpanded: true,
                    hint: Text(
                      'Filter by client',
                      style: AppTypography.labelSmall(context),
                    ),
                    style: const TextStyle(fontSize: 13),
                    iconSize: 18,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'All Clients',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      ...crm.organizations.map(
                        (o) => DropdownMenuItem<String>(
                          value: o.id,
                          child: Text(
                            o.companyName,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _clientFilter = v),
                  ),
                ),
                const SizedBox(width: 12),
                if (canCreate)
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Debtor'),
                    onPressed: _openNewDebtor,
                  ),
              ],
            ),
          ),
          const Divider(),

          // Search bar
          Container(
            color: AppColors.bgCard,
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search debtors by name…',
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        splashRadius: 16,
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          const Divider(),

          // Error banner
          if (rec.error != null)
            _ErrorBanner(message: rec.error!, onDismiss: rec.clearError),

          // Table header
          Container(
            color: AppColors.bgPage,
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
            child: Row(
              children: [
                Expanded(
                  flex: 25,
                  child: Text(
                    'NAME',
                    style: AppTypography.tableHeader(context),
                  ),
                ),
                Expanded(
                  flex: 12,
                  child: Text(
                    'TYPE',
                    style: AppTypography.tableHeader(context),
                  ),
                ),
                Expanded(
                  flex: 20,
                  child: Text(
                    'CLIENT',
                    style: AppTypography.tableHeader(context),
                  ),
                ),
                Expanded(
                  flex: 18,
                  child: Text(
                    'PHONE',
                    style: AppTypography.tableHeader(context),
                  ),
                ),
                Expanded(
                  flex: 20,
                  child: Text(
                    'EMAIL',
                    style: AppTypography.tableHeader(context),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    'CASES',
                    style: AppTypography.tableHeader(
                      context,
                    ).copyWith(fontSize: 10),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Table body
          Expanded(
            child: rec.debtors.isEmpty && rec.isLoading
                ? const Center(child: CircularProgressIndicator())
                : rec.debtors.isEmpty
                ? _EmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'No Debtors Found',
                    subtitle: 'Get started by creating your first debtor.',
                    actionLabel: canCreate ? 'Add First Debtor' : null,
                    onAction: canCreate ? _openNewDebtor : null,
                  )
                : displayList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _searchCtrl.text.trim().isNotEmpty
                            ? 'No debtors match your search for "${_searchCtrl.text.trim()}".'
                            : 'No debtors found for client "$filterLabel".',
                        style: AppTypography.labelSmall(context),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: displayList.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final d = displayList[i];
                      return _DebtorRow(
                        debtor: d,
                        clientName: _clientNameOf(crm, d.clientId),
                        caseCount: rec.caseCountByDebtor[d.id] ?? 0,
                        canEdit: canCreate,
                        onEdit: canCreate
                            ? () async {
                                final result = await showDialog<DebtorModel>(
                                  context: context,
                                  builder: (_) => DebtorFormDialog(existing: d),
                                );
                                if (result != null) {
                                  await rec.loadDebtors();
                                  await rec.loadCaseCounts();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Debtor "${result.name}" updated',
                                      ),
                                    ),
                                  );
                                }
                              }
                            : null,
                        onTap: () => widget.onDebtorSelected?.call(d.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DebtorRow extends StatelessWidget {
  final DebtorModel debtor;
  final String clientName;
  final int caseCount;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback onTap;
  const _DebtorRow({
    required this.debtor,
    required this.clientName,
    required this.caseCount,
    required this.canEdit,
    this.onEdit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: AppColors.bgCard,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: Row(
          children: [
            // ── Avatar + Name ───────────────────────────────────────────────
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(
                  debtor.name.isNotEmpty ? debtor.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 25,
              child: Text(
                debtor.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textHead,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // ── Type ───────────────────────────────────────────────────────
            Expanded(flex: 12, child: StatusBadge(debtor.type)),
            // ── Client ─────────────────────────────────────────────────────
            Expanded(
              flex: 20,
              child: Text(
                clientName,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.navy,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // ── Phone / Email ───────────────────────────────────────────────
            Expanded(
              flex: 18,
              child: Text(
                debtor.phone ?? '—',
                style: TextStyle(fontSize: 13, color: AppColors.textBody),
              ),
            ),
            Expanded(
              flex: 20,
              child: Text(
                debtor.email ?? '—',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textBody,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // ── Case count ─────────────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '$caseCount',
                    style: TextStyle(
                      fontSize: 13,
                      color: caseCount == 0
                          ? AppColors.textMuted
                          : AppColors.navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (caseCount == 1) ...[
                    const SizedBox(width: 4),
                    const Tooltip(
                      message: '1 case',
                      child: Icon(
                        Icons.cases_outlined,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (canEdit)
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                splashRadius: 16,
                tooltip: 'Edit debtor',
                onPressed: onEdit,
                padding: const EdgeInsets.only(left: 8),
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Local error / empty widgets (self-contained, mirror ClientsScreen style) ─

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.statusRedBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.statusRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.statusRed, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onDismiss,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.statusRed,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Dismiss', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Icon(icon, size: 36, color: AppColors.borderMid),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHead,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(actionLabel!),
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
