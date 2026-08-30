import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/organization_model.dart';
import '../../providers/crm_provider.dart';

/// Dialog for creating or editing an organization (client record).
class ClientFormDialog extends StatefulWidget {
  final OrganizationModel? existing; // null = create, non-null = edit

  const ClientFormDialog({super.key, this.existing});

  @override
  State<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _regCtrl;
  late final TextEditingController _industryCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _sourceCtrl;
  late final TextEditingController _notesCtrl;
  late String _status;
  DateTime? _dateAcquired;
  DateTime? _contractStart;
  DateTime? _contractEnd;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.companyName ?? '');
    _regCtrl = TextEditingController(text: e?.registrationNumber ?? '');
    _industryCtrl = TextEditingController(text: e?.industry ?? '');
    _addressCtrl = TextEditingController(text: e?.address ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _sourceCtrl = TextEditingController(text: e?.leadSource ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _status = e?.status ?? 'Prospect';
    _dateAcquired = e?.dateAcquired;
    _contractStart = e?.contractStartDate;
    _contractEnd = e?.contractEndDate;
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _regCtrl,
      _industryCtrl,
      _addressCtrl,
      _phoneCtrl,
      _emailCtrl,
      _sourceCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(
    BuildContext context,
    DateTime? current,
    ValueChanged<DateTime> onPicked,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final crm = context.read<CrmProvider>();
    OrganizationModel? result;

    if (widget.existing == null) {
      result = await crm.createOrganization(
        companyName: _nameCtrl.text.trim(),
        registrationNumber: _regCtrl.text.trim().isEmpty
            ? null
            : _regCtrl.text.trim(),
        industry: _industryCtrl.text.trim().isEmpty
            ? null
            : _industryCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        status: _status,
        leadSource: _sourceCtrl.text.trim().isEmpty
            ? null
            : _sourceCtrl.text.trim(),
        dateAcquired: _dateAcquired,
        contractStartDate: _contractStart,
        contractEndDate: _contractEnd,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
    } else {
      result = await crm.updateOrganization(
        widget.existing!.copyWith(
          companyName: _nameCtrl.text.trim(),
          registrationNumber: _regCtrl.text.trim().isEmpty
              ? null
              : _regCtrl.text.trim(),
          industry: _industryCtrl.text.trim().isEmpty
              ? null
              : _industryCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          status: _status,
          leadSource: _sourceCtrl.text.trim().isEmpty
              ? null
              : _sourceCtrl.text.trim(),
          dateAcquired: _dateAcquired,
          contractStartDate: _contractStart,
          contractEndDate: _contractEnd,
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
          content: Text(crm.error ?? 'Failed to save'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _dateTile(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(
          value != null ? DateFormat('dd MMM yyyy').format(value) : '—',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
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
                    isEdit ? 'Edit Client' : 'New Client',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Company Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Company name is required'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _regCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Registration Number',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _industryCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Industry',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Status *',
                            border: OutlineInputBorder(),
                          ),
                          items: OrganizationModel.validStatuses
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
                        child: TextFormField(
                          controller: _sourceCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Lead Source',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _dateTile('Date Acquired', _dateAcquired, () {
                          _pickDate(
                            context,
                            _dateAcquired,
                            (d) => setState(() => _dateAcquired = d),
                          );
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateTile('Contract Start', _contractStart, () {
                          _pickDate(
                            context,
                            _contractStart,
                            (d) => setState(() => _contractStart = d),
                          );
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateTile('Contract End', _contractEnd, () {
                          _pickDate(
                            context,
                            _contractEnd,
                            (d) => setState(() => _contractEnd = d),
                          );
                        }),
                      ),
                    ],
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
                            : Text(isEdit ? 'Save Changes' : 'Create Client'),
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
