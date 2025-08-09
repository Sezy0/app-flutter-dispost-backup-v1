class PurchaseHistory {
  final String id;
  final String userId;
  final String planName;
  final double originalPrice;
  final double? discountPrice;
  final double finalPrice;
  final DateTime purchasedAt;
  final String paymentStatus; // 'pending', 'completed', 'failed', 'refunded'
  final String? transactionId;
  final String? paymentMethod;
  final int maxConfigPurchased;
  final int daysPurchased;
  final String? notes;

  PurchaseHistory({
    required this.id,
    required this.userId,
    required this.planName,
    required this.originalPrice,
    this.discountPrice,
    required this.finalPrice,
    required this.purchasedAt,
    required this.paymentStatus,
    this.transactionId,
    this.paymentMethod,
    required this.maxConfigPurchased,
    required this.daysPurchased,
    this.notes,
  });

  factory PurchaseHistory.fromJson(Map<String, dynamic> json) {
    return PurchaseHistory(
      id: json['purchase_id'] ?? '',
      userId: json['user_id'] ?? '',
      planName: json['plan_name'] ?? '',
      originalPrice: (json['original_price'] ?? 0).toDouble(),
      discountPrice: json['discount_price'] != null ? (json['discount_price']).toDouble() : null,
      finalPrice: (json['final_price'] ?? 0).toDouble(),
      purchasedAt: DateTime.parse(json['purchased_at'] ?? DateTime.now().toIso8601String()),
      paymentStatus: json['payment_status'] ?? 'pending',
      transactionId: json['transaction_id'],
      paymentMethod: json['payment_method'],
      maxConfigPurchased: json['max_config_purchased'] ?? 0,
      daysPurchased: json['days_purchased'] ?? 0,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'purchase_id': id,
      'user_id': userId,
      'plan_name': planName,
      'original_price': originalPrice,
      'discount_price': discountPrice,
      'final_price': finalPrice,
      'purchased_at': purchasedAt.toIso8601String(),
      'payment_status': paymentStatus,
      'transaction_id': transactionId,
      'payment_method': paymentMethod,
      'max_config_purchased': maxConfigPurchased,
      'days_purchased': daysPurchased,
      'notes': notes,
    };
  }

  bool get isCompleted => paymentStatus == 'completed';
  bool get isPending => paymentStatus == 'pending';
  bool get isFailed => paymentStatus == 'failed';
  bool get isRefunded => paymentStatus == 'refunded';
  
  // Helper getters untuk backward compatibility
  double get amount => finalPrice;
  DateTime get purchaseDate => purchasedAt;
  String get status => paymentStatus;
  int get maxConfig => maxConfigPurchased;
  int get durationDays => daysPurchased;
}
