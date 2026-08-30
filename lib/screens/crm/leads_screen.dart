import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/lead_model.dart';
import '../../providers/crm_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'lead_form_dialog.dart';
import 'log_activity_dialog.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final crm = context.read<CrmProvider>();
      await crm.loadOrganizations();
      await crm.loadLeads();
    });
  }

  void _newLead() async {
    await showDialog(context: context, builder: (_) => const LeadFormDialog());
  }

  void _editLead(LeadModel lead) async {
    await showDialog(
      context: context,
      builder: (_) => LeadFormDialog(existing: lead),
    );
  }

  void _logActivity(LeadModel lead) async {
    await showDialog(
      context: context,
      builder: (_) => LogActivityDialog(
        leadId: lead.id,
        organizationId: lead.organizationId,
      ),
    );
  }

  void _moveLead(LeadModel lead, String newStage) {
    context.read<CrmProvider>().moveLeadStage(lead.id, newStage);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.watch<CrmProvider>();
    final auth = context.watch<AuthProvider>();
    final canManage = auth.hasPermission('lead.manage');

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
                    Text(
                      'Lead Pipeline',
                      style: AppTypography.pageTitle(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${crm.leads.length} lead${crm.leads.length == 1 ? '' : 's'} across ${LeadModel.pipelineStages.length} stages',
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
                if (canManage)
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Lead'),
                    onPressed: _newLead,
                  ),
              ],
            ),
          ),
          const Divider(),

          if (crm.error != null)
            _ErrorBanner(message: crm.error!, onDismiss: crm.clearError),

          // ── Kanban board ─────────────────────────────────────────────────
          Expanded(
            child: crm.leads.isEmpty && !crm.isLoading
                ? _EmptyState(
                    icon: Icons.view_kanban_outlined,
                    title: 'No leads in the pipeline',
                    subtitle:
                        'Create your first lead to start tracking opportunities.',
                    actionLabel: canManage ? 'Add First Lead' : null,
                    onAction: _newLead,
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: LeadModel.pipelineStages.map((stage) {
                        final stageLeads = crm.leadsByStage[stage] ?? [];
                        return _KanbanColumn(
                          stage: stage,
                          leads: stageLeads,
                          allOrgs: crm.organizations,
                          canManage: canManage,
                          onEdit: _editLead,
                          onLogActivity: _logActivity,
                          onDrop: (lead) => _moveLead(lead, stage),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Kanban column ──────────────────────────────────────────────────────────

class _KanbanColumn extends StatelessWidget {
  final String stage;
  final List<LeadModel> leads;
  final List allOrgs;
  final bool canManage;
  final ValueChanged<LeadModel> onEdit;
  final ValueChanged<LeadModel> onLogActivity;
  final ValueChanged<LeadModel> onDrop;

  const _KanbanColumn({
    required this.stage,
    required this.leads,
    required this.allOrgs,
    required this.canManage,
    required this.onEdit,
    required this.onLogActivity,
    required this.onDrop,
  });

  // Stage accent color (dot + card left border)
  static Color _stageColor(String stage) {
    switch (stage) {
      case 'New':
        return const Color(0xFF64B5F6);
      case 'Qualified':
        return const Color(0xFF4DD0E1);
      case 'Contacted':
        return const Color(0xFF81C784);
      case 'Meeting':
        return const Color(0xFFFFB74D);
      case 'Proposal':
        return const Color(0xFFFF8A65);
      case 'Negotiation':
        return const Color(0xFFBA68C8);
      case 'Contract':
        return const Color(0xFFF06292);
      case 'Onboarding':
        return const Color(0xFFFFD54F);
      case 'Client':
        return const Color(0xFF4CAF50);
      default:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _stageColor(stage);

    return DragTarget<LeadModel>(
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidateData, _) {
        final isOver = candidateData.isNotEmpty;
        return Container(
          width: 232,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: isOver ? AppColors.accentBg : AppColors.bgPage,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isOver ? AppColors.accent : AppColors.border,
              width: isOver ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Column header
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(9),
                  ),
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stage,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
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
                        color: leads.isEmpty
                            ? AppColors.bgPage
                            : accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${leads.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: leads.isEmpty ? AppColors.textMuted : accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Cards
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  itemCount: leads.length,
                  itemBuilder: (_, i) => _LeadCard(
                    lead: leads[i],
                    stageColor: accent,
                    orgName: allOrgs
                        .where((o) => o.id == leads[i].organizationId)
                        .map((o) => o.companyName as String)
                        .firstOrNull,
                    canManage: canManage,
                    onEdit: () => onEdit(leads[i]),
                    onLogActivity: () => onLogActivity(leads[i]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Lead card ──────────────────────────────────────────────────────────────

class _LeadCard extends StatelessWidget {
  final LeadModel lead;
  final Color stageColor;
  final String? orgName;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onLogActivity;

  const _LeadCard({
    required this.lead,
    required this.stageColor,
    this.orgName,
    required this.canManage,
    required this.onEdit,
    required this.onLogActivity,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable<LeadModel>(
      data: lead,
      feedback: _CardBody(
        lead: lead,
        stageColor: stageColor,
        orgName: orgName,
        canManage: false,
        onEdit: () {},
        onLogActivity: () {},
        dragging: true,
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _CardBody(
          lead: lead,
          stageColor: stageColor,
          orgName: orgName,
          canManage: false,
          onEdit: () {},
          onLogActivity: () {},
        ),
      ),
      child: _CardBody(
        lead: lead,
        stageColor: stageColor,
        orgName: orgName,
        canManage: canManage,
        onEdit: onEdit,
        onLogActivity: onLogActivity,
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  final LeadModel lead;
  final Color stageColor;
  final String? orgName;
  final bool canManage;
  final bool dragging;
  final VoidCallback onEdit;
  final VoidCallback onLogActivity;

  const _CardBody({
    required this.lead,
    required this.stageColor,
    this.orgName,
    required this.canManage,
    required this.onEdit,
    required this.onLogActivity,
    this.dragging = false,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_US');
    final isOverdue = lead.isFollowupOverdue;

    return Container(
      width: dragging ? 216 : null,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOverdue
              ? AppColors.statusAmber.withValues(alpha: 0.5)
              : AppColors.border,
        ),
        boxShadow: dragging
            ? [
                const BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : [
                const BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stage accent strip
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: stageColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lead.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: AppColors.textHead,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (orgName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.business,
                        size: 11,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          orgName!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (lead.expectedValue != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'RWF ${fmt.format(lead.expectedValue!)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                if (lead.nextAction != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.arrow_forward,
                        size: 11,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          lead.nextAction!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textBody,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (lead.followupDate != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? AppColors.statusAmberBg
                          : AppColors.bgPage,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 11,
                          color: isOverdue
                              ? AppColors.statusAmber
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd MMM').format(lead.followupDate!),
                          style: TextStyle(
                            fontSize: 11,
                            color: isOverdue
                                ? AppColors.statusAmber
                                : AppColors.textMuted,
                            fontWeight: isOverdue
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        if (isOverdue) ...[
                          const SizedBox(width: 4),
                          Text(
                            'OVERDUE',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.statusAmber,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (canManage && !dragging) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ActionIcon(
                        icon: Icons.add_comment_outlined,
                        tooltip: 'Log Activity',
                        onTap: onLogActivity,
                      ),
                      const SizedBox(width: 8),
                      _ActionIcon(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit Lead',
                        onTap: onEdit,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 15, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

// ── Shared widgets (copy from clients_screen for self-containment) ──────────

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
            style: TextButton.styleFrom(foregroundColor: AppColors.statusRed),
            child: const Text('Dismiss', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
