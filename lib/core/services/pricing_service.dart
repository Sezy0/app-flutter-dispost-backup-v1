import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'discord_webhook_service.dart';

class PricingPlan {
  final String planId;
  final String name;
  final double pricing;
  final double? discountPrice;
  final int maxConfig;
  final int expiredPlan;
  final double finalPrice;

  PricingPlan({
    required this.planId,
    required this.name,
    required this.pricing,
    this.discountPrice,
    required this.maxConfig,
    required this.expiredPlan,
    required this.finalPrice,
  });

  factory PricingPlan.fromJson(Map<String, dynamic> json) {
    return PricingPlan(
      planId: json['plan_id'],
      name: json['name'],
      pricing: (json['pricing'] as num).toDouble(),
      discountPrice: json['discount_price'] != null 
          ? (json['discount_price'] as num).toDouble() 
          : null,
      maxConfig: json['max_config'],
      expiredPlan: json['expired_plan'],
      finalPrice: (json['final_price'] as num).toDouble(),
    );
  }
}

class PurchaseHistory {
  final String purchaseId;
  final String planName;
  final double originalPrice;
  final double? discountPrice;
  final double finalPrice;
  final int maxConfigPurchased;
  final int daysPurchased;
  final String paymentMethod;
  final String paymentStatus;
  final DateTime purchasedAt;

  PurchaseHistory({
    required this.purchaseId,
    required this.planName,
    required this.originalPrice,
    this.discountPrice,
    required this.finalPrice,
    required this.maxConfigPurchased,
    required this.daysPurchased,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.purchasedAt,
  });

  factory PurchaseHistory.fromJson(Map<String, dynamic> json) {
    return PurchaseHistory(
      purchaseId: json['purchase_id'],
      planName: json['plan_name'],
      originalPrice: (json['original_price'] as num).toDouble(),
      discountPrice: json['discount_price'] != null 
          ? (json['discount_price'] as num).toDouble() 
          : null,
      finalPrice: (json['final_price'] as num).toDouble(),
      maxConfigPurchased: json['max_config_purchased'],
      daysPurchased: json['days_purchased'],
      paymentMethod: json['payment_method'],
      paymentStatus: json['payment_status'],
      purchasedAt: DateTime.parse(json['purchased_at']),
    );
  }
}

class PricingService {
  static final _supabase = Supabase.instance.client;

  // Get all active plans
  static Future<List<PricingPlan>> getActivePlans() async {
    try {
      final response = await _supabase.rpc('get_active_plans');
      
      return (response as List<dynamic>? ?? [])
          .map((json) => PricingPlan.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting active plans: $e');
      throw Exception('Failed to load pricing plans: $e');
    }
  }

  // Purchase a plan
  static Future<Map<String, Object?>> purchasePlan({
    required String planId,
    String paymentMethod = 'manual',
    String? transactionId,
    String? notes,
    String? proofImageUrl,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get plan details before purchase
      final plan = await getPlanById(planId);
      if (plan == null) {
        return {
          'success': false,
          'message': 'Plan not found',
        };
      }

      // Use auto-ban enabled purchase function
      final response = await _supabase.rpc('purchase_plan_with_auto_ban', params: {
        'p_user_id': user.id,
        'p_plan_id': planId,
        'p_payment_method': paymentMethod,
        'p_transaction_id': transactionId,
        'p_notes': notes,
      });

      final result = response as Map<String, Object?>? ?? {
        'success': false,
        'message': 'Invalid response format',
      };
      
      // Debug: Log the response to see what we get from Supabase
      debugPrint('Purchase RPC Response: $response');
      debugPrint('Purchase ID from result: ${result['purchase_id']}');

      // Send Discord webhook notification if purchase was successful
      if (result['success'] == true) {
        // Extract purchase_id explicitly and ensure it's properly handled
        String purchaseId = 'Unknown ID';
        
        // Try multiple ways to extract purchase_id from the result
        if (result['purchase_id'] != null) {
          purchaseId = result['purchase_id'].toString();
        } else if (result.containsKey('purchase_id')) {
          // Sometimes the key exists but value is null
          final rawPurchaseId = result['purchase_id'];
          if (rawPurchaseId != null) {
            purchaseId = rawPurchaseId.toString();
          }
        }
        
        // Debug: Log the extracted purchase_id
        debugPrint('Extracted purchase_id for webhook: $purchaseId');
        
        try {
          await DiscordWebhookService.sendPurchaseNotification(
            userEmail: user.email ?? 'Unknown User',
            planName: plan.name,
            finalPrice: plan.finalPrice,
            paymentMethod: paymentMethod,
            transactionId: transactionId,
            notes: notes,
            purchaseId: purchaseId,
            proofImageUrl: proofImageUrl,
          );
        } catch (webhookError) {
          debugPrint('Discord webhook failed but purchase succeeded: $webhookError');
          // Don't fail the purchase if webhook fails
        }
      }

      return result;
    } catch (e) {
      debugPrint('Error purchasing plan: $e');
      return {
        'success': false,
        'message': 'Purchase failed: $e',
      };
    }
  }

  // Get user purchase history
  static Future<List<PurchaseHistory>> getUserPurchaseHistory() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase.rpc('get_user_purchase_history', params: {
        'p_user_id': user.id,
      });

      return (response as List<dynamic>? ?? [])
          .map((json) => PurchaseHistory.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting purchase history: $e');
      throw Exception('Failed to load purchase history: $e');
    }
  }

