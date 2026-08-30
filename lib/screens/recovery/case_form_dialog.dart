import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../models/case_model.dart';
import '../../../models/debtor_model.dart';
import '../../../providers/recovery_provider.dart';
import '../../../providers/crm_provider.dart';
import '../../../theme/app_theme.dart';
import 'debtor_form_dialog.dart';

class CaseFormDialog extends StatefulWidget {
  final CaseModel? existing;

  /// When provided, the debtor dropdown is pre-filtered to this client and
  /// the client selector is locked.
  final String? initialClientId;
  const CaseFormDialog({super.key, this.existing, this.initialClientId});

  @override
  State<CaseFormDialog> createState() => _CaseFormDialogState();
}

class _CaseFormDialogState extends State<CaseFormDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedOrgId;
  String? _selectedDebtorId;
  String _priority = 'Medium';
  String _difficulty = 'Medium';

  late TextEditingController _refCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _typeCtrl;
  late TextEditingController _principalCtrl;
  late TextEditingController _interestCtrl;
  late TextEditingController _penaltiesCtrl;
  late TextEditingController _feesCtrl;

  bool _saving = false;

  /// Debtors filtered to the currently selected client.
  List<DebtorModel> _filteredDebtors = [];

  /// Sentinel value surfaced as a "+ New Debtor" option inside the debtor
  /// dropdown so a debtor can be created inline even when none exist yet.
  static const String _createNewDebtorSentinel = '__create_new_debtor__';

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _selectedOrgId = c?.organizationId ?? widget.initialClientId;
    _selectedDebtorId = c?.debtorId;
    _priority = c?.priority ?? 'Medium';
    _difficulty = c?.difficulty ?? 'Medium';

    _refCtrl = TextEditingController(text: c?.clientReference ?? '');
    _titleCtrl = TextEditingController(text: c?.title ?? '');
    _descCtrl = TextEditingController(text: c?.description ?? '');
    _typeCtrl = TextEditingController(text: c?.caseType ?? '');

    _principalCtrl = TextEditingController(
      text: c?.principal.toString() ?? '0',
    );
    _interestCtrl = TextEditingController(text: c?.interest.toString() ?? '0');
    _penaltiesCtrl = TextEditingController(
      text: c?.penalties.toString() ?? '0',
    );
    _feesCtrl = TextEditingController(text: c?.fees.toString() ?? '0');

    // Ensure organizations and debtors are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final crm = context.read<CrmProvider>();
      crm.loadOrganizations();
      // If editing or initialClientId provided, filter debtors for that client
      if (_selectedOrgId != null) {
        _refreshDebtorsForClient(_selectedOrgId!);
      } else {
        context.read<RecoveryProvider>().loadDebtors();
      }
    });
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _typeCtrl.dispose();
    _principalCtrl.dispose();
    _interestCtrl.dispose();
    _penaltiesCtrl.dispose();
    _feesCtrl.dispose();
    super.dispose();
  }

  /// Reload the debtor list, filtered to [clientId].
  void _refreshDebtorsForClient(String clientId) async {
    final recProv = context.read<RecoveryProvider>();
    // Load debtors scoped to this client via the repository
    await recProv.loadDebtorsForClient(clientId);
    if (!mounted) return;
    setState(() {
      _filteredDebtors = recProv.clientDebtors;
      // If the previously selected debtor is not in the filtered list, clear it
      if (_selectedDebtorId != null &&
          !_filteredDebtors.any((d) => d.id == _selectedDebtorId)) {
        _selectedDebtorId = null;
      }
    });
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOrgId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a client.')));
      return;
    }
    if (_selectedDebtorId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a debtor.')));
      return;
    }

    setState(() => _saving = true);
    final prov = context.read<RecoveryProvider>();

    try {
      final p = double.tryParse(_principalCtrl.text) ?? 0.0;
      final i = double.tryParse(_interestCtrl.text) ?? 0.0;
      final pn = double.tryParse(_penaltiesCtrl.text) ?? 0.0;
      final f = double.tryParse(_feesCtrl.text) ?? 0.0;
      final total = p + i + pn + f;

      if (widget.existing == null) {
        final newCase = CaseModel(
          id: const Uuid().v4(),
          caseNumber: '', // Generated in repo
          organizationId: _selectedOrgId!,
          debtorId: _selectedDebtorId!,
          clientReference: _refCtrl.text.trim().isEmpty
              ? null
              : _refCtrl.text.trim(),
          title: _titleCtrl.text.trim(),
          caseType: _typeCtrl.text.trim().isEmpty
              ? null
              : _typeCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          priority: _priority,
          status: 'Open',
          dateReceived: DateTime.now(),
          principal: p,
          interest: i,
          penalties: pn,
          fees: f,
          totalClaim: total,
          difficulty: _difficulty,
        );
        await prov.createCase(newCase);
        if (mounted) Navigator.of(context).pop();
      } else {
        final upd = widget.existing!.copyWith(
          organizationId: _selectedOrgId!,
          debtorId: _selectedDebtorId!,
          clientReference: _refCtrl.text.trim().isEmpty
              ? null
              : _refCtrl.text.trim(),
          title: _titleCtrl.text.trim(),
          caseType: _typeCtrl.text.trim().isEmpty
              ? null
              : _typeCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          priority: _priority,
          principal: p,
          interest: i,
          penalties: pn,
          fees: f,
          totalClaim: total,
          difficulty: _difficulty,
        );
        await prov.updateCase(upd);
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  void _createNewDebtor() async {
    // Quick-create debtor: pass the current client so the debtor is auto-assigned
    if (_selectedOrgId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a client first.')));
      return;
    }
    final newDebtor = await showDialog<DebtorModel>(
      context: context,
      builder: (_) => DebtorFormDialog(clientId: _selectedOrgId),
    );
    if (newDebtor != null) {
      // Refresh the filtered list and auto-select the new debtor
      _refreshDebtorsForClient(_selectedOrgId!);
      setState(() {
        _selectedDebtorId = newDebtor.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final crmProv = context.watch<CrmProvider>();
    final recProv = context.watch<RecoveryProvider>();
    final bool clientLocked = widget.initialClientId != null;
    final displayDebtors = _selectedOrgId != null
        ? _filteredDebtors
        : recProv.debtors;

    return Dialog(
      child: Container(
        width: 700,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              widget.existing == null ? 'New Case' : 'Edit Case',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textHead,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CLIENT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedOrgId,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                  items: crmProv.organizations
                                      .map(
                                        (o) => DropdownMenuItem(
                                          value: o.id,
                                          child: Text(
                                            o.companyName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: clientLocked
                                      ? null
                                      : (v) {
                                          setState(() {
                                            _selectedOrgId = v;
                                            _selectedDebtorId =
                                                null; // Clear debtor when client changes
                                            _filteredDebtors = [];
                                          });
                                          if (v != null) {
                                            _refreshDebtorsForClient(v);
                                          }
                                        },
                                  validator: (v) =>
                                      v == null ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'DEBTOR',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    if (_selectedOrgId != null)
                                      InkWell(
                                        onTap: _createNewDebtor,
                                        child: const Text(
                                          '+ New',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.navy,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedDebtorId,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                  items: [
                                    ...displayDebtors.map(
                                      (d) => DropdownMenuItem(
                                        value: d.id,
                                        child: Text(
                                          d.name,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ),
                                    // Inline quick-create: opens the debtor form
                                    // pre-locked to the currently selected client.
                                    if (_selectedOrgId != null)
                                      DropdownMenuItem(
                                        value: _createNewDebtorSentinel,
                                        child: Row(
                                          children: const [
                                            Icon(
                                              Icons.add,
                                              size: 16,
                                              color: AppColors.navy,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              '+ New Debtor',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors.navy,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                  onChanged: _selectedOrgId == null
                                      ? null
                                      : (v) {
                                          if (v == _createNewDebtorSentinel) {
                                            _createNewDebtor();
                                          } else {
                                            setState(
                                              () => _selectedDebtorId = v,
                                            );
                                          }
                                        },
                                  validator: (v) =>
                                      v == null ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CASE TITLE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _titleCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. Unpaid Q3 Invoices',
                                  ),
                                  validator: (v) =>
                                      v!.trim().isEmpty ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CLIENT REF',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _refCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'Optional',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CASE TYPE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _typeCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. Corporate Default',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PRIORITY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  initialValue: _priority,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                  items: ['Low', 'Medium', 'High', 'Critical']
                                      .map(
                                        (t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(
                                            t,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _priority = v!),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DIFFICULTY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  initialValue: _difficulty,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                  items:
                                      [
                                            'Easy',
                                            'Medium',
                                            'Difficult',
                                            'Very Difficult',
                                          ]
                                          .map(
                                            (t) => DropdownMenuItem(
                                              value: t,
                                              child: Text(
                                                t,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (v) =>
                                      setState(() => _difficulty = v!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'DESCRIPTION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Case context...',
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'FINANCIAL DETAILS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHead,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMoneyField(
                              'PRINCIPAL',
                              _principalCtrl,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMoneyField('INTEREST', _interestCtrl),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMoneyField(
                              'PENALTIES',
                              _penaltiesCtrl,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: _buildMoneyField('FEES', _feesCtrl)),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Case'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoneyField(String label, TextEditingController ctrl) {
    return Column(
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
        TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: 'RWF '),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            if (double.tryParse(v) == null) return 'Invalid';
            return null;
          },
        ),
      ],
    );
  }
}
