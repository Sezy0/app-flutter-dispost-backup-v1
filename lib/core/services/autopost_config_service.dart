import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dispost_autopost/core/models/autopost_config.dart';
import 'package:dispost_autopost/core/utils/timezone_utils.dart';
import 'package:timezone/timezone.dart' as tz;

class AutopostConfigService {
  static final _supabase = Supabase.instance.client;

  /// Get all user tokens for dropdown selection
  static Future<List<TokenOption>> getUserTokens() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('tokens')
          .select('id, name, discord_id, avatar_url, status')
          .eq('user_id', user.id)
          .eq('status', true) // Only get active tokens
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => TokenOption.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting user tokens: $e');
      return [];
    }
  }

  /// Create new autopost configuration
  static Future<bool> createConfig({
    required String tokenId,
    required String serverType,
    required String name,
    required String channelId,
    String? webhookUrl,
    required int delay,
    dynamic endTime, // Accept both DateTime and tz.TZDateTime
    required int minDelay,
    required int maxDelay,
    required String message,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('User not authenticated');
        return false;
      }

      // Convert endTime to UTC for database storage if provided
      String? endTimeIso;
      if (endTime != null) {
        if (endTime is tz.TZDateTime) {
          // tz.TZDateTime from Jakarta timezone - convert to UTC
          endTimeIso = endTime.toUtc().toIso8601String();
        } else if (endTime is DateTime) {
          // Regular DateTime - assume it's already in Jakarta timezone
          // Convert to UTC for database storage
          final jakartaDateTime = tz.TZDateTime.from(endTime, TimezoneUtils.jakartaLocation);
          endTimeIso = jakartaDateTime.toUtc().toIso8601String();
        }
      }

      final configData = {
        'user_id': user.id,
        'token_id': tokenId,
        'server_type': serverType,
        'name': name,
        'channel_id': channelId,
        'webhook_url': webhookUrl?.isEmpty == true ? null : webhookUrl,
        'delay': delay,
        'end_time': endTimeIso,
        'min_delay': minDelay,
        'max_delay': maxDelay,
        'message': message,
        'status': false, // Initially inactive
      };

      await _supabase.from('autopost_config').insert(configData);

      debugPrint('Autopost config created successfully');
      return true;
    } catch (e) {
      debugPrint('Error creating autopost config: $e');
      return false;
    }
  }

  /// Get all configurations for current user by server type
  static Future<List<AutopostConfig>> getUserConfigs({String? serverType}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      var query = _supabase
          .from('autopost_config')
          .select('*')
          .eq('user_id', user.id);

      if (serverType != null) {
        query = query.eq('server_type', serverType);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((json) => AutopostConfig.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting user configs: $e');
      return [];
    }
  }

  /// Get single configuration by ID
  static Future<AutopostConfig?> getConfigById(String configId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('autopost_config')
          .select('*')
          .eq('id', configId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return null;

      return AutopostConfig.fromJson(response);
    } catch (e) {
      debugPrint('Error getting config by ID: $e');
      return null;
    }
  }

  /// Update configuration status (activate/deactivate)
  static Future<bool> updateConfigStatus(String configId, bool status) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase
          .from('autopost_config')
          .update({'is_active': status})
          .eq('id', configId)
          .eq('user_id', user.id);

      debugPrint('Config status updated successfully');
      return true;
    } catch (e) {
      debugPrint('Error updating config status: $e');
      return false;
    }
  }

  /// Update entire configuration
  static Future<bool> updateConfig({
    required String configId,
    String? tokenId,
    String? name,
    String? channelId,
    String? webhookUrl,
    int? delay,
    dynamic endTime, // Accept both DateTime and tz.TZDateTime
    int? minDelay,
    int? maxDelay,
    String? message,
    bool? status,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final updateData = <String, dynamic>{};

      if (tokenId != null) updateData['token_id'] = tokenId;
      if (name != null) updateData['name'] = name;
      if (channelId != null) updateData['channel_id'] = channelId;
      if (webhookUrl != null) updateData['webhook_url'] = webhookUrl.isEmpty ? null : webhookUrl;
      if (delay != null) updateData['delay'] = delay;
      if (minDelay != null) updateData['min_delay'] = minDelay;
      if (maxDelay != null) updateData['max_delay'] = maxDelay;
      if (message != null) updateData['message'] = message;
      if (status != null) updateData['status'] = status;

      if (endTime != null) {
        if (endTime is tz.TZDateTime) {
          // tz.TZDateTime from Jakarta timezone - convert to UTC
          updateData['end_time'] = endTime.toUtc().toIso8601String();
        } else if (endTime is DateTime) {
          // Regular DateTime - assume it's already in Jakarta timezone
          // Convert to UTC for database storage
          final jakartaDateTime = tz.TZDateTime.from(endTime, TimezoneUtils.jakartaLocation);
          updateData['end_time'] = jakartaDateTime.toUtc().toIso8601String();
        }
      }

      await _supabase
          .from('autopost_config')
          .update(updateData)
          .eq('id', configId)
          .eq('user_id', user.id);

      debugPrint('Config updated successfully');
      return true;
    } catch (e) {
      debugPrint('Error updating config: $e');
      return false;
    }
  }

  /// Delete configuration
  static Future<bool> deleteConfig(String configId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase
          .from('autopost_config')
          .delete()
          .eq('id', configId)
          .eq('user_id', user.id);

      debugPrint('Config deleted successfully');
      return true;
    } catch (e) {
      debugPrint('Error deleting config: $e');
      return false;
    }
  }

  /// Get configuration count for current user (for max_config validation)
  static Future<int> getUserConfigCount({String? serverType}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      var query = _supabase
          .from('autopost_config')
          .select('id')
          .eq('user_id', user.id);

      if (serverType != null) {
        query = query.eq('server_type', serverType);
      }

      final response = await query.count();
      return response.count;
    } catch (e) {
      debugPrint('Error getting config count: $e');
      return 0;
    }
  }

  /// Check if user can create more configs for specific server
  static Future<bool> canCreateConfig(String serverType) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Get user profile to check max_config
      final profileResponse = await _supabase
          .from('profiles')
          .select('max_config, expired_plan')
          .eq('id', user.id)
          .maybeSingle();

      if (profileResponse == null) return false;

      final maxConfig = profileResponse['max_config'] as int?;
      final expiredPlan = profileResponse['expired_plan'] != null 
          ? DateTime.parse(profileResponse['expired_plan'])
          : null;

      // Check if plan is active
      if (expiredPlan != null) {
        final jakartaExpiredPlan = tz.TZDateTime.from(expiredPlan, TimezoneUtils.jakartaLocation);
        if (jakartaExpiredPlan.isBefore(TimezoneUtils.nowInJakarta())) {
          return false; // Plan expired
        }
      } else {
        return false; // No plan
      }

      // Check if user has proper access for server type
      if (maxConfig == null || maxConfig <= 0) return false;

      switch (serverType) {
        case 'server_1':
          if (maxConfig < 1) return false;
          break;
        case 'server_2':
          if (maxConfig < 30) return false;
          break;
        case 'server_3':
          if (maxConfig < 50) return false;
          break;
        default:
          return false;
      }

      // Get current config count
      final currentCount = await getUserConfigCount();
      
      // Check if user has reached max config limit
      return currentCount < maxConfig;
    } catch (e) {
      debugPrint('Error checking can create config: $e');
      return false;
    }
  }

  /// Get active configurations that need to run
  static Future<List<AutopostConfig>> getActiveConfigs() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final now = TimezoneUtils.nowInJakarta().toIso8601String();

      final response = await _supabase
          .from('autopost_config')
          .select('*')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .or('end_time.is.null,end_time.gte.$now') // Not expired
          .order('next_run', ascending: true);

      return (response as List)
          .map((json) => AutopostConfig.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting active configs: $e');
      return [];
    }
  }

  /// Increment total sent for a configuration
  static Future<bool> incrementTotalSent(String configId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase.rpc('increment_config_total_sent', params: {
        'config_uuid': configId,
        'user_uuid': user.id,
      });

      return true;
    } catch (e) {
      debugPrint('Error incrementing total sent: $e');
      return false;
    }
  }

  /// Validate webhook URL format
  static bool isValidWebhookUrl(String? url) {
    if (url == null || url.isEmpty) return true; // Optional field

    final regex = RegExp(r'^https://discord(app)?\.com/api/webhooks/[0-9]+/[a-zA-Z0-9_-]+$');
    return regex.hasMatch(url);
  }

  /// Validate channel ID format
  static bool isValidChannelId(String channelId) {
    final regex = RegExp(r'^[0-9]{17,20}$');
    return regex.hasMatch(channelId);
  }

  /// Validate delay values
  static bool isValidDelay(int delay) {
    return delay >= 10 && delay <= 86400; // 10 seconds to 24 hours
  }

  /// Validate delay hierarchy (min <= max for random range)
  static bool isValidDelayHierarchy(int minDelay, int delay, int maxDelay) {
    // Main delay can be any valid value
    // Only min_delay <= max_delay matters for random range
    return minDelay <= maxDelay;
  }

  /// Get server display name
  static String getServerDisplayName(String serverType) {
    switch (serverType) {
      case 'server_1':
        return 'Server 1 (Free Plan)';
      case 'server_2':
        return 'Server 2 (Basic Plan)';
      case 'server_3':
        return 'Server 3 (Pro Plan)';
      default:
        return 'Unknown Server';
    }
  }
}
