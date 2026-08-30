import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/contact_model.dart';
import '../../providers/crm_provider.dart';

/// Dialog for creating or editing a contact linked to an organization.
class ContactFormDialog extends StatefulWidget {
  final String organizationId;
  final ContactModel? existing; // null = create, non-null = edit

  const ContactFormDialog({
    super.key,
    required this.organizationId,
    this.existing,
  });

  @override
  State<ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends State<ContactFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _positionCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _notesCtrl;
  late String _roleType;
  late String? _preferredChannel;
  late bool _isDecisionMaker;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _firstNameCtrl = TextEditingController(text: e?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: e?.lastName ?? '');
    _positionCtrl = TextEditingController(text: e?.position ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _roleType = e?.roleType ?? 'Primary';
    _preferredChannel = e?.preferredChannel;
    _isDecisionMaker = e?.isDecisionMaker ?? false;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _positionCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final crm = context.read<CrmProvider>();
    ContactModel? result;

    if (widget.existing == null) {
      result = await crm.createContact(
        organizationId: widget.organizationId,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        position: _positionCtrl.text.trim().isEmpty
            ? null
            : _positionCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        preferredChannel: _preferredChannel,
        roleType: _roleType,
        isDecisionMaker: _isDecisionMaker,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
    } else {
      result = await crm.updateContact(
        widget.existing!.copyWith(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          position: _positionCtrl.text.trim().isEmpty
              ? null
              : _positionCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          preferredChannel: _preferredChannel,
          roleType: _roleType,
          isDecisionMaker: _isDecisionMaker,
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
          content: Text(crm.error ?? 'Failed to save contact'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    isEdit ? 'Edit Contact' : 'New Contact',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'First Name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Last Name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _positionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Position / Title',
                      border: OutlineInputBorder(),
                    ),
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

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _roleType,
                          decoration: const InputDecoration(
                            labelText: 'Role Type *',
                            border: OutlineInputBorder(),
                          ),
                          items: ContactModel.validRoleTypes
                              .map(
                                (r) =>
                                    DropdownMenuItem(value: r, child: Text(r)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _roleType = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _preferredChannel,
                          decoration: const InputDecoration(
                            labelText: 'Preferred Channel',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('—'),
                            ),
                            ...ContactModel.validChannels.map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _preferredChannel = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Decision Maker'),
                    value: _isDecisionMaker,
                    onChanged: (v) =>
                        setState(() => _isDecisionMaker = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
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
                            : Text(isEdit ? 'Save Changes' : 'Add Contact'),
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
