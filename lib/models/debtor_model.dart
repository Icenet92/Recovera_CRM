class DebtorModel {
  final String id;
  final String clientId; // FK → organizations.id — the client this debtor belongs to
  final String name;
  final String type; // Individual, Company, Agent, Employee, Supplier, Other
  final String? phone;
  final String? email;
  final String? address;
  final String? employerBusiness;
  final String? notes;

  const DebtorModel({
    required this.id,
    required this.clientId,
    required this.name,
    required this.type,
    this.phone,
    this.email,
    this.address,
    this.employerBusiness,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'name': name,
      'type': type,
      'phone': phone,
      'email': email,
      'address': address,
      'employer_business': employerBusiness,
      'notes': notes,
    };
  }

  factory DebtorModel.fromMap(Map<String, dynamic> map) {
    return DebtorModel(
      id: map['id'] as String,
      clientId: map['client_id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      employerBusiness: map['employer_business'] as String?,
      notes: map['notes'] as String?,
    );
  }

  DebtorModel copyWith({
    String? clientId,
    String? name,
    String? type,
    String? phone,
    String? email,
    String? address,
    String? employerBusiness,
    String? notes,
  }) {
    return DebtorModel(
      id: id,
      clientId: clientId ?? this.clientId,
      name: name ?? this.name,
      type: type ?? this.type,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      employerBusiness: employerBusiness ?? this.employerBusiness,
      notes: notes ?? this.notes,
    );
  }

  static const List<String> validTypes = [
    'Individual',
    'Company',
    'Agent',
    'Employee',
    'Supplier',
    'Other'
  ];
}
