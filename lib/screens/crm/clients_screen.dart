import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/organization_model.dart';
import '../../providers/crm_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'client_form_dialog.dart';
import 'client_detail_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _searchCtrl = TextEditingController();
  String? _statusFilter;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CrmProvider>().loadOrganizations();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    final crm = context.read<CrmProvider>();
    setState(() => _searching = q.trim().isNotEmpty);
    if (q.trim().isEmpty) {
      crm.searchClients('');
      crm.loadOrganizations(statusFilter: _statusFilter);
    } else {
      crm.searchClients(q);
    }
  }

  void _openNewClient() async {
    final result = await showDialog<OrganizationModel>(
      context: context,
      builder: (_) => const ClientFormDialog(),
    );
    if (result != null && mounted) {
      _showSnack('Client "${result.companyName}" created');
    }
  }

  void _openDetail(OrganizationModel org) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientDetailScreen(organizationId: org.id),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.watch<CrmProvider>();
    final auth = context.watch<AuthProvider>();
    final canCreate = auth.hasPermission('crm.create');
    final displayList = _searching ? crm.searchResults : crm.organizations;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        children: [
          // ── Page header ──────────────────────────────────────────────────
          Container(
            color: AppColors.bgCard,
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Clients', style: AppTypography.pageTitle(context)),
                    const SizedBox(height: 2),
                    Text(
                      '${crm.organizations.length} organization${crm.organizations.length == 1 ? '' : 's'}',
                      style: AppTypography.labelSmall(context),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                if (crm.isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const Spacer(),
                // Status filter chips
                _statusChip('All', null, crm),
                const SizedBox(width: 6),
                _statusChip('Active', 'Active', crm),
                const SizedBox(width: 6),
                _statusChip('Prospect', 'Prospect', crm),
                const SizedBox(width: 6),
                _statusChip('Negotiating', 'Negotiating', crm),
                if (canCreate) ...[
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Client'),
                    onPressed: _openNewClient,
                  ),
                ],
              ],
            ),
          ),
          const Divider(),

          // ── Search bar ───────────────────────────────────────────────────
          Container(
            color: AppColors.bgCard,
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by company name, phone, or email…',
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
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),
          const Divider(),

          // ── Error banner ─────────────────────────────────────────────────
          if (crm.error != null)
            _ErrorBanner(message: crm.error!, onDismiss: crm.clearError),

          // ── Table header ─────────────────────────────────────────────────
          Container(
            color: AppColors.bgPage,
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'COMPANY',
                    style: AppTypography.tableHeader(context),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'INDUSTRY',
                    style: AppTypography.tableHeader(context),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'STATUS',
                    style: AppTypography.tableHeader(context),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'PHONE',
                    style: AppTypography.tableHeader(context),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'DATE ACQUIRED',
                    style: AppTypography.tableHeader(context),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // ── Table body ───────────────────────────────────────────────────
          Expanded(
            child: displayList.isEmpty && !crm.isLoading
                ? _EmptyState(
                    icon: Icons.business_outlined,
                    title: _searching ? 'No results found' : 'No clients yet',
                    subtitle: _searching
                        ? 'Try adjusting your search term.'
                        : 'Add your first client to get started.',
                    actionLabel: (!_searching && canCreate)
                        ? 'Add First Client'
                        : null,
                    onAction: _openNewClient,
                  )
                : ListView.separated(
                    itemCount: displayList.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final org = displayList[i];
                      return _ClientRow(
                        org: org,
                        onTap: () => _openDetail(org),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, String? value, CrmProvider crm) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.accentBg,
      onSelected: (_) {
        setState(() => _statusFilter = value);
        crm.loadOrganizations(statusFilter: value);
      },
    );
  }
}

class _ClientRow extends StatelessWidget {
  final OrganizationModel org;
  final VoidCallback onTap;
  const _ClientRow({required this.org, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: AppColors.accentBg,
      child: Container(
        color: AppColors.bgCard,
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _OrgAvatar(name: org.companyName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      org.companyName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textHead,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                org.industry ?? '—',
                style: const TextStyle(fontSize: 13, color: AppColors.textBody),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(flex: 2, child: StatusBadge(org.status)),
            Expanded(
              flex: 2,
              child: Text(
                org.phone ?? '—',
                style: const TextStyle(fontSize: 13, color: AppColors.textBody),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                org.dateAcquired != null
                    ? DateFormat('dd MMM yyyy').format(org.dateAcquired!)
                    : '—',
                style: const TextStyle(fontSize: 13, color: AppColors.textBody),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrgAvatar extends StatelessWidget {
  final String name;
  const _OrgAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.accentBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// Reusable status badge — exported for use in client_detail_screen etc.
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  static (Color, Color) _colors(String status) {
    switch (status) {
      case 'Active':
        return (AppColors.statusGreenBg, AppColors.statusGreen);
      case 'Prospect':
        return (AppColors.statusBlueBg, AppColors.statusBlue);
      case 'Negotiating':
        return (AppColors.statusAmberBg, AppColors.statusAmber);
      case 'Onboarding':
        return (AppColors.statusPurpleBg, AppColors.statusPurple);
      case 'Contacted':
        return (AppColors.statusBlueBg, AppColors.statusBlue);
      case 'Dormant':
        return (AppColors.statusGrayBg, AppColors.statusGray);
      case 'Suspended':
        return (AppColors.statusRedBg, AppColors.statusRed);
      case 'Lost':
        return (AppColors.statusRedBg, AppColors.statusRed);
      case 'Closed':
        return (AppColors.statusGrayBg, AppColors.statusGray);
      default:
        return (AppColors.statusGrayBg, AppColors.statusGray);
    }
  }
}

// ── Shared empty state widget ──────────────────────────────────────────────

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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHead,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
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

// ── Shared error banner ────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.statusRedBg,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.statusRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.statusRed, fontSize: 13),
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
