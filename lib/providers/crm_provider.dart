import 'package:flutter/foundation.dart';
import '../models/organization_model.dart';
import '../models/contact_model.dart';
import '../models/lead_model.dart';
import '../models/crm_activity_model.dart';
import '../repositories/organization_repository.dart';
import '../repositories/contact_repository.dart';
import '../repositories/lead_repository.dart';
import '../repositories/crm_activity_repository.dart';

class CrmProvider extends ChangeNotifier {
  final OrganizationRepository _orgRepo;
  final ContactRepository _contactRepo;
  final LeadRepository _leadRepo;
  final CrmActivityRepository _activityRepo;

  CrmProvider(
    this._orgRepo,
    this._contactRepo,
    this._leadRepo,
    this._activityRepo,
  );

  // ── State ──────────────────────────────────────────────────────────────────

  List<OrganizationModel> _organizations = [];
  List<OrganizationModel> get organizations => _organizations;

  List<ContactModel> _contacts = [];
  List<ContactModel> get contacts => _contacts;

  List<LeadModel> _leads = [];
  List<LeadModel> get leads => _leads;

  List<CrmActivityModel> _activities = [];
  List<CrmActivityModel> get activities => _activities;

  List<OrganizationModel> _searchResults = [];
  List<OrganizationModel> get searchResults => _searchResults;

  List<ContactModel> _contactSearchResults = [];
  List<ContactModel> get contactSearchResults => _contactSearchResults;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // ── Organizations ──────────────────────────────────────────────────────────

  Future<void> loadOrganizations({String? statusFilter}) async {
    _setLoading(true);
    try {
      _organizations = await _orgRepo.getAll(statusFilter: statusFilter);
      _error = null;
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<OrganizationModel?> createOrganization({
    required String companyName,
    String? registrationNumber,
    String? industry,
    String? address,
    String? phone,
    String? email,
    String status = 'Prospect',
    String? accountManagerEmployeeId,
    DateTime? dateAcquired,
    String? leadSource,
    DateTime? contractStartDate,
    DateTime? contractEndDate,
    String? notes,
  }) async {
    try {
      final org = await _orgRepo.create(
        companyName: companyName,
        registrationNumber: registrationNumber,
        industry: industry,
        address: address,
        phone: phone,
        email: email,
        status: status,
        accountManagerEmployeeId: accountManagerEmployeeId,
        dateAcquired: dateAcquired,
        leadSource: leadSource,
        contractStartDate: contractStartDate,
        contractEndDate: contractEndDate,
        notes: notes,
      );
      _organizations = [org, ..._organizations];
      _error = null;
      notifyListeners();
      return org;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<OrganizationModel?> updateOrganization(OrganizationModel org) async {
    try {
      final updated = await _orgRepo.update(org);
      final idx = _organizations.indexWhere((o) => o.id == org.id);
      if (idx != -1) _organizations[idx] = updated;
      _error = null;
      notifyListeners();
      return updated;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteOrganization(String id) async {
    try {
      await _orgRepo.softDelete(id);
      _organizations.removeWhere((o) => o.id == id);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> searchClients(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      _contactSearchResults = [];
      notifyListeners();
      return;
    }
    try {
      _searchResults = await _orgRepo.search(query);
      _contactSearchResults = await _contactRepo.search(query);
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  // ── Contacts ───────────────────────────────────────────────────────────────

  Future<void> loadContactsForOrg(String orgId) async {
    _setLoading(true);
    try {
      _contacts = await _contactRepo.getByOrganization(orgId);
      _error = null;
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<ContactModel?> createContact({
    required String organizationId,
    required String firstName,
    required String lastName,
    String? position,
    String? phone,
    String? email,
    String? preferredChannel,
    String roleType = 'Primary',
    bool isDecisionMaker = false,
    String? notes,
    DateTime? nextFollowupDate,
  }) async {
    try {
      final contact = await _contactRepo.create(
        organizationId: organizationId,
        firstName: firstName,
        lastName: lastName,
        position: position,
        phone: phone,
        email: email,
        preferredChannel: preferredChannel,
        roleType: roleType,
        isDecisionMaker: isDecisionMaker,
        notes: notes,
        nextFollowupDate: nextFollowupDate,
      );
      _contacts = [contact, ..._contacts];
      _error = null;
      notifyListeners();
      return contact;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<ContactModel?> updateContact(ContactModel contact) async {
    try {
      final updated = await _contactRepo.update(contact);
      final idx = _contacts.indexWhere((c) => c.id == contact.id);
      if (idx != -1) _contacts[idx] = updated;
      _error = null;
      notifyListeners();
      return updated;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  // ── Leads ──────────────────────────────────────────────────────────────────

  Future<void> loadLeads() async {
    _setLoading(true);
    try {
      _leads = await _leadRepo.getAll();
      _error = null;
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<LeadModel?> createLead({
    String? organizationId,
    required String title,
    String? ownerEmployeeId,
    String? source,
    double? expectedValue,
    String currency = 'RWF',
    String status = 'New',
    String? nextAction,
    DateTime? followupDate,
    String? notes,
  }) async {
    try {
      final lead = await _leadRepo.create(
        organizationId: organizationId,
        title: title,
        ownerEmployeeId: ownerEmployeeId,
        source: source,
        expectedValue: expectedValue,
        currency: currency,
        status: status,
        nextAction: nextAction,
        followupDate: followupDate,
        notes: notes,
      );
      _leads = [lead, ..._leads];
      _error = null;
      notifyListeners();
      return lead;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> moveLeadStage(String leadId, String newStatus) async {
    try {
      final updated = await _leadRepo.moveToStage(leadId, newStatus);
      final idx = _leads.indexWhere((l) => l.id == leadId);
      if (idx != -1) _leads[idx] = updated;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<LeadModel?> updateLead(LeadModel lead) async {
    try {
      final updated = await _leadRepo.update(lead);
      final idx = _leads.indexWhere((l) => l.id == lead.id);
      if (idx != -1) _leads[idx] = updated;
      _error = null;
      notifyListeners();
      return updated;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  // ── Activities ─────────────────────────────────────────────────────────────

  Future<void> loadActivitiesForOrg(String orgId) async {
    _setLoading(true);
    try {
      _activities = await _activityRepo.getForOrganization(orgId);
      _error = null;
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<CrmActivityModel?> logActivity({
    required String activityType,
    required String subject,
    String? description,
    String? outcome,
    String? contactId,
    String? leadId,
    String? organizationId,
    DateTime? activityDate,
  }) async {
    try {
      final activity = await _activityRepo.log(
        activityType: activityType,
        subject: subject,
        description: description,
        outcome: outcome,
        contactId: contactId,
        leadId: leadId,
        organizationId: organizationId,
        activityDate: activityDate,
      );
      _activities = [activity, ..._activities];
      _error = null;
      notifyListeners();
      return activity;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('PermissionException')) {
      return msg.replaceFirst('PermissionException: ', '');
    }
    return msg.replaceFirst('Exception: ', '');
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Helper: leads grouped by pipeline stage for Kanban.
  Map<String, List<LeadModel>> get leadsByStage {
    final map = <String, List<LeadModel>>{};
    for (final stage in LeadModel.pipelineStages) {
      map[stage] = _leads.where((l) => l.status == stage).toList();
    }
    return map;
  }
}
