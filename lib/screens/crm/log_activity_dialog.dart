import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/crm_activity_model.dart';
import '../../providers/crm_provider.dart';

/// Dialog for logging a CRM activity (call, meeting, note, email, etc.)
/// against an org, contact, or lead. Every interaction goes through here —
/// it is the single source of truth, per the build plan.
class LogActivityDialog extends StatefulWidget {
  final String? organizationId;
  final String? contactId;
  final String? leadId;

  const LogActivityDialog({
    super.key,
    this.organizationId,
    this.contactId,
    this.leadId,
  });

  @override
  State<LogActivityDialog> createState() => _LogActivityDialogState();
}

class _LogActivityDialogState extends State<LogActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'Call';
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _outcomeCtrl = TextEditingController();
  DateTime _activityDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    _outcomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final crm = context.read<CrmProvider>();
    final result = await crm.logActivity(
      activityType: _type,
      subject: _subjectCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      outcome: _outcomeCtrl.text.trim().isEmpty
          ? null
          : _outcomeCtrl.text.trim(),
      contactId: widget.contactId,
      leadId: widget.leadId,
      organizationId: widget.organizationId,
      activityDate: _activityDate.toUtc(),
    );

    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop(result);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(crm.error ?? 'Failed to log activity'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Log Activity',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // Type selector
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Activity Type *',
                    border: OutlineInputBorder(),
                  ),
                  items: CrmActivityModel.validTypes
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text('${CrmActivityModel.iconForType(t)}  $t'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _type = v!),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _subjectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Subject *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Subject is required'
                      : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _outcomeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Outcome / Decision',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // Date picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _activityDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setState(() => _activityDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Activity Date',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      DateFormat('dd MMM yyyy').format(_activityDate),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
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
                          : const Text('Log Activity'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
