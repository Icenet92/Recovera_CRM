import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../models/debtor_model.dart';
import '../../../providers/recovery_provider.dart';
import '../../../providers/crm_provider.dart';
import '../../../theme/app_theme.dart';

class DebtorFormDialog extends StatefulWidget {
  final DebtorModel? existing;

  /// When provided (e.g. quick-create from CaseFormDialog or Client Workspace),
  /// the debtor is automatically assigned to this client and the field is locked.
  final String? clientId;
  const DebtorFormDialog({super.key, this.existing, this.clientId});

  @override
  State<DebtorFormDialog> createState() => _DebtorFormDialogState();
}

class _DebtorFormDialogState extends State<DebtorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _employerCtrl;
  late TextEditingController _notesCtrl;
  String _type = 'Company';
  bool _saving = false;

  /// Selected client when the debtor is being created standalone (no
  /// [clientId] / [existing] client lock). Populated from the Client dropdown.
  String? _selectedClientId;

  @override
  void initState() {
    super.initState();
    final d = widget.existing;
    _nameCtrl = TextEditingController(text: d?.name ?? '');
    _phoneCtrl = TextEditingController(text: d?.phone ?? '');
    _emailCtrl = TextEditingController(text: d?.email ?? '');
    _addressCtrl = TextEditingController(text: d?.address ?? '');
    _employerCtrl = TextEditingController(text: d?.employerBusiness ?? '');
    _notesCtrl = TextEditingController(text: d?.notes ?? '');
    if (d != null && DebtorModel.validTypes.contains(d.type)) {
      _type = d.type;
    }

    // Standalone create (no locked client): preload organizations so the
    // Client dropdown has options.
    if (widget.clientId == null && widget.existing == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final crm = context.read<CrmProvider>();
        if (crm.organizations.isEmpty) crm.loadOrganizations();
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _employerCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Determine the clientId: explicit param (locked) > existing (edit) > picked.
    final effectiveClientId =
        widget.clientId ?? widget.existing?.clientId ?? _selectedClientId;
    if (effectiveClientId == null || effectiveClientId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debtor must be assigned to a client.')),
      );
      return;
    }

    setState(() => _saving = true);

    final prov = context.read<RecoveryProvider>();
    try {
      if (widget.existing == null) {
        final newDebtor = DebtorModel(
          id: const Uuid().v4(),
          clientId: effectiveClientId,
          name: _nameCtrl.text.trim(),
          type: _type,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
          employerBusiness: _employerCtrl.text.trim().isEmpty
              ? null
              : _employerCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
        await prov.createDebtor(newDebtor);
        if (mounted) Navigator.of(context).pop(newDebtor);
      } else {
        final upd = widget.existing!.copyWith(
          clientId: effectiveClientId,
          name: _nameCtrl.text.trim(),
          type: _type,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
          employerBusiness: _employerCtrl.text.trim().isEmpty
              ? null
              : _employerCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
        await prov.updateDebtor(upd);
        if (mounted) Navigator.of(context).pop(upd);
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

  @override
  Widget build(BuildContext context) {
    final crmProv = context.watch<CrmProvider>();
    // A client must be picked when creating standalone (no locked clientId and
    // no existing debtor to inherit the client from). On edit the debtor's
    // existing client is locked.
    final showClientPicker = widget.clientId == null && widget.existing == null;

    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'New Debtor' : 'Edit Debtor',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHead,
                ),
              ),
              const SizedBox(height: 24),

              // ── Client selector (only when not pre-assigned) ─────────────────
              if (showClientPicker) ...[
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
                  initialValue: _selectedClientId,
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
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedClientId = v),
                  validator: (v) => v == null ? 'Required' : null,
                  hint: crmProv.organizations.isEmpty
                      ? const Text('Loading clients…')
                      : null,
                ),
                const SizedBox(height: 16),
              ],

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NAME',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Full Name / Company Name',
                          ),
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Required' : null,
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
                          'TYPE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: _type,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          items: DebtorModel.validTypes
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
                          onChanged: (v) => setState(() => _type = v!),
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
                          'PHONE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(
                            hintText: '+250...',
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
                          'EMAIL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                            hintText: 'name@example.com',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                'ADDRESS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(hintText: 'Physical address'),
              ),
              const SizedBox(height: 16),

              const Text(
                'EMPLOYER / BUSINESS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _employerCtrl,
                decoration: const InputDecoration(hintText: 'If applicable'),
              ),
              const SizedBox(height: 16),

              const Text(
                'NOTES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Internal notes about this debtor',
                ),
              ),
              const SizedBox(height: 32),

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
                        : const Text('Save Debtor'),
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
