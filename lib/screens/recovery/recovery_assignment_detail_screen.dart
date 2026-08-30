import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/recovery_assignment_model.dart';
import '../../../providers/recovery_provider.dart';
import '../../../theme/app_theme.dart';
import '../crm/clients_screen.dart'; // For StatusBadge

/// Phase 3B — Recovery Assignment (Case Pool) detail view.
///
/// Shows the batch's target vs. recovered amount, deadline vs. today
/// (read-time [RecoveryAssignmentModel.isOverdue]), a progress bar, the
/// pooled-cases table with each case's per-batch duration, and inline
/// Complete / Cancel / Remove-case actions.
class RecoveryAssignmentDetailScreen extends StatefulWidget {
  final String assignmentId;
  final VoidCallback onBack;
  const RecoveryAssignmentDetailScreen({
    super.key,
    required this.assignmentId,
    required this.onBack,
  });

  @override
  State<RecoveryAssignmentDetailScreen> createState() =>
      _RecoveryAssignmentDetailScreenState();
}

class _RecoveryAssignmentDetailScreenState
    extends State<RecoveryAssignmentDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<RecoveryProvider>();
      prov.loadRecoveryAssignment(widget.assignmentId);
      if (prov.officers.isEmpty) prov.loadOfficers();
    });
  }

  String _officerName(RecoveryProvider prov, String id) {
    final o = prov.officers.firstWhere((e) => e['id'] == id, orElse: () => const {});
    return (o['username'] as String?) ?? id;
  }

  String _fmtDuration(Duration? d) {
    if (d == null) return '-';
    final days = d.inDays;
    final hours = d.inHours.remainder(60);
    if (days > 0) return '${days}d ${hours}h';
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<RecoveryProvider>();
    final a = prov.currentAssignment;

    if (prov.isLoading && a == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (a == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Assignment not found.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final isOverdue = a.isOverdue;
    final deadlineStr = a.deadlineDate.toIso8601String().split('T').first;
    final cases = prov.currentAssignmentCases;
    final recovered = prov.currentAssignmentRecoveredAmount;
    final progress = a.targetAmount > 0
        ? (recovered / a.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final isActive = a.status == 'Active';

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
                    'Batch: ${a.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '•',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _officerName(prov, a.assignedEmployeeId),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  StatusBadge(a.status),
                  if (isOverdue)
                    Container(
                      margin: const EdgeInsets.only(left: 12),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.statusRedBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'OVERDUE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.statusRed,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Recovery Assignment',
                style: AppTypography.pageTitle(context),
              ),
              Text(
                isOverdue
                    ? 'Deadline passed — recovery goal overdue'
                    : 'Deadline: $deadlineStr',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      isOverdue ? AppColors.statusRed : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              // Target vs Recovered
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Target',
                      value: 'RWF ${a.targetAmount.toStringAsFixed(0)}',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Recovered',
                      value: 'RWF ${recovered.toStringAsFixed(0)}',
                      accent: AppColors.statusGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.bgCard,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).clamp(0.0, 100.0).toStringAsFixed(0)}% of target recovered',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              // Actions (Phase 5 unlocks partial-collection actions)
              Wrap(
                spacing: 12,
                children: [
                  if (isActive) ...[
                    FilledButton.icon(
                      onPressed: () => prov.completeAssignment(a.id),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Complete Batch'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => prov.cancelAssignment(a.id),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Cancel Batch'),
                    ),
                  ],
                  if (a.isOverdue && isActive)
                    const Text(
                      'This batch is past its deadline.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.statusRed,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Pooled cases table
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: DataTable(
                showCheckboxColumn: false,
                headingTextStyle: AppTypography.tableHeader(context),
                columns: const [
                  DataColumn(label: Text('CASE NO')),
                  DataColumn(label: Text('TITLE')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('TIME IN POOL')),
                  DataColumn(label: Text('OUTSTANDING (RWF)')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: cases.map((c) {
                  final inPool =
                      prov.timeToRecoveryForCase(c.id);
                  return DataRow(
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
                      DataCell(StatusBadge(c.status)),
                      DataCell(Text(_fmtDuration(inPool))),
                      DataCell(
                        Text(c.outstandingAmount.toStringAsFixed(0)),
                      ),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              size: 18),
                          color: AppColors.statusRed,
                          tooltip: 'Remove from batch',
                          onPressed: isActive
                              ? () => prov.removeCaseFromBatch(a.id, c.id)
                              : null,
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
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accent;
  const _StatCard({
    required this.title,
    required this.value,
    this.accent = AppColors.navy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.labelSmall(context)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
