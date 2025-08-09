import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dispost_autopost/core/utils/timezone_utils.dart';
import 'package:timezone/timezone.dart' as tz;

class UserProfile {
  final String id;
  final String userId;
  final String email;
  final String? name;
  final DateTime? expiredPlan; // Nullable - no plan by default
  final int? maxConfig;        // Nullable - no limit by default
  final String status;
  final DateTime? lastLogin;
  final DateTime createdAt;
  final int totalSent;         // Total posts sent
  final String? banReason;     // Reason for ban
  final DateTime? bannedUntil; // When ban expires

  UserProfile({
    required this.id,
    required this.userId,
    required this.email,
    this.name,
    this.expiredPlan,
    this.maxConfig,
    required this.status,
    this.lastLogin,
    required this.createdAt,
    required this.totalSent,
    this.banReason,
    this.bannedUntil,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      userId: json['user_id'],
      email: json['email'],
      name: json['name'],
      expiredPlan: json['expired_plan'] != null ? DateTime.parse(json['expired_plan']) : null,
      maxConfig: json['max_config'],
      status: json['status'],
      lastLogin: json['last_login'] != null ? DateTime.parse(json['last_login']) : null,
      createdAt: DateTime.parse(json['created_at']),
      totalSent: json['total_sent'] ?? 0,
      banReason: json['ban_reason'],
      bannedUntil: json['banned_until'] != null ? DateTime.parse(json['banned_until']) : null,
    );
  }

  // Helper methods - menggunakan timezone Jakarta
  bool get isPlanActive {
    if (expiredPlan == null) return false;
    final jakartaExpiredPlan = tz.TZDateTime.from(expiredPlan!, TimezoneUtils.jakartaLocation);
    return jakartaExpiredPlan.isAfter(TimezoneUtils.nowInJakarta());
  }
  bool get hasPlan => expiredPlan != null;
  bool get hasMaxConfig => maxConfig != null;
  bool get isBanned => status == 'banned';
  bool get isActive => status == 'active';
  
  int get daysUntilExpired {
    if (expiredPlan == null) return 0;
    final jakartaExpiredPlan = tz.TZDateTime.from(expiredPlan!, TimezoneUtils.jakartaLocation);
    return TimezoneUtils.daysDifferenceFromNow(jakartaExpiredPlan);
  }
}

class UserService {
  static final _supabase = Supabase.instance.client;

  // Get current user profile
  static Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle(); // Use maybeSingle() instead of single() to handle 0 rows gracefully

      if (response == null) {
        debugPrint('No profile found for user ${user.id}. Profile may need to be created.');
        return null;
      }

