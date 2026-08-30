import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/recovery_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../models/case_model.dart';

class CloseCaseDialog extends StatefulWidget {
  final CaseModel caseModel;
  final bool isReopening;
  const CloseCaseDialog({
    super.key,
    required this.caseModel,
    this.isReopening = false,
  });

  @override
  State<CloseCaseDialog> createState() => _CloseCaseDialogState();
}

class _CloseCaseDialogState extends State<CloseCaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  String _status = 'Closed - Recovered';
  bool _saving = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final newStatus = widget.isReopening ? 'Open' : _status;
      await context.read<RecoveryProvider>().changeCaseStatus(
        widget.caseModel.id,
        newStatus,
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
              Text(
                widget.isReopening ? 'Reopen Case' : 'Close Case',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHead,
                ),
              ),
              const SizedBox(height: 24),

              if (!widget.isReopening) ...[
                const Text(
                  'CLOSE STATUS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  items:
                      [
                            'Closed - Recovered',
                            'Closed - Unrecoverable',
                            'Closed - Settled',
                            'Closed - Legal Action',
                          ]
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                t,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _status = v!),
                ),
                const SizedBox(height: 16),
              ],

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
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: widget.isReopening
                      ? 'Reason for reopening'
                      : 'Reason for closing',
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
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.isReopening
                          ? AppColors.navy
                          : AppColors.statusRed,
                    ),
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
                        : Text(
                            widget.isReopening
                                ? 'Confirm Reopen'
                                : 'Confirm Close',
                          ),
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
