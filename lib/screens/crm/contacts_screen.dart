import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/crm_provider.dart';
import '../../models/contact_model.dart';
import '../../theme/app_theme.dart';
import 'client_detail_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CrmProvider>().loadOrganizations();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    context.read<CrmProvider>().searchClients(q);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.watch<CrmProvider>();
    final hasQuery = _searchCtrl.text.trim().isNotEmpty;
    final contacts = hasQuery ? crm.contactSearchResults : <ContactModel>[];

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        children: [
          // ── Page header ──────────────────────────────────────────────────
          Container(
            color: AppColors.bgCard,
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contacts', style: AppTypography.pageTitle(context)),
                    const SizedBox(height: 2),
                    const Text(
                      'Search across all client organizations',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),

          // ── Search bar ───────────────────────────────────────────────────
          Container(
            color: AppColors.bgCard,
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search contacts by name, phone, or email…',
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        splashRadius: 16,
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          const Divider(),

          // ── Results ──────────────────────────────────────────────────────
          Expanded(
            child: !hasQuery
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.bgPage,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.border,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.manage_search_rounded,
                            size: 36,
                            color: AppColors.borderMid,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Find any contact',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHead,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Type a name, phone number, or email address above.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : contacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.bgPage,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.border,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person_search_outlined,
                            size: 30,
                            color: AppColors.borderMid,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No contacts found',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.textHead,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Try a different name, phone, or email.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: contacts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final c = contacts[i];
                      final org = crm.organizations
                          .where((o) => o.id == c.organizationId)
                          .firstOrNull;
                      return InkWell(
                        onTap: org != null
                            ? () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ClientDetailScreen(
                                    organizationId: org.id,
                                  ),
                                ),
                              )
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.accentBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Center(
                                  child: Text(
                                    c.firstName.isNotEmpty
                                        ? c.firstName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accent,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          c.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: AppColors.textHead,
                                          ),
                                        ),
                                        if (c.isDecisionMaker) ...[
                                          const SizedBox(width: 6),
                                          const Tooltip(
                                            message: 'Decision Maker',
                                            child: Icon(
                                              Icons.star_rounded,
                                              size: 13,
                                              color: Color(0xFFF59E0B),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${c.roleType}${c.position != null ? " · ${c.position}" : ""}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    if (org != null) ...[
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.business,
                                            size: 11,
                                            color: AppColors.accent,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            org.companyName,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.accent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (c.phone != null)
                                    Text(
                                      c.phone!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textBody,
                                      ),
                                    ),
                                  if (c.email != null)
                                    Text(
                                      c.email!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  if (org != null) ...[
                                    const SizedBox(height: 4),
                                    const Icon(
                                      Icons.chevron_right,
                                      size: 16,
                                      color: AppColors.textMuted,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
