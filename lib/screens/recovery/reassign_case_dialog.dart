import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/recovery_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../models/case_model.dart';

class ReassignCaseDialog extends StatefulWidget {
  final CaseModel caseModel;
  const ReassignCaseDialog({super.key, required this.caseModel});

  @override
  State<ReassignCaseDialog> createState() => _ReassignCaseDialogState();
}

class _ReassignCaseDialogState extends State<ReassignCaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ownerCtrl =
      TextEditingController(); // In real app, this would be a dropdown of employees
  final _supervisorCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ownerCtrl.text = widget.caseModel.primaryOwnerId ?? '';
    _supervisorCtrl.text = widget.caseModel.supervisorId ?? '';
  }

  @override
  void dispose() {
    _ownerCtrl.dispose();
    _supervisorCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await context.read<RecoveryProvider>().reassignCase(
        widget.caseModel.id,
        _ownerCtrl.text.trim(),
        _supervisorCtrl.text.trim().isEmpty
            ? null
            : _supervisorCtrl.text.trim(),
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

              const Text(
                'NEW OWNER (Employee ID)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _ownerCtrl,
                decoration: const InputDecoration(
                  hintText: 'Enter employee ID',
                ),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              const Text(
                'SUPERVISOR (Employee ID)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _supervisorCtrl,
                decoration: const InputDecoration(hintText: 'Optional'),
              ),
              const SizedBox(height: 16),

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
