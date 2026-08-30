import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/recovery_provider.dart';
import '../theme/app_theme.dart';

/// A searchable dropdown for picking a Recovery Officer.
///
/// Shows "Full Name — Job Title" per option (Full Name falls back to the
/// username when the employee record has no name, and Job Title falls back to
/// "No title" when the position/role is unknown). The value reported back
/// through [onChanged] / the enclosing [FormFieldState] is the officer's user
/// id — the same id stored in `recovery_assignments.assigned_employee_id` and
/// `case_assignments.employee_id` (see [RecoveryAssignmentModel] docs), which is
/// what the repositories expect.
///
/// Reusable across the recovery-assignment create form, the Case Reassign
/// dialog and the Add-Supporting-Officer flow. Implemented as a [FormField] so
/// it participates in `Form` validation (the empty-submission unit test relies
/// on this), and as a *searchable* field (type to filter the officer list)
/// rather than a plain scroll-to-find dropdown.
class OfficerPicker extends FormField<String> {
  OfficerPicker({
    super.key,
    String? value,
    this.onChanged,
    super.validator,
    this.decoration,
    this.autoLoad = true,
  })  : super(
          initialValue: value,
          builder: (FormFieldState<String> field) => _OfficerPickerBody(
            value: field.value,
            errorText: field.errorText,
            onChanged: (id) {
              field.didChange(id);
              onChanged?.call(id);
            },
            decoration: decoration,
            autoLoad: autoLoad,
          ),
        );

  /// Fired with the selected officer's user id (or null when cleared).
  final ValueChanged<String?>? onChanged;
  final InputDecoration? decoration;

  /// When false, skips the lazy `loadOfficers()` call. Widget tests that only
  /// exercise form validation pass [autoLoad: false] to avoid hitting the
  /// FFI-backed repository.
  final bool autoLoad;
}

class _OfficerPickerBody extends StatefulWidget {
  const _OfficerPickerBody({
    required this.value,
    required this.errorText,
    required this.onChanged,
    this.decoration,
    this.autoLoad = true,
  });

  final String? value;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final InputDecoration? decoration;
  final bool autoLoad;

  @override
  State<_OfficerPickerBody> createState() => _OfficerPickerBodyState();
}

class _OfficerPickerBodyState extends State<_OfficerPickerBody> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _open = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final prov = Provider.of<RecoveryProvider>(context, listen: false);
        if (prov.officers.isEmpty) prov.loadOfficers();
      });
    }
    // The selected officer's display name is seeded in [didChangeDependencies]
    // (after officers finish loading), not here — at first build the provider
    // list is typically still empty.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-seed whenever the officers list changes (e.g. finished loading).
    _seedText();
  }

  void _seedText() {
    final v = widget.value;
    if (v == null || v.isEmpty) return;
    final prov = context.read<RecoveryProvider>();
    final o = _findOfficer(prov.officers, v);
    if (o == null) return; // officers not loaded yet -> keep current text.
    final name = _displayName(o);
    if (_ctrl.text != name) {
      _ctrl.text = name;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  static Map<String, dynamic>? _findOfficer(
    List<Map<String, dynamic>> officers,
    String id,
  ) {
    for (final o in officers) {
      if (o['id'] == id) return o;
    }
    return null;
  }

  static String _jobTitle(Map<String, dynamic> o) {
    final job = (o['job_title'] as String? ?? o['position'] as String? ?? '')
        .trim();
    return job.isEmpty ? 'No title' : job;
  }

  static String _displayName(Map<String, dynamic> o) {
    final first = (o['first_name'] as String? ?? '').trim();
    final last = (o['last_name'] as String? ?? '').trim();
    final job = _jobTitle(o);
    final name = '$first $last'.trim();
    if (name.isEmpty) {
      return o['username'] as String? ?? o['id'] as String? ?? '';
    }
    return '$name — $job';
  }

  List<Map<String, dynamic>> _matches(List<Map<String, dynamic>> officers) {
    final q = _ctrl.text.toLowerCase();
    if (q.isEmpty) return officers;
    return officers.where((o) {
      final target = _displayName(o).toLowerCase();
      final user = (o['username'] as String? ?? '').toLowerCase();
      final job = _jobTitle(o).toLowerCase();
      return target.contains(q) || user.contains(q) || job.contains(q);
    }).toList();
  }

  void _select(Map<String, dynamic> o) {
    _ctrl.text = _displayName(o);
    _focus.unfocus();
    widget.onChanged(o['id'] as String);
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    // watch so the field rebuilds when the FFI-backed officers load.
    final officers = context.watch<RecoveryProvider>().officers;
    final matches = _open ? _matches(officers) : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          decoration: (widget.decoration ?? const InputDecoration()).copyWith(
            errorText: widget.errorText,
            hintText: widget.decoration?.hintText ?? 'Search officer…',
            suffixIcon:
                widget.decoration?.suffixIcon ??
                const Icon(Icons.search, size: 18),
          ),
          onTap: () => setState(() => _open = true),
          onChanged: (_) => setState(() {}), // refresh filtered list
          onSubmitted: (_) {
            if (matches.length == 1) _select(matches.first);
            _focus.unfocus();
          },
        ),
        if (_open)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: matches.isNotEmpty
                ? ListView.separated(
                    shrinkWrap: true,
                    itemCount: matches.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: AppColors.border),
                    itemBuilder: (BuildContext context, int i) {
                      final o = matches[i];
                      return ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        title: Text(
                          _displayName(o),
                          style: const TextStyle(fontSize: 13),
                        ),
                        onTap: () => _select(o),
                      );
                    },
                  )
                : const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'No officers found',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
          ),
      ],
    );
  }
}
