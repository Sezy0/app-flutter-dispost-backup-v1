import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dispost_autopost/core/models/purchase_history.dart';

class PurchaseHistoryService {
  static final _supabase = Supabase.instance.client;

  /// Get purchase history for current user
  static Future<List<PurchaseHistory>> getUserPurchaseHistory() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('purchase_history')
          .select('*')
          .eq('user_id', user.id)
          .order('purchased_at', ascending: false);

      return (response as List)
          .map((item) => PurchaseHistory.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to load purchase history: $e');
    }
  }

  /// Get specific purchase by ID
  static Future<PurchaseHistory?> getPurchaseById(String purchaseId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('purchase_history')
          .select('*')
          .eq('purchase_id', purchaseId)
          .eq('user_id', user.id)
          .single();

      return PurchaseHistory.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Create new purchase record
  static Future<PurchaseHistory> createPurchaseRecord({
    required String planName,
    required double originalPrice,
    double? discountPrice,
    required double finalPrice,
    required String paymentStatus,
    String? transactionId,
    String? paymentMethod,
    required int maxConfigPurchased,
    required int daysPurchased,
    String? notes,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final purchaseData = {
        'user_id': user.id,
        'plan_name': planName,
        'original_price': originalPrice,
        'discount_price': discountPrice,
        'final_price': finalPrice,
        'payment_status': paymentStatus,
        'transaction_id': transactionId,
        'payment_method': paymentMethod,
        'max_config_purchased': maxConfigPurchased,
        'days_purchased': daysPurchased,
        'notes': notes,
      };

      final response = await _supabase
          .from('purchase_history')
          .insert(purchaseData)
          .select()
          .single();

      return PurchaseHistory.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create purchase record: $e');
    }
  }

  /// Update purchase status
  static Future<PurchaseHistory> updatePurchaseStatus({
    required String purchaseId,
    required String paymentStatus,
    String? transactionId,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final updateData = <String, dynamic>{
        'payment_status': paymentStatus,
      };

      if (transactionId != null) {
        updateData['transaction_id'] = transactionId;
      }

      final response = await _supabase
          .from('purchase_history')
          .update(updateData)
          .eq('purchase_id', purchaseId)
          .eq('user_id', user.id)
          .select()
          .single();

      return PurchaseHistory.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update purchase status: $e');
    }
  }

  /// Get purchase statistics
  static Future<Map<String, dynamic>> getPurchaseStatistics() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('purchase_history')
          .select('payment_status, final_price')
          .eq('user_id', user.id);

      final data = response as List;
      
      int totalPurchases = data.length;
      int completedPurchases = data.where((item) => item['payment_status'] == 'completed').length;
      int pendingPurchases = data.where((item) => item['payment_status'] == 'pending').length;
      int failedPurchases = data.where((item) => item['payment_status'] == 'failed').length;
      
      double totalSpent = data
          .where((item) => item['payment_status'] == 'completed')
          .fold(0.0, (sum, item) => sum + (item['final_price'] ?? 0));

      return {
        'total_purchases': totalPurchases,
        'completed_purchases': completedPurchases,
        'pending_purchases': pendingPurchases,
        'failed_purchases': failedPurchases,
        'total_spent': totalSpent,
      };
    } catch (e) {
      throw Exception('Failed to get purchase statistics: $e');
    }
  }
}
