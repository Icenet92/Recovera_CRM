import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/case_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/recovery_provider.dart';
import '../../../theme/app_theme.dart';

/// Phase 3B — Create a Recovery Assignment (a "Case Pool") for one officer.
///
/// Presented as a modal [AlertDialog] from [CasesScreen]. The target amount is
/// auto-suggested from the sum of the selected cases' outstanding balances and
/// can be edited; the deadline defaults to ~14 days out.
class RecoveryAssignmentForm extends StatefulWidget {
  /// Called with the new assignment id once the batch is created.
  final void Function(String assignmentId)? onCreated;

  /// When false, skips the lazy officer/case lookup. Widget tests that only
  /// exercise form validation pass [autoLoad: false] to avoid hitting the
  /// (FFI-backed) repository.
  final bool autoLoad;

  const RecoveryAssignmentForm({
    super.key,
    this.onCreated,
    this.autoLoad = true,
  });

  @override
  State<RecoveryAssignmentForm> createState() => _RecoveryAssignmentFormState();
}

class _RecoveryAssignmentFormState extends State<RecoveryAssignmentForm> {
  final _formKey = GlobalKey<FormState>();
  final _targetCtrl = TextEditingController();
  final _deadlineCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _submitted = false;
  bool _isSaving = false;
  bool _targetDirty = false;
  String? _selectedOfficerId;
  DateTime? _deadline;
  final Set<String> _caseIds = {};

  @override
  void initState() {
    super.initState();
    // Once the user types in the target, stop auto-suggesting on case toggles.
    _targetCtrl.addListener(() => _targetDirty = true);
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final prov = context.read<RecoveryProvider>();
        if (prov.officers.isEmpty) prov.loadOfficers();
        if (prov.cases.isEmpty) prov.loadCases();
      });
    }
  }

  List<CaseModel> _selectedCases(RecoveryProvider prov) =>
      prov.cases.where((c) => _caseIds.contains(c.id)).toList();

  void _toggleCase(bool? value, CaseModel c) {
    setState(() {
      if (value == true) {
        _caseIds.add(c.id);
      } else {
        _caseIds.remove(c.id);
      }
    });
    _recomputeTarget();
  }

  /// Auto-suggests the target from selected cases' outstanding balances, but
  /// only while the user hasn't manually edited the field.
  void _recomputeTarget() {
    if (_targetDirty) return;
    final prov = context.read<RecoveryProvider>();
    final total = _selectedCases(prov).fold<double>(
      0.0,
      (s, c) => s + c.outstandingAmount,
    );
    _targetCtrl.text = total.toStringAsFixed(0);
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _deadline = picked;
      _deadlineCtrl.text = picked.toIso8601String().split('T').first;
    });
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_selectedOfficerId == null || _selectedOfficerId!.isEmpty) return;
    if (_caseIds.isEmpty) return;
    if (_deadline == null) return;

    double target = 0;
    try {
      target = double.parse(_targetCtrl.text);
    } catch (_) {}
    if (target <= 0) return;

    final prov = context.read<RecoveryProvider>();
    final session = context.read<AuthProvider>().currentSession;
    setState(() => _isSaving = true);
    try {
      final id = await prov.createRecoveryAssignment(
        assignedEmployeeId: _selectedOfficerId!,
        assignedBy: session?.userId ?? '',
        targetAmount: target,
        startDate: DateTime.now(),
        deadlineDate: _deadline!,
        notes: _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        caseIds: _caseIds.toList(),
      );
      widget.onCreated?.call(id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.statusRedBg,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    _deadlineCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<RecoveryProvider>();
    final openCases = prov.cases
        .where((c) => !c.status.toLowerCase().contains('closed'))
        .toList();
    final selectedCases = _selectedCases(prov);
    final autoTarget = selectedCases.fold<double>(
      0.0,
      (s, c) => s + c.outstandingAmount,
    );

    return AlertDialog(
      title: const Text('Create Recovery Assignment'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Officer ───────────────────────────────────────────────
                DropdownButtonFormField<String>(
                  initialValue: _selectedOfficerId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Recovery Officer',
                  ),
                  items: prov.officers
                      .map(
                        (o) => DropdownMenuItem<String>(
                          value: o['id'] as String,
                          child: Text(o['username'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedOfficerId = v),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Please select an officer'
                      : null,
                ),
                const SizedBox(height: 20),
                // ── Cases ─────────────────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Pool Cases', style: AppTypography.tableHeader(context)),
                    const SizedBox(height: 8),
                    if (openCases.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          prov.cases.isEmpty
                              ? 'No cases loaded yet.'
                              : 'No open cases available.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    else
                      SizedBox(
                        height: 224,
                        child: ListView(
                          children: openCases
                              .map(
                                (c) => CheckboxListTile(
                                  value: _caseIds.contains(c.id),
                                  onChanged: (v) => _toggleCase(v, c),
                                  title: Text(
                                    c.caseNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  subtitle: Text(c.title),
                                  dense: true,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    if (_submitted && _caseIds.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Select at least one case',
                          style: TextStyle(
                            color: AppColors.statusRed,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                // ── Target (auto-suggested) ────────────────────────────────
                TextFormField(
                  controller: _targetCtrl,
                  decoration: InputDecoration(
                    labelText: 'Target Amount (RWF)',
                    hintText: _targetDirty
                        ? null
                        : 'Auto-suggested: ${autoTarget.toStringAsFixed(0)}',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a target amount';
                    double x;
                    try {
                      x = double.parse(v);
                    } catch (_) {
                      return 'Enter a valid number';
                    }
                    if (x <= 0) return 'Target must be greater than 0';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // ── Deadline ───────────────────────────────────────────────
                TextFormField(
                  controller: _deadlineCtrl,
                  decoration: const InputDecoration(labelText: 'Deadline'),
                  readOnly: true,
                  onTap: _pickDeadline,
                  validator: (_) =>
                      _deadline == null ? 'Select a deadline' : null,
                ),
                const SizedBox(height: 20),
                // ── Notes ─────────────────────────────────────────────────
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  maxLines: 3,
                ),
                if (prov.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      prov.error!,
                      style: TextStyle(color: AppColors.statusRed),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save, size: 18),
          label: _isSaving ? const Text('Saving…') : const Text('Save Batch'),
        ),
      ],
    );
  }
}
