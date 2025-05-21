// lib/common/models/kyc.dart
class KYCData {
  final String name;
  final String lastName;
  final String documentType;
  final String documentNumber;
  final String birthDate;
  final String address;
  final String city;
  final String postalCode;
  final String country;
  final String email;
  
  // Nuevos campos requeridos por Stripe
  final String? bankAccountNumber;
  final String? routingNumber;
  final String? iban;
  final String? accountHolderName;
  
  // URLs de documentos
  final String? documentFrontUrl;
  final String? documentBackUrl;
  final String? selfieUrl;
  
  // Estado
  final String status;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? rejectionReason;

  KYCData({
    required this.name,
    required this.lastName,
    required this.documentType,
    required this.documentNumber,
    required this.birthDate,
    required this.address,
    required this.city,
    required this.postalCode,
    required this.country,
    required this.email,
    this.bankAccountNumber,
    this.routingNumber,
    this.iban,
    this.accountHolderName,
    this.documentFrontUrl,
    this.documentBackUrl,
    this.selfieUrl,
    this.status = 'pending',
    this.submittedAt,
    this.approvedAt,
    this.rejectedAt,
    this.rejectionReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'lastName': lastName,
      'documentType': documentType,
      'documentNumber': documentNumber,
      'birthDate': birthDate,
      'address': address,
      'city': city,
      'postalCode': postalCode,
      'country': country,
      'email': email,
      'bankAccountNumber': bankAccountNumber,
      'routingNumber': routingNumber,
      'iban': iban,
      'accountHolderName': accountHolderName,
      'documentFrontUrl': documentFrontUrl,
      'documentBackUrl': documentBackUrl,
      'selfieUrl': selfieUrl,
      'status': status,
      'submittedAt': submittedAt,
      'approvedAt': approvedAt,
      'rejectedAt': rejectedAt,
      'rejectionReason': rejectionReason,
    };
  }
}