      return UserProfile.fromJson(response);
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  // Update last login (otomatis via trigger, tapi bisa manual juga)
  static Future<void> updateLastLogin() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('profiles')
          .update({'last_login': TimezoneUtils.nowInJakarta().toIso8601String()})
          .eq('id', user.id);
    } catch (e) {
      debugPrint('Error updating last login: $e');
    }
  }

  // Update user name
  static Future<bool> updateUserName(String name) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase
          .from('profiles')
          .update({'name': name})
          .eq('id', user.id);

      return true;
    } catch (e) {
      debugPrint('Error updating user name: $e');
      return false;
    }
  }

  // Check if user plan is still active
  static Future<bool> isPlanActive() async {
    try {
      final profile = await getCurrentUserProfile();
      return profile?.isPlanActive ?? false;
    } catch (e) {
      debugPrint('Error checking plan status: $e');
      return false;
    }
  }

  // Get user status (active, banned, etc)
  static Future<String?> getUserStatus() async {
    try {
      final profile = await getCurrentUserProfile();
      return profile?.status;
    } catch (e) {
      debugPrint('Error getting user status: $e');
      return null;
    }
  }

  // Check if user is banned
  static Future<bool> isUserBanned() async {
    try {
      final status = await getUserStatus();
      return status == 'banned';
    } catch (e) {
      debugPrint('Error checking ban status: $e');
      return false;
    }
  }

  // Get remaining config slots
  static Future<int> getRemainingConfigSlots() async {
    try {
      final profile = await getCurrentUserProfile();
      if (profile == null) return 0;
      
      // If no max_config set or is 0, return 0
      if (profile.maxConfig == null || profile.maxConfig == 0) return 0;

      // Hitung jumlah config yang sudah dipakai
      // (Anda perlu buat tabel configs terpisah)
      final usedConfigs = await _supabase
          .from('configs')
          .select('id')
          .eq('user_id', profile.id)
          .count();

      return profile.maxConfig! - usedConfigs.count;
    } catch (e) {
      debugPrint('Error getting remaining config slots: $e');
      return 0;
    }
  }

  // Extension plan (untuk admin atau payment)
  static Future<bool> extendPlan(int days) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final profile = await getCurrentUserProfile();
      if (profile == null) return false;

      // If no existing plan, start from today (Jakarta time)
      final tz.TZDateTime baseDate = profile.expiredPlan != null 
          ? tz.TZDateTime.from(profile.expiredPlan!, TimezoneUtils.jakartaLocation)
          : TimezoneUtils.nowInJakarta();
      final newExpiredDate = baseDate.add(Duration(days: days));

      await _supabase
          .from('profiles')
          .update({'expired_plan': newExpiredDate.toIso8601String().split('T')[0]})
          .eq('id', user.id);

      return true;
    } catch (e) {
      debugPrint('Error extending plan: $e');
      return false;
    }
  }

  // Ban user (untuk admin)
  static Future<bool> banUser(String userId) async {
    try {
      await _supabase
          .from('profiles')
          .update({'status': 'banned'})
          .eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('Error banning user: $e');
      return false;
    }
  }

  // Unban user (untuk admin)
  static Future<bool> unbanUser(String userId) async {
    try {
      await _supabase
          .from('profiles')
          .update({'status': 'active'})
          .eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('Error unbanning user: $e');
      return false;
    }
  }

  // Increment total sent posts
  static Future<bool> incrementTotalSent() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase.rpc('increment_total_sent', params: {
        'user_profile_id': user.id,
      });

      return true;
    } catch (e) {
      debugPrint('Error incrementing total sent: $e');
      return false;
    }
  }

  // Reset total sent (untuk admin atau testing)
  static Future<bool> resetTotalSent() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase
          .from('profiles')
          .update({'total_sent': 0})
          .eq('id', user.id);

      return true;
    } catch (e) {
      debugPrint('Error resetting total sent: $e');
      return false;
    }
  }

  // Redirect if user is banned
  static Future<void> checkAndRedirectIfBanned(BuildContext context) async {
    try {
      final profile = await getCurrentUserProfile();
      if (context.mounted && profile != null && profile.isBanned) {
        Navigator.of(context).pushReplacementNamed('/banned');
      }
    } catch (e) {
      debugPrint('Error checking and redirecting banned user: $e');
    }
  }

  // Check if user has Server 1 access (Free Plan) - based on max_config
  static Future<bool> hasServer1Access() async {
    try {
      final profile = await getCurrentUserProfile();
      if (profile == null) return false;
      
      // Server 1 access: user has max_config = 1 (Free Plan config)
      // AND plan is still active (not expired)
      return profile.maxConfig != null && 
             profile.maxConfig! >= 1 && 
             profile.isPlanActive;
    } catch (e) {
      debugPrint('Error checking Server 1 access: $e');
      return false;
    }
  }

  // Check if user has Server 2 access (Basic Plan) - based on max_config
  static Future<bool> hasServer2Access() async {
    try {
      final profile = await getCurrentUserProfile();
      if (profile == null) return false;
      
      // Server 2 access: user has max_config >= 30 (Basic Plan config)
      // AND plan is still active (not expired)
      return profile.maxConfig != null && 
             profile.maxConfig! >= 30 && 
             profile.isPlanActive;
    } catch (e) {
      debugPrint('Error checking Server 2 access: $e');
      return false;
    }
  }

  // Check if user has Server 3 access (Pro Plan) - based on max_config
  static Future<bool> hasServer3Access() async {
    try {
      final profile = await getCurrentUserProfile();
      if (profile == null) return false;
      
      // Server 3 access: user has max_config >= 50 (Pro Plan config)
      // AND plan is still active (not expired)
      return profile.maxConfig != null && 
             profile.maxConfig! >= 50 && 
             profile.isPlanActive;
    } catch (e) {
      debugPrint('Error checking Server 3 access: $e');
      return false;
    }
  }

  // Get user plan type based on max_config
  static Future<String> getUserPlanType() async {
    try {
      final profile = await getCurrentUserProfile();
      if (profile == null || profile.maxConfig == null) {
        return 'No Plan';
      }
      
      // Determine plan type based on max_config value from database
      final maxConfig = profile.maxConfig!;
      if (maxConfig >= 50) {
        return 'Pro Plan';
      } else if (maxConfig >= 30) {
        return 'Basic Plan';
      } else if (maxConfig >= 1) {
        return 'Free Plan';
      } else {
        return 'No Plan';
      }
    } catch (e) {
      debugPrint('Error getting user plan type: $e');
      return 'No Plan';
    }
  }
  
  // Get available servers for user
  static Future<List<int>> getAvailableServers() async {
    List<int> availableServers = [];
    
    if (await hasServer1Access()) availableServers.add(1);
    if (await hasServer2Access()) availableServers.add(2);
    if (await hasServer3Access()) availableServers.add(3);
    
    return availableServers;
  }
  
  // Get user access summary
  static Future<Map<String, dynamic>> getUserAccessSummary() async {
    try {
      final profile = await getCurrentUserProfile();
      if (profile == null) {
        return {
          'planType': 'No Plan',
          'maxConfig': 0,
          'isPlanActive': false,
          'availableServers': <int>[],
          'daysUntilExpired': 0,
        };
      }
      
      // Optimasi: hitung semua dari profile yang sudah diambil, tanpa query tambahan
      final maxConfig = profile.maxConfig ?? 0;
      final isPlanActive = profile.isPlanActive;
      
      List<int> availableServers = [];
      String planType = 'No Plan';
      
      // Hitung available servers dan plan type berdasarkan maxConfig
      if (isPlanActive && maxConfig > 0) {
        if (maxConfig >= 1) {
          availableServers.add(1);
          planType = 'Free Plan';
        }
        if (maxConfig >= 30) {
          availableServers.add(2);
          planType = 'Basic Plan';
        }
        if (maxConfig >= 50) {
          availableServers.add(3);
          planType = 'Pro Plan';
        }
      }
      
      return {
        'planType': planType,
        'maxConfig': maxConfig,
        'isPlanActive': isPlanActive,
        'availableServers': availableServers,
        'daysUntilExpired': profile.daysUntilExpired,
      };
    } catch (e) {
      debugPrint('Error getting user access summary: $e');
      return {
        'planType': 'Error',
        'maxConfig': 0,
        'isPlanActive': false,
        'availableServers': <int>[],
        'daysUntilExpired': 0,
      };
    }
  }

  // Legacy functions for backward compatibility
  // Check if user has free trial access (for Server 1)
  static Future<bool> hasFreeTrial() async {
    return await hasServer1Access();
  }

  // Check if user has Basic plan access (for Server 2)
  static Future<bool> hasBasicPlan() async {
    return await hasServer2Access();
  }

  // Check if user has Pro plan access (for Server 3)
  static Future<bool> hasProPlan() async {
    return await hasServer3Access();
  }

  // Get user's current active plan name
  static Future<String?> getCurrentPlanName() async {
    try {
      final profile = await getCurrentUserProfile();
      if (profile == null || !profile.isPlanActive) return null;

      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      // Get the most recent purchase that's still active
      final response = await _supabase
          .from('purchase_history')
          .select('plan_name, purchased_at, days_purchased')
          .eq('user_id', user.id)
          .order('purchased_at', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;

      final latestPurchase = response.first;
      final purchaseDate = DateTime.parse(latestPurchase['purchased_at']);
      final daysPurchased = latestPurchase['days_purchased'] as int;
      final expiryDate = purchaseDate.add(Duration(days: daysPurchased));

      // Check if plan is still active
      if (DateTime.now().isBefore(expiryDate)) {
        return latestPurchase['plan_name'] as String;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting current plan name: $e');
      return null;
    }
  }

  // Logout user
  static Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Error logging out: $e');
      rethrow;
    }
  }
}
