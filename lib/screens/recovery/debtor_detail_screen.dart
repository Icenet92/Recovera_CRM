import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/debtor_model.dart';
import '../../models/case_model.dart';
import '../../providers/recovery_provider.dart';
import '../../theme/app_theme.dart';

/// Full-page screen showing a debtor's own info and every case belonging to them.
class DebtorDetailScreen extends StatefulWidget {
  final String debtorId;
  final VoidCallback? onBack;
  const DebtorDetailScreen({super.key, required this.debtorId, this.onBack});

  @override
  State<DebtorDetailScreen> createState() => _DebtorDetailScreenState();
}

class _DebtorDetailScreenState extends State<DebtorDetailScreen> {
  DebtorModel? _debtor;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Defer the data load to a post-frame callback so the first build runs
    // with a clean layout (no `markNeedsBuild` during the mount/build phase,
    // which would otherwise throw "setState/markNeedsBuild called during build"
    // because loadCasesForDebtor notifies listeners synchronously).
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final recProv = context.read<RecoveryProvider>();
    // Ensure debtors are loaded so we can find this one
    if (recProv.debtors.isEmpty) {
      await recProv.loadDebtors();
    }
    // Load cases for this debtor
    await recProv.loadCasesForDebtor(widget.debtorId);

    if (!mounted) return;
    final debtor = recProv.debtors.firstWhere(
      (d) => d.id == widget.debtorId,
      orElse: () => throw Exception('Debtor not found'),
    );
    setState(() {
      _debtor = debtor;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final recProv = context.watch<RecoveryProvider>();

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_debtor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Debtor Detail')),
        body: const Center(child: Text('Debtor not found')),
      );
    }

    final cases = recProv.debtorCases;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            color: AppColors.bgCard,
            padding: const EdgeInsets.fromLTRB(16, 12, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      onPressed:
                          widget.onBack ?? () => Navigator.of(context).pop(),
                      tooltip: 'Back',
                      color: AppColors.textMuted,
                      splashRadius: 20,
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.navyLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          _debtor!.name.isNotEmpty
                              ? _debtor!.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
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
                            _debtor!.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: AppColors.textHead,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _debtor!.type,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: cases.isEmpty
                            ? AppColors.statusGrayBg
                            : AppColors.statusBlueBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${cases.length} case${cases.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cases.isEmpty
                              ? AppColors.statusGray
                              : AppColors.statusBlue,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Contact info chips
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (_debtor!.phone != null)
                      _InfoChip(
                        icon: Icons.phone_outlined,
                        label: _debtor!.phone!,
                      ),
                    if (_debtor!.email != null)
                      _InfoChip(
                        icon: Icons.email_outlined,
                        label: _debtor!.email!,
                      ),
                    if (_debtor!.address != null)
                      _InfoChip(
                        icon: Icons.location_on_outlined,
                        label: _debtor!.address!,
                      ),
                    if (_debtor!.employerBusiness != null)
                      _InfoChip(
                        icon: Icons.business_outlined,
                        label: _debtor!.employerBusiness!,
                      ),
                  ],
                ),

                if (_debtor!.notes != null && _debtor!.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      _debtor!.notes!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textBody,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Divider(),

          // ── Cases list ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(
              'ALL CASES (${cases.length})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
          ),

          Expanded(
            child: cases.isEmpty
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
                            border: Border.all(
                              color: AppColors.border,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.cases_outlined,
                            size: 30,
                            color: AppColors.borderMid,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No cases for this debtor',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHead,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Cases against this debtor will appear here.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: cases.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _CaseCard(caseModel: cases[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textBody),
          ),
        ],
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  final CaseModel caseModel;
  const _CaseCard({required this.caseModel});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _statusColors(caseModel.status);
    final isOverdue =
        caseModel.deadline != null &&
        caseModel.deadline!.isBefore(DateTime.now()) &&
        !caseModel.status.toLowerCase().contains('closed');

    return Container(
      padding: const EdgeInsets.all(16),
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
              Text(
                caseModel.caseNumber,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  caseModel.status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              if (isOverdue) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
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
              const Spacer(),
              Text(
                'RWF ${caseModel.outstandingAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.statusRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            caseModel.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textHead,
            ),
          ),
          if (caseModel.description != null &&
              caseModel.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              caseModel.description!,
              style: const TextStyle(fontSize: 12, color: AppColors.textBody),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _MetaTag(Icons.flag_outlined, caseModel.priority),
              const SizedBox(width: 12),
              _MetaTag(Icons.signal_cellular_alt, caseModel.difficulty),
              if (caseModel.deadline != null) ...[
                const SizedBox(width: 12),
                _MetaTag(
                  Icons.calendar_today,
                  'Due ${DateFormat('dd MMM yyyy').format(caseModel.deadline!)}',
                ),
              ],
              if (caseModel.caseType != null) ...[
                const SizedBox(width: 12),
                _MetaTag(Icons.category_outlined, caseModel.caseType!),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static (Color, Color) _statusColors(String status) {
    switch (status) {
      case 'Open':
        return (AppColors.statusBlueBg, AppColors.statusBlue);
      case 'In Progress':
        return (AppColors.statusAmberBg, AppColors.statusAmber);
      case 'Closed - Recovered':
        return (AppColors.statusGreenBg, AppColors.statusGreen);
      case 'Closed - Unrecovered':
        return (AppColors.statusRedBg, AppColors.statusRed);
      default:
        return (AppColors.statusGrayBg, AppColors.statusGray);
    }
  }
}

class _MetaTag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaTag(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
