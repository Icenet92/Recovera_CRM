import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/lead_model.dart';
import '../../providers/crm_provider.dart';

/// Dialog for creating or editing a lead.
class LeadFormDialog extends StatefulWidget {
  final LeadModel? existing;
  final String? preselectedOrgId;

  const LeadFormDialog({super.key, this.existing, this.preselectedOrgId});

  @override
  State<LeadFormDialog> createState() => _LeadFormDialogState();
}

class _LeadFormDialogState extends State<LeadFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _valueCtrl;
  late final TextEditingController _nextActionCtrl;
  late final TextEditingController _notesCtrl;
  late String _status;
  late String? _source;
  late String? _orgId;
  DateTime? _followupDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _valueCtrl = TextEditingController(
      text: e?.expectedValue != null
          ? e!.expectedValue!.toStringAsFixed(0)
          : '',
    );
    _nextActionCtrl = TextEditingController(text: e?.nextAction ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _status = e?.status ?? 'New';
    _source = e?.source;
    _orgId = e?.organizationId ?? widget.preselectedOrgId;
    _followupDate = e?.followupDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _valueCtrl.dispose();
    _nextActionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final crm = context.read<CrmProvider>();
    final value = double.tryParse(_valueCtrl.text.replaceAll(',', ''));
    LeadModel? result;

    if (widget.existing == null) {
      result = await crm.createLead(
        organizationId: _orgId,
        title: _titleCtrl.text.trim(),
        source: _source,
        expectedValue: value,
        status: _status,
        nextAction: _nextActionCtrl.text.trim().isEmpty
            ? null
            : _nextActionCtrl.text.trim(),
        followupDate: _followupDate?.toUtc(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
    } else {
      result = await crm.updateLead(
        widget.existing!.copyWith(
          organizationId: _orgId,
          title: _titleCtrl.text.trim(),
          source: _source,
          expectedValue: value,
          status: _status,
          nextAction: _nextActionCtrl.text.trim().isEmpty
              ? null
              : _nextActionCtrl.text.trim(),
          followupDate: _followupDate?.toUtc(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          syncUpdatedAt: DateTime.now().toUtc(),
        ),
      );
    }

    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop(result);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(crm.error ?? 'Failed to save lead'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.watch<CrmProvider>();
    final orgs = crm.organizations;
    final isEdit = widget.existing != null;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? 'Edit Lead' : 'New Lead',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lead Title *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // Organization picker
                  DropdownButtonFormField<String?>(
                    initialValue: orgs.any((o) => o.id == _orgId)
                        ? _orgId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Client / Organization',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('— None (unlinked lead) —'),
                      ),
                      ...orgs.map(
                        (o) => DropdownMenuItem(
                          value: o.id,
                          child: Text(o.companyName),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _orgId = v),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Stage *',
                            border: OutlineInputBorder(),
                          ),
                          items: LeadModel.pipelineStages
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _status = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _source,
                          decoration: const InputDecoration(
                            labelText: 'Source',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('—'),
                            ),
                            ...LeadModel.validSources.map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            ),
                          ],
                          onChanged: (v) => setState(() => _source = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _valueCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Expected Value (RWF)',
                      border: OutlineInputBorder(),
                      prefixText: 'RWF ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _nextActionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Next Action',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            _followupDate ??
                            DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime(2040),
                      );
                      if (picked != null) {
                        setState(() => _followupDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Follow-up Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _followupDate != null
                                ? DateFormat(
                                    'dd MMM yyyy',
                                  ).format(_followupDate!)
                                : '—',
                          ),
                          if (_followupDate != null)
                            GestureDetector(
                              onTap: () => setState(() => _followupDate = null),
                              child: const Icon(Icons.clear, size: 18),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
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
                            : Text(isEdit ? 'Save Changes' : 'Create Lead'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
