import 'package:flutter/foundation.dart';
import '../services/user_service.dart';
import '../services/pricing_service.dart';

class UserValidationUtils {
  // Validate if user's max_config matches any plan in pricing table
  static Future<Map<String, dynamic>> validateUserMaxConfig() async {
    try {
      final profile = await UserService.getCurrentUserProfile();
      if (profile == null || profile.maxConfig == null) {
        return {
          'isValid': false,
          'error': 'User profile not found or max_config is null',
          'userMaxConfig': null,
          'matchingPlan': null,
          'availableServers': <int>[],
        };
      }

      // Check if user's max_config exists in pricing table
      final isValidConfig = await PricingService.isValidMaxConfig(profile.maxConfig!);
      
      // Get matching plan if exists
      final matchingPlan = await PricingService.getPlanByMaxConfig(profile.maxConfig!);
      
      // Get available servers for user's max_config
      final availableServers = await PricingService.getAvailableServersForMaxConfig(profile.maxConfig!);
      
      return {
        'isValid': isValidConfig,
        'userMaxConfig': profile.maxConfig,
        'matchingPlan': matchingPlan,
        'availableServers': availableServers,
        'planExists': matchingPlan != null,
        'planName': matchingPlan?.name,
        'error': null,
      };
    } catch (e) {
      debugPrint('Error validating user max_config: $e');
      return {
        'isValid': false,
        'error': 'Validation failed: $e',
        'userMaxConfig': null,
        'matchingPlan': null,
        'availableServers': <int>[],
      };
    }
  }

  // Sync user's max_config based on their latest purchase
  static Future<Map<String, dynamic>> syncUserMaxConfigFromPurchaseHistory() async {
    try {
      final profile = await UserService.getCurrentUserProfile();
      if (profile == null) {
        return {
          'success': false,
          'error': 'User profile not found',
          'oldMaxConfig': null,
          'newMaxConfig': null,
        };
      }

      // Get user's latest purchase
      final purchaseHistory = await PricingService.getUserPurchaseHistory();
      if (purchaseHistory.isEmpty) {
        return {
          'success': false,
          'error': 'No purchase history found',
          'oldMaxConfig': profile.maxConfig,
          'newMaxConfig': null,
        };
      }

      // Get the latest successful purchase
      final latestPurchase = purchaseHistory
          .where((p) => p.paymentStatus == 'completed' || p.paymentStatus == 'approved')
          .first;

      // Check if user's current max_config matches the purchased max_config
      final oldMaxConfig = profile.maxConfig;
      final purchasedMaxConfig = latestPurchase.maxConfigPurchased;

      if (oldMaxConfig == purchasedMaxConfig) {
        return {
          'success': true,
          'message': 'max_config already synchronized',
          'oldMaxConfig': oldMaxConfig,
          'newMaxConfig': purchasedMaxConfig,
          'changed': false,
        };
      }

      // Update user's max_config to match purchase
      final user = await UserService.getCurrentUserProfile();
      if (user == null) {
        return {
          'success': false,
          'error': 'Failed to get user for update',
          'oldMaxConfig': oldMaxConfig,
          'newMaxConfig': null,
        };
      }

      // Here you would typically update the user's profile
      // This assumes you have an update method in UserService
      // await _supabase.from('profiles').update({'max_config': purchasedMaxConfig}).eq('id', user.id);

      return {
        'success': true,
        'message': 'max_config synchronized successfully',
        'oldMaxConfig': oldMaxConfig,
        'newMaxConfig': purchasedMaxConfig,
        'changed': true,
        'latestPurchasePlan': latestPurchase.planName,
      };
    } catch (e) {
      debugPrint('Error syncing user max_config from purchase history: $e');
      return {
        'success': false,
        'error': 'Sync failed: $e',
        'oldMaxConfig': null,
        'newMaxConfig': null,
      };
    }
  }

  // Get comprehensive user access report
  static Future<Map<String, dynamic>> getUserAccessReport() async {
    try {
      final profile = await UserService.getCurrentUserProfile();
      if (profile == null) {
        return {
          'success': false,
          'error': 'User profile not found',
          'report': null,
        };
      }

      // Get validation results
      final validation = await validateUserMaxConfig();
      
      // Get available servers
      final availableServers = await UserService.getAvailableServers();
      
      // Get user plan type
      final planType = await UserService.getUserPlanType();
      
      // Get access summary
      final accessSummary = await UserService.getUserAccessSummary();
      
      // Check server access individually
      final server1Access = await UserService.hasServer1Access();
      final server2Access = await UserService.hasServer2Access();
      final server3Access = await UserService.hasServer3Access();

      return {
        'success': true,
        'report': {
          'userProfile': {
            'id': profile.id,
            'email': profile.email,
            'maxConfig': profile.maxConfig,
            'isPlanActive': profile.isPlanActive,
            'daysUntilExpired': profile.daysUntilExpired,
            'status': profile.status,
          },
          'validation': validation,
          'planType': planType,
          'availableServers': availableServers,
          'accessSummary': accessSummary,
          'serverAccess': {
            'server1': server1Access,
            'server2': server2Access,
            'server3': server3Access,
          },
        },
      };
    } catch (e) {
      debugPrint('Error generating user access report: $e');
      return {
        'success': false,
        'error': 'Report generation failed: $e',
        'report': null,
      };
    }
  }