  // Get specific plan by ID
  static Future<PricingPlan?> getPlanById(String planId) async {
    try {
      final response = await _supabase
          .from('pricing')
          .select()
          .eq('plan_id', planId)
          .eq('status', 'active')
          .single();

      return PricingPlan.fromJson({
        ...response,
        'final_price': response['discount_price'] ?? response['pricing'],
      });
    } catch (e) {
      debugPrint('Error getting plan by ID: $e');
      return null;
    }
  }

  // Check if user can purchase plan (validation)
  static Future<Map<String, dynamic>> validatePurchase(String planId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {
          'valid': false,
          'message': 'User not authenticated',
        };
      }

      // Get user profile
      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      // Check if user is banned
      if (profileResponse['status'] == 'banned') {
        return {
          'valid': false,
          'message': 'Account is banned and cannot purchase plans',
        };
      }

      // Get plan details
      final plan = await getPlanById(planId);
      if (plan == null) {
        return {
          'valid': false,
          'message': 'Plan not found or inactive',
        };
      }

      return {
        'valid': true,
        'message': 'Purchase validation successful',
        'plan': plan,
        'user_profile': profileResponse,
      };
    } catch (e) {
      debugPrint('Error validating purchase: $e');
      return {
        'valid': false,
        'message': 'Validation failed: $e',
      };
    }
  }

  // Get pricing statistics (for admin)
  static Future<Map<String, dynamic>> getPricingStats() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get total purchases
      final purchaseCountResponse = await _supabase
          .from('purchase_history')
          .select('purchase_id')
          .eq('user_id', user.id);

      // Get total spent
      final totalSpentResponse = await _supabase
          .from('purchase_history')
          .select('final_price')
          .eq('user_id', user.id);

      double totalSpent = (totalSpentResponse as List<dynamic>? ?? [])
          .fold(0.0, (sum, purchase) => sum + (purchase['final_price'] as num).toDouble());

      return {
        'total_purchases': purchaseCountResponse.length,
        'total_spent': totalSpent,
        'currency': 'IDR',
      };
    } catch (e) {
      debugPrint('Error getting pricing stats: $e');
      throw Exception('Failed to load pricing statistics: $e');
    }
  }

  // Format currency for display
  static String formatCurrency(double amount, {String currency = 'IDR'}) {
    String formatted = amount.toStringAsFixed(0);
    
    // Add thousand separators
    formatted = formatted.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );

    switch (currency) {
      case 'IDR':
        return 'Rp $formatted';
      case 'USD':
        return '\$$formatted';
      default:
        return '$currency $formatted';
    }
  }

  // Calculate discount percentage
  static double calculateDiscountPercentage(double originalPrice, double discountPrice) {
    if (originalPrice <= 0) return 0;
    return ((originalPrice - discountPrice) / originalPrice) * 100;
  }

  // Get recommended plan (for UI highlighting)
  static String getRecommendedPlanName() {
    return 'Basic Plan'; // This can be made configurable
  }

  // Check if user can claim free plan (only once per user)
  static Future<bool> canClaimFreePlan() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return false;
      }

      final response = await _supabase.rpc('check_user_free_plan_eligibility', params: {
        'p_user_id': user.id,
      });

      return response as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking free plan eligibility: $e');
      return false;
    }
  }

  // Get user's free plan history
  static Future<List<Map<String, dynamic>>> getUserFreePlanHistory() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return [];
      }

      final response = await _supabase.rpc('get_user_free_plan_history', params: {
        'p_user_id': user.id,
      });

      return List<Map<String, dynamic>>.from(response as List? ?? []);
    } catch (e) {
      debugPrint('Error getting free plan history: $e');
      return [];
    }
  }

  // === NEW FUNCTIONS FOR DATABASE INTEGRATION ===
  
  // Get all pricing plans directly from pricing table
  static Future<List<PricingPlan>> getAllPricingPlans() async {
    try {
      final response = await _supabase
          .from('pricing')
          .select()
          .order('max_config', ascending: true);

      return response.map<PricingPlan>((json) => PricingPlan.fromJson({
        ...json,
        'plan_id': json['id'].toString(),
        'final_price': json['discount_price'] ?? json['pricing'],
      })).toList();
    } catch (e) {
      debugPrint('Error getting all pricing plans: $e');
      return [];
    }
  }

  // Get plan by name from pricing table
  static Future<PricingPlan?> getPlanByName(String planName) async {
    try {
      final response = await _supabase
          .from('pricing')
          .select()
          .eq('name', planName)
          .maybeSingle();

      if (response == null) return null;
      
      return PricingPlan.fromJson({
        ...response,
        'plan_id': response['id'].toString(),
        'final_price': response['discount_price'] ?? response['pricing'],
      });
    } catch (e) {
      debugPrint('Error getting plan by name: $e');
      return null;
    }
  }

  // Get plan by max_config value
  static Future<PricingPlan?> getPlanByMaxConfig(int maxConfig) async {
    try {
      final response = await _supabase
          .from('pricing')
          .select()
          .eq('max_config', maxConfig)
          .maybeSingle();

      if (response == null) return null;
      
      return PricingPlan.fromJson({
        ...response,
        'plan_id': response['id'].toString(),
        'final_price': response['discount_price'] ?? response['pricing'],
      });
    } catch (e) {
      debugPrint('Error getting plan by max_config: $e');
      return null;
    }
  }

  // Get the highest plan that user can access with given max_config
  static Future<PricingPlan?> getHighestAccessiblePlan(int userMaxConfig) async {
    try {
      final response = await _supabase
          .from('pricing')
          .select()
          .lte('max_config', userMaxConfig)
          .order('max_config', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      
      return PricingPlan.fromJson({
        ...response,
        'plan_id': response['id'].toString(),
        'final_price': response['discount_price'] ?? response['pricing'],
      });
    } catch (e) {
      debugPrint('Error getting highest accessible plan: $e');
      return null;
    }
  }

  // Check if user max_config matches any existing plan
  static Future<bool> isValidMaxConfig(int maxConfig) async {
    try {
      final response = await _supabase
          .from('pricing')
          .select('id')
          .eq('max_config', maxConfig)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error validating max_config: $e');
      return false;
    }
  }

  // Get available servers for specific max_config
  static Future<List<int>> getAvailableServersForMaxConfig(int maxConfig) async {
    try {
      List<int> servers = [];
      
      // Server 1 access (Free Plan equivalent - max_config >= 1)
      if (maxConfig >= 1) servers.add(1);
      
      // Server 2 access (Basic Plan equivalent - max_config >= 30)
      if (maxConfig >= 30) servers.add(2);
      
      // Server 3 access (Pro Plan equivalent - max_config >= 50)
      if (maxConfig >= 50) servers.add(3);
      
      return servers;
    } catch (e) {
      debugPrint('Error getting available servers for max_config: $e');
      return [];
    }
  }

  // Validate server access for user max_config
  static Future<bool> hasServerAccess(int userMaxConfig, int serverNumber) async {
    try {
      final availableServers = await getAvailableServersForMaxConfig(userMaxConfig);
      return availableServers.contains(serverNumber);
    } catch (e) {
      debugPrint('Error checking server access: $e');
      return false;
    }
  }

  // Sync user max_config with pricing table (untuk memastikan konsistensi)
  static Future<bool> syncUserMaxConfigWithPricing(String userId, String planName) async {
    try {
      final plan = await getPlanByName(planName);
      if (plan == null) return false;

      await _supabase
          .from('profiles')
          .update({'max_config': plan.maxConfig})
          .eq('id', userId);

      return true;
    } catch (e) {
      debugPrint('Error syncing user max_config with pricing: $e');
      return false;
    }
  }

  // Get plan details with server access info
  static Future<Map<String, dynamic>> getPlanDetailsWithAccess(String planName) async {
    try {
      final plan = await getPlanByName(planName);
      if (plan == null) {
        return {
          'exists': false,
          'plan': null,
          'serverAccess': <int>[],
          'canAccessServer1': false,
          'canAccessServer2': false,
          'canAccessServer3': false,
        };
      }

      final serverAccess = await getAvailableServersForMaxConfig(plan.maxConfig);
      
      return {
        'exists': true,
        'plan': plan,
        'serverAccess': serverAccess,
        'canAccessServer1': serverAccess.contains(1),
        'canAccessServer2': serverAccess.contains(2),
        'canAccessServer3': serverAccess.contains(3),
      };
    } catch (e) {
      debugPrint('Error getting plan details: $e');
      return {
        'exists': false,
        'plan': null,
        'serverAccess': <int>[],
        'canAccessServer1': false,
        'canAccessServer2': false,
        'canAccessServer3': false,
        'error': e.toString(),
      };
    }
  }

  // Get plan statistics from database
  static Future<Map<String, dynamic>> getDatabasePlanStatistics() async {
    try {
      final plans = await getAllPricingPlans();
      
      return {
        'totalPlans': plans.length,
        'freePlans': plans.where((p) => p.name.toLowerCase().contains('free')).length,
        'basicPlans': plans.where((p) => p.name.toLowerCase().contains('basic')).length,
        'proPlans': plans.where((p) => p.name.toLowerCase().contains('pro')).length,
        'maxConfigRange': plans.isNotEmpty 
            ? {'min': plans.first.maxConfig, 'max': plans.last.maxConfig}
            : {'min': 0, 'max': 0},
        'serverAccessDistribution': {
          'server1Only': plans.where((p) => p.maxConfig >= 1 && p.maxConfig < 30).length,
          'server1And2': plans.where((p) => p.maxConfig >= 30 && p.maxConfig < 50).length,
          'allServers': plans.where((p) => p.maxConfig >= 50).length,
        },
      };
    } catch (e) {
      debugPrint('Error getting database plan statistics: $e');
      return {
        'totalPlans': 0,
        'freePlans': 0,
        'basicPlans': 0,
        'proPlans': 0,
        'maxConfigRange': {'min': 0, 'max': 0},
        'serverAccessDistribution': {
          'server1Only': 0,
          'server1And2': 0,
          'allServers': 0,
        },
        'error': e.toString(),
      };
    }
  }
}
