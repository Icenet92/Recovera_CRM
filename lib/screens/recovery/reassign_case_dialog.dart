import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/case_model.dart';
import '../../../providers/recovery_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/officer_picker.dart';

/// Modal shown from the Case Detail screen's "Reassign" button.
///
/// Replaces the previous raw "Employee ID" text fields (which had no name
/// lookup and were unsearchable) with [OfficerPicker] dropdowns that show
/// "Full Name — Job Title" and report the officer's user id — the exact
/// value [RecoveryProvider.reassignCase] expects for
/// `cases.primary_owner_id` / `cases.supervisor_id`.
class ReassignCaseDialog extends StatefulWidget {
  final CaseModel caseModel;
  const ReassignCaseDialog({super.key, required this.caseModel});

  @override
  State<ReassignCaseDialog> createState() => _ReassignCaseDialogState();
}

class _ReassignCaseDialogState extends State<ReassignCaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();

  // Selected officer user ids; seeded from the case's current assignment.
  String? _ownerId;
  String? _supervisorId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ownerId = widget.caseModel.primaryOwnerId;
    _supervisorId = widget.caseModel.supervisorId;
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await context.read<RecoveryProvider>().reassignCase(
            widget.caseModel.id,
            _ownerId?.trim() ?? '',
            (_supervisorId?.trim() ?? '').isEmpty ? null : _supervisorId!.trim(),
            _reasonCtrl.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Reassign Case',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHead,
                ),
              ),
              const SizedBox(height: 24),

              // ── New Owner ───────────────────────────────────────────────
              const Text(
                'NEW OWNER (Recovery Officer)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              OfficerPicker(
                value: _ownerId,
                onChanged: (v) => setState(() => _ownerId = v),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                decoration: const InputDecoration(
                  hintText: 'Search officer…',
                ),
              ),
              const SizedBox(height: 16),

              // ── Supervisor (optional) ───────────────────────────────────
              const Text(
                'SUPERVISOR (Recovery Officer)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              OfficerPicker(
                value: _supervisorId,
                onChanged: (v) => setState(() => _supervisorId = v),
                // Optional field — no validator.
                decoration: const InputDecoration(
                  hintText: 'Search officer…',
                ),
              ),
              const SizedBox(height: 16),

              // ── Reason ──────────────────────────────────────────────────
              const Text(
                'REASON',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Reason for reassignment',
                ),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
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
                        : const Text('Confirm'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