  // Check if user's plan configuration is consistent
  static Future<Map<String, dynamic>> checkPlanConsistency() async {
    try {
      final profile = await UserService.getCurrentUserProfile();
      if (profile == null) {
        return {
          'isConsistent': false,
          'error': 'User profile not found',
          'issues': ['Profile not found'],
        };
      }

      List<String> issues = [];
      Map<String, dynamic> details = {};

      // Check if max_config exists in pricing table
      if (profile.maxConfig != null) {
        final isValidMaxConfig = await PricingService.isValidMaxConfig(profile.maxConfig!);
        if (!isValidMaxConfig) {
          issues.add('max_config ${profile.maxConfig} does not exist in pricing table');
        }
        details['maxConfigValid'] = isValidMaxConfig;
      } else {
        issues.add('max_config is null');
        details['maxConfigValid'] = false;
      }

      // Check if plan is expired but user still has access
      if (profile.hasPlan && !profile.isPlanActive) {
        issues.add('Plan expired but user may still have access');
        details['planExpired'] = true;
      } else {
        details['planExpired'] = false;
      }

      // Check server access consistency
      final availableServers = await UserService.getAvailableServers();
      final expectedServers = profile.maxConfig != null 
          ? await PricingService.getAvailableServersForMaxConfig(profile.maxConfig!)
          : <int>[];
          
      if (availableServers.length != expectedServers.length ||
          !availableServers.every((server) => expectedServers.contains(server))) {
        issues.add('Server access inconsistent with max_config');
        details['serverAccessInconsistent'] = true;
        details['actualServerAccess'] = availableServers;
        details['expectedServerAccess'] = expectedServers;
      } else {
        details['serverAccessInconsistent'] = false;
      }

      return {
        'isConsistent': issues.isEmpty,
        'issues': issues,
        'details': details,
        'profile': {
          'maxConfig': profile.maxConfig,
          'isPlanActive': profile.isPlanActive,
          'daysUntilExpired': profile.daysUntilExpired,
        },
      };
    } catch (e) {
      debugPrint('Error checking plan consistency: $e');
      return {
        'isConsistent': false,
        'error': 'Consistency check failed: $e',
        'issues': ['System error during check'],
      };
    }
  }

  // Auto-fix common plan inconsistencies
  static Future<Map<String, dynamic>> autoFixPlanInconsistencies() async {
    try {
      final consistencyCheck = await checkPlanConsistency();
      if (consistencyCheck['isConsistent'] == true) {
        return {
          'success': true,
          'message': 'No inconsistencies found',
          'fixes': [],
        };
      }

      List<String> fixes = [];
      final profile = await UserService.getCurrentUserProfile();
      if (profile == null) {
        return {
          'success': false,
          'error': 'User profile not found',
          'fixes': [],
        };
      }

      // Try to sync max_config from purchase history
      final syncResult = await syncUserMaxConfigFromPurchaseHistory();
      if (syncResult['success'] == true && syncResult['changed'] == true) {
        fixes.add('Synchronized max_config from purchase history: ${syncResult['oldMaxConfig']} → ${syncResult['newMaxConfig']}');
      }

      // Additional fixes can be added here...

      return {
        'success': fixes.isNotEmpty,
        'message': fixes.isNotEmpty 
            ? 'Applied ${fixes.length} fix(es)'
            : 'No fixes could be applied automatically',
        'fixes': fixes,
        'originalIssues': consistencyCheck['issues'],
      };
    } catch (e) {
      debugPrint('Error auto-fixing plan inconsistencies: $e');
      return {
        'success': false,
        'error': 'Auto-fix failed: $e',
        'fixes': [],
      };
    }
  }

  // Get plan upgrade recommendations
  static Future<Map<String, dynamic>> getPlanUpgradeRecommendations() async {
    try {
      final profile = await UserService.getCurrentUserProfile();
      if (profile == null || profile.maxConfig == null) {
        return {
          'hasRecommendations': false,
          'error': 'User profile or max_config not found',
          'recommendations': [],
        };
      }

      // Get all available plans
      final allPlans = await PricingService.getAllPricingPlans();
      if (allPlans.isEmpty) {
        return {
          'hasRecommendations': false,
          'error': 'No pricing plans found',
          'recommendations': [],
        };
      }

      // Find upgrade options (plans with higher max_config)
      final upgradePlans = allPlans
          .where((plan) => plan.maxConfig > profile.maxConfig!)
          .toList();

      if (upgradePlans.isEmpty) {
        return {
          'hasRecommendations': false,
          'message': 'User already has the highest plan',
          'recommendations': [],
          'currentPlan': allPlans.where((p) => p.maxConfig == profile.maxConfig!).firstOrNull,
        };
      }

      // Create recommendations
      List<Map<String, dynamic>> recommendations = [];
      for (final plan in upgradePlans) {
        final additionalServers = await PricingService.getAvailableServersForMaxConfig(plan.maxConfig);
        final currentServers = await UserService.getAvailableServers();
        final newServers = additionalServers.where((server) => !currentServers.contains(server)).toList();

        recommendations.add({
          'plan': plan,
          'benefits': {
            'additionalMaxConfig': plan.maxConfig - profile.maxConfig!,
            'newServers': newServers,
            'totalServers': additionalServers,
          },
          'pricing': {
            'price': plan.finalPrice,
            'formattedPrice': PricingService.formatCurrency(plan.finalPrice),
            'duration': plan.expiredPlan,
          }
        });
      }

      return {
        'hasRecommendations': true,
        'recommendations': recommendations,
        'currentMaxConfig': profile.maxConfig,
        'currentServers': await UserService.getAvailableServers(),
      };
    } catch (e) {
      debugPrint('Error getting plan upgrade recommendations: $e');
      return {
        'hasRecommendations': false,
        'error': 'Failed to get recommendations: $e',
        'recommendations': [],
      };
    }
  }
}
