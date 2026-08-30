import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/recovery_provider.dart';
import '../../../theme/app_theme.dart';
import '../crm/clients_screen.dart'; // For StatusBadge
import 'case_form_dialog.dart';
import 'recovery_assignment_form.dart';

class CasesScreen extends StatefulWidget {
  final Function(String) onCaseSelected;
  final void Function(String assignmentId)? onAssignmentCreated;
  const CasesScreen({
    super.key,
    required this.onCaseSelected,
    this.onAssignmentCreated,
  });

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecoveryProvider>().loadCases();
    });
  }

  void _newCase() {
    showDialog(context: context, builder: (_) => const CaseFormDialog());
  }

  void _createBatch() {
    showDialog(
      context: context,
      builder: (_) => RecoveryAssignmentForm(
        onCreated: widget.onAssignmentCreated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<RecoveryProvider>();

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
                  Text('Cases', style: AppTypography.pageTitle(context)),
                  const SizedBox(height: 4),
                  Text(
                    'Manage active and closed recovery cases',
                    style: AppTypography.labelSmall(context),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: _newCase,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Case'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _createBatch,
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Create Batch'),
              ),
            ],
          ),
        ),

        // Error
        if (prov.error != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(24),
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
          child: prov.isLoading && prov.cases.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : prov.cases.isEmpty
              ? _buildEmptyState(context)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingTextStyle: AppTypography.tableHeader(context),
                      columns: const [
                        DataColumn(label: Text('CASE NO')),
                        DataColumn(label: Text('TITLE')),
                        DataColumn(label: Text('PRIORITY')),
                        DataColumn(label: Text('STATUS')),
                        DataColumn(label: Text('OUTSTANDING (RWF)')),
                        DataColumn(label: Text('DEADLINE')),
                      ],
                      rows: prov.cases.map((c) {
                        return DataRow(
                          onSelectChanged: (_) => widget.onCaseSelected(c.id),
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
                            DataCell(_PriorityBadge(priority: c.priority)),
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cases_outlined,
            size: 64,
            color: AppColors.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Cases Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textHead,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get started by creating a new recovery case.',
            style: AppTypography.labelSmall(context),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _newCase,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Case'),
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.bgCard;
    Color fg = AppColors.textBody;

    switch (priority.toLowerCase()) {
      case 'low':
        bg = AppColors.statusGreenBg;
        fg = AppColors.statusGreen;
        break;
      case 'medium':
        bg = AppColors.statusAmberBg;
        fg = AppColors.statusAmber;
        break;
      case 'high':
        bg = AppColors.statusRedBg;
        fg = AppColors.statusRed;
        break;
      case 'critical':
        bg = AppColors.statusRed;
        fg = Colors.white;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
