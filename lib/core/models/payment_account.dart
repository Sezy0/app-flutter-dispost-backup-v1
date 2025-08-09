class PaymentAccount {
  final String id;
  final String type; // 'ewallet', 'bank', atau 'qris'
  final String provider; // 'shopeepay', 'dana', 'seabank'
  final String accountNumber;
  final String accountName;
  final String? qrCodePath; // path untuk QR code jika ada
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PaymentAccount({
    required this.id,
    required this.type,
    required this.provider,
    required this.accountNumber,
    required this.accountName,
    this.qrCodePath,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'provider': provider,
      'account_number': accountNumber,
      'account_name': accountName,
      'qr_code_path': qrCodePath,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Create from Map (from database)
  factory PaymentAccount.fromMap(Map<String, dynamic> map) {
    return PaymentAccount(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      provider: map['provider'] ?? '',
      accountNumber: map['account_number'] ?? '',
      accountName: map['account_name'] ?? '',
      qrCodePath: map['qr_code_path'],
      isActive: (map['is_active'] ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  // Create from Supabase Map (from RPC function)
  factory PaymentAccount.fromSupabaseMap(Map<String, dynamic> map) {
    return PaymentAccount(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      provider: map['provider'] ?? '',
      accountNumber: map['account_number'] ?? '',
      accountName: map['account_name'] ?? '',
      qrCodePath: map['qr_code_path'],
      isActive: true, // From RPC function, only active accounts are returned
      createdAt: DateTime.now(), // Default for display
      updatedAt: null,
    );
  }

  // Create a copy with updated fields
  PaymentAccount copyWith({
    String? id,
    String? type,
    String? provider,
    String? accountNumber,
    String? accountName,
    String? qrCodePath,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentAccount(
      id: id ?? this.id,
      type: type ?? this.type,
      provider: provider ?? this.provider,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      qrCodePath: qrCodePath ?? this.qrCodePath,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'PaymentAccount(id: $id, type: $type, provider: $provider, accountNumber: $accountNumber, accountName: $accountName, qrCodePath: $qrCodePath, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentAccount &&
        other.id == id &&
        other.type == type &&
        other.provider == provider &&
        other.accountNumber == accountNumber &&
        other.accountName == accountName &&
        other.qrCodePath == qrCodePath &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        type.hashCode ^
        provider.hashCode ^
        accountNumber.hashCode ^
        accountName.hashCode ^
        qrCodePath.hashCode ^
        isActive.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
