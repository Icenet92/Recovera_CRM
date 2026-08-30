import 'package:flutter/foundation.dart';
import '../models/case_model.dart';
import '../models/debtor_model.dart';
import '../repositories/case_repository.dart';
import '../repositories/debtor_repository.dart';
import '../models/case_assignment_model.dart';

class RecoveryProvider extends ChangeNotifier {
  final CaseRepository _caseRepo;
  final DebtorRepository _debtorRepo;

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
  List<CaseAssignmentModel> _assignments = [];
  List<CaseStatusHistoryModel> _statusHistory = [];
  List<CaseSupportingEmployeeModel> _supportingEmployees = [];

  bool _isLoading = false;
  String? _error;

  RecoveryProvider(this._caseRepo, this._debtorRepo);

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
    notifyListeners();

    try {
      _assignments = await _caseRepo.getAssignments(caseId);
      _statusHistory = await _caseRepo.getStatusHistory(caseId);
      _supportingEmployees = await _caseRepo.getSupportingEmployees(caseId);
    } catch (e) {
      _error = e.toString();
    } finally {
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
}
