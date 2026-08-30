import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/case_model.dart';
import '../models/debtor_model.dart';
import '../models/case_assignment_model.dart';
import '../models/recovery_assignment_model.dart';
import '../repositories/case_repository.dart';
import '../repositories/debtor_repository.dart';
import '../repositories/recovery_assignment_repository.dart';

class RecoveryProvider extends ChangeNotifier {
  final CaseRepository _caseRepo;
  final DebtorRepository _debtorRepo;
  final RecoveryAssignmentRepository _recoveryAssignmentRepo;

  List<CaseModel> _cases = [];
  List<CaseModel> _clientCases = [];   // Cases for a specific client
  List<CaseModel> _debtorCases = [];  // Cases for a specific debtor
  List<DebtorModel> _debtors = [];
  List<DebtorModel> _clientDebtors = []; // Debtors for a specific client
  List<DebtorModel> _debtorSearchResults = [];
  Map<String, int> _caseCountByDebtor = {}; // debtorId -> case count (all clients)

  ClientCaseStats? _clientStats;
  List<DebtorCaseStats> _debtorCaseStats = [];
  
  // Detail views
  CaseModel? _currentCase;
  bool _caseDetailsLoaded = false;
  List<CaseAssignmentModel> _assignments = [];
  List<CaseStatusHistoryModel> _statusHistory = [];
  List<CaseSupportingEmployeeModel> _supportingEmployees = [];

  // Phase 3B — Recovery Assignments (Case Pools)
  List<RecoveryAssignmentModel> _recoveryAssignments = [];
  RecoveryAssignmentModel? _currentAssignment;
  List<CaseModel> _assignmentCases = [];
  // Cached per-case batch + status-history look-ups for time-to-recovery.
  final Map<String, DateTime> _caseAddedDates = {};
  final Map<String, List<CaseStatusHistoryModel>> _caseStatusHistoryByCase = {};
  List<Map<String, dynamic>> _officers = [];

  bool _isLoading = false;
  String? _error;

  RecoveryProvider(this._caseRepo, this._debtorRepo, this._recoveryAssignmentRepo);

  List<CaseModel> get cases => _cases;
  List<CaseModel> get clientCases => _clientCases;
  List<CaseModel> get debtorCases => _debtorCases;
  List<DebtorModel> get debtors => _debtors;
  List<DebtorModel> get clientDebtors => _clientDebtors;
  List<DebtorModel> get debtorSearchResults => _debtorSearchResults;
  Map<String, int> get caseCountByDebtor => _caseCountByDebtor;
  ClientCaseStats? get clientStats => _clientStats;
  List<DebtorCaseStats> get debtorCaseStats => _debtorCaseStats;
  List<CaseAssignmentModel> get assignments => _assignments;
  List<CaseStatusHistoryModel> get statusHistory => _statusHistory;
  List<CaseSupportingEmployeeModel> get supportingEmployees => _supportingEmployees;
  CaseModel? get currentCase => _currentCase;
  bool get caseDetailsLoaded => _caseDetailsLoaded;

  // Phase 3B getters
  List<RecoveryAssignmentModel> get recoveryAssignments => _recoveryAssignments;
  RecoveryAssignmentModel? get currentAssignment => _currentAssignment;
  List<CaseModel> get currentAssignmentCases => _assignmentCases;
  bool get hasCurrentAssignment => _currentAssignment != null;
  List<Map<String, dynamic>> get officers => _officers;
  
  bool get isLoading => _isLoading;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Global loads ────────────────────────────────────────────────────────

  Future<void> loadCases() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _cases = await _caseRepo.getAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDebtors() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _debtors = await _debtorRepo.getAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Client-scoped loads ─────────────────────────────────────────────────

