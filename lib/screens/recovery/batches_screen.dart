import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/recovery_provider.dart';
import '../../../theme/app_theme.dart';
import '../crm/clients_screen.dart'; // StatusBadge
import 'recovery_assignment_form.dart';

/// Phase 3B — Batches (Recovery Assignments) list screen.
///
/// Shows every recovery assignment visible to the current session, filterable
/// by status (All / Active / Completed / Cancelled). Tapping a row opens the
/// existing [RecoveryAssignmentDetailScreen] through AppShell's
/// `_selectedAssignmentId` routing — the same mechanism [CasesScreen] uses for
/// `_selectedCaseId`.
class BatchesScreen extends StatefulWidget {
  final void Function(String)? onBatchSelected;
  final void Function(String)? onAssignmentCreated;
  const BatchesScreen({
    super.key,
    this.onBatchSelected,
    this.onAssignmentCreated,
  });

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<RecoveryProvider>();
      prov.loadAssignments();
      if (prov.officers.isEmpty) prov.loadOfficers();
    });
  }

  void _createBatch() {
    showDialog(
      context: context,
      builder: (_) => RecoveryAssignmentForm(
        onCreated: widget.onAssignmentCreated,
      ),
    );
  }

  static String _officerName(RecoveryProvider prov, String id) {
    final o = prov.officers.firstWhere(
      (e) => e['id'] == id,
      orElse: () => const {},
    );
    return (o['username'] as String?) ?? id;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<RecoveryProvider>();

    final all = prov.recoveryAssignments;
    final batches = _statusFilter == 'All'
        ? all
        : all.where((a) => a.status == _statusFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Batches', style: AppTypography.pageTitle(context)),
                  const SizedBox(height: 4),
                  Text(
                    'Recovery assignment pools across the firm',
                    style: AppTypography.labelSmall(context),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: _createBatch,
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('New Batch'),
              ),
            ],
          ),
        ),

        // Status filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Wrap(
            spacing: 8,
            children: [
              for (final f in ['All', 'Active', 'Completed', 'Cancelled'])
                _StatusFilterChip(
                  label: f,
                  selected: _statusFilter == f,
                  onTap: () => setState(() => _statusFilter = f),
                ),
            ],
          ),
        ),

        // Error
        if (prov.error != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            color: AppColors.statusRedBg,
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.statusRed),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    prov.error!,
                    style: const TextStyle(color: AppColors.statusRed),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: prov.clearError,
                ),
              ],
            ),
          ),

        // List
        Expanded(
          child: prov.isLoading && batches.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : batches.isEmpty
              ? _buildEmptyState(context)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingTextStyle: AppTypography.tableHeader(context),
                      columns: const [
                        DataColumn(label: Text('BATCH')),
                        DataColumn(label: Text('ASSIGNED TO')),
                        DataColumn(label: Text('TARGET (RWF)')),
                        DataColumn(label: Text('STATUS')),
                        DataColumn(label: Text('DEADLINE')),
                      ],
                      rows: batches.map((a) {
                        final deadlineStr =
                            a.deadlineDate.toIso8601String().split('T').first;
                        return DataRow(
                          onSelectChanged: (_) =>
                              widget.onBatchSelected?.call(a.id),
                          cells: [
                            DataCell(
                              Text(
                                a.id.substring(0, 8),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(_officerName(prov, a.assignedEmployeeId)),
                            ),
                            DataCell(Text(a.targetAmount.toStringAsFixed(0))),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  StatusBadge(a.status),
                                  if (a.isOverdue) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.warning_rounded,
                                      size: 14,
                                      color: AppColors.statusRed,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                deadlineStr,
                                style: TextStyle(
                                  color: a.isOverdue
                                      ? AppColors.statusRed
                                      : AppColors.textBody,
                                  fontWeight: a.isOverdue
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: AppColors.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Batches Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textHead,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusFilter == 'All'
                ? 'Get started by creating a new recovery assignment batch.'
                : 'No batches match the current filter.',
            style: AppTypography.labelSmall(context),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _createBatch,
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: const Text('New Batch'),
          ),
        ],
      ),
    );
  }
}

/// A single-select status filter chip for the Batches list.
class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: selected ? Colors.white : AppColors.sidebarText,
      ),
      backgroundColor: AppColors.bgCard,
      selectedColor: AppColors.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }
}