  /// Loads cases, debtors, and aggregated stats for a specific client.
  Future<void> loadClientWorkspace(String clientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _clientCases = await _caseRepo.getByClientId(clientId);
      _clientDebtors = await _debtorRepo.getByClientId(clientId);
      _clientStats = await _caseRepo.getClientAggregatedStats(clientId);
      _debtorCaseStats = await _caseRepo.getDebtorCaseStatsForClient(clientId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads only the debtor list for a client (e.g. for the Debtors tab refresh).
  Future<void> loadDebtorsForClient(String clientId) async {
    try {
      _clientDebtors = await _debtorRepo.getByClientId(clientId);
      _debtorCaseStats = await _caseRepo.getDebtorCaseStatsForClient(clientId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Loads only the cases list for a client (e.g. for the Cases tab refresh).
  Future<void> loadCasesForClient(String clientId) async {
    try {
      _clientCases = await _caseRepo.getByClientId(clientId);
      _clientStats = await _caseRepo.getClientAggregatedStats(clientId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Debtor-scoped loads ─────────────────────────────────────────────────

  /// Loads all cases for a specific debtor (for the Debtor Detail screen).
  Future<void> loadCasesForDebtor(String debtorId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _debtorCases = await _caseRepo.getByDebtorId(debtorId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads a debtorId -> case-count map across all clients (for the Debtors
  /// list screen). Lightweight: single aggregate query.
  Future<void> loadCaseCounts() async {
    try {
      _caseCountByDebtor = await _caseRepo.getCaseCountsByDebtor();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Search ──────────────────────────────────────────────────────────────

  Future<void> searchDebtors(String query) async {
    if (query.isEmpty) {
      _debtorSearchResults = [];
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    notifyListeners();

    try {
      _debtorSearchResults = await _debtorRepo.search(query);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Create / Update ────────────────────────────────────────────────────

  Future<void> createDebtor(DebtorModel debtor) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _debtorRepo.create(debtor);
      await loadDebtors();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateDebtor(DebtorModel debtor) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _debtorRepo.update(debtor);
      await loadDebtors();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> createCase(CaseModel caseModel) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _caseRepo.create(caseModel);
      await loadCases();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateCase(CaseModel caseModel) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _caseRepo.update(caseModel);
      await loadCases();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ── Case Details ────────────────────────────────────────────────────────

  Future<void> loadCaseDetails(String caseId) async {
    _isLoading = true;
    _error = null;
    _caseDetailsLoaded = false;
    notifyListeners();

    try {
      // Fetch the case itself by id so the detail view works even when the
      // global `cases` list hasn't been populated (e.g. opened from a client's
      // Cases tab via MaterialPageRoute, where loadCases() wasn't called).
      _currentCase = await _caseRepo.getById(caseId);
      _assignments = await _caseRepo.getAssignments(caseId);
      _statusHistory = await _caseRepo.getStatusHistory(caseId);
      _supportingEmployees = await _caseRepo.getSupportingEmployees(caseId);

      // Best-effort: resolve the case's debtor so CaseDetailScreen's
      // "Debtor: <name>" line resolves even when the global debtors list was
      // never loaded (e.g. opened straight from a client's Cases tab). This was
      // the bug: loadCaseDetails fetched the case but never the debtor, so the
      // name lookup against the empty `_debtors` list was permanently stuck on
      // "Loading...". Non-fatal — a lookup failure leaves the placeholder
      // rather than masking the case fetch above.
      final debtorId = _currentCase?.debtorId;
      if (debtorId != null && !_debtors.any((d) => d.id == debtorId)) {
        try {
          final debtor = await _debtorRepo.getById(debtorId);
          if (debtor != null) _debtors = [..._debtors, debtor];
        } catch (_) {
          // ignore — the screen degrades to 'Loading...' if unresolved.
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _caseDetailsLoaded = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reassignCase(String caseId, String newOwnerId, String? supervisorId, String reason) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _caseRepo.assignCase(caseId, newOwnerId, supervisorId, reason);
      await loadCases();
      await loadCaseDetails(caseId);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> changeCaseStatus(String caseId, String newStatus, String reason) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _caseRepo.changeStatus(caseId, newStatus, reason);
      await loadCases();
      await loadCaseDetails(caseId);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addSupportingEmployee(String caseId, String employeeId) async {
    try {
      await _caseRepo.addSupportingEmployee(caseId, employeeId);
      await loadCaseDetails(caseId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeSupportingEmployee(String caseId, String employeeId) async {
    try {
      await _caseRepo.removeSupportingEmployee(caseId, employeeId);
      await loadCaseDetails(caseId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ── Recovery Assignments (Phase 3B) ────────────────────────────────────────

  Future<String> createRecoveryAssignment({
    required String assignedEmployeeId,
    required String assignedBy,
    required double targetAmount,
    required DateTime startDate,
    required DateTime deadlineDate,
    String? notes,
    required List<String> caseIds,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    String assignmentId = '';
    try {
      final assignment = RecoveryAssignmentModel(
        id: const Uuid().v4(),
        assignedEmployeeId: assignedEmployeeId,
        assignedBy: assignedBy,
        targetAmount: targetAmount,
        startDate: startDate,
        deadlineDate: deadlineDate,
        status: 'Active',
        notes: notes,
      );
      final created =
          await _recoveryAssignmentRepo.create(assignment, caseIds);
      // Refresh the officer's row-scoped list.
      await loadAssignmentsForEmployee(assignedEmployeeId);
      assignmentId = created.id;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
    return assignmentId;
  }

  /// Row-scoped list: an officer only ever sees their own batches.
  Future<void> loadAssignmentsForEmployee(String employeeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _recoveryAssignments =
          await _recoveryAssignmentRepo.getByEmployee(employeeId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads Recovery Officers for the Create-assignment picker.
  Future<void> loadOfficers() async {
    try {
      _officers = await _recoveryAssignmentRepo.listRecoveryOfficers();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// Manager scope: batches whose pooled cases belong to a client.
  Future<void> loadAssignmentsForClient(String clientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _recoveryAssignments =
          await _recoveryAssignmentRepo.getByClient(clientId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads all recovery assignments visible to the current session (used by the
  /// Batches list screen). Scoping (officer = own, manager = all) is enforced in
  /// the repository's [RecoveryAssignmentRepository.getAll].
  Future<void> loadAssignments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _recoveryAssignments = await _recoveryAssignmentRepo.getAll(activeOnly: false);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads a batch's detail: assignment + pooled cases + cached look-ups used
  /// for time-to-recovery computation.
  Future<void> loadRecoveryAssignment(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentAssignment = await _recoveryAssignmentRepo.getById(id);
      _assignmentCases = [];
      _caseAddedDates.clear();
      _caseStatusHistoryByCase.clear();
      final assignment = _currentAssignment;
      if (assignment != null) {
        _assignmentCases =
            await _recoveryAssignmentRepo.getAssignmentCases(id);
        for (final c in _assignmentCases) {
          final added =
              await _recoveryAssignmentRepo.getCaseAddedDate(id, c.id);
          if (added != null) _caseAddedDates[c.id] = added;
          _caseStatusHistoryByCase[c.id] =
              await _caseRepo.getStatusHistory(c.id);
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Verified payments live in Phase 5; until then recovered == 0.0.
  double get currentAssignmentRecoveredAmount => 0.0;

  /// Time-to-recovery for a pooled case = resolved-date − added-date.
  /// Falls back to now − added-date (in-progress) when the case has not yet
  /// reached a closed/resolved status.
  Duration? timeToRecoveryForCase(String caseId) {
    final added = _caseAddedDates[caseId];
    if (added == null) return null;

    final hist = _caseStatusHistoryByCase[caseId] ?? [];
    DateTime? resolved;
    for (final h in hist) {
      if (h.newStatus.toLowerCase().contains('closed')) {
        resolved = h.changeDate;
      }
    }
    if (resolved != null) return resolved.difference(added);
    return DateTime.now().difference(added);
  }

  Future<void> completeAssignment(String id) =>
      _recoveryAssignmentRepo.updateStatus(id, 'Completed');

  Future<void> cancelAssignment(String id) =>
      _recoveryAssignmentRepo.updateStatus(id, 'Cancelled');

  Future<void> removeCaseFromBatch(String assignmentId, String caseId) async {
    await _recoveryAssignmentRepo.removeCaseFromBatch(
      assignmentId,
      caseId,
    );
    await loadRecoveryAssignment(assignmentId);
  }
}
