import 'package:dispost_autopost/core/utils/timezone_utils.dart';
import 'package:timezone/timezone.dart' as tz;

class AutopostConfig {
  final String id;
  final String userId;
  final String tokenId;
  final String serverType;
  final String name;
  final String channelId;
  final String? webhookUrl;
  final int delay;
  final DateTime? endTime;
  final int minDelay;
  final int maxDelay;
  final String message;
  final int totalSent;
  final bool status;
  final DateTime? nextRun;
  final DateTime createdAt;
  final DateTime updatedAt;

  AutopostConfig({
    required this.id,
    required this.userId,
    required this.tokenId,
    required this.serverType,
    required this.name,
    required this.channelId,
    this.webhookUrl,
    required this.delay,
    this.endTime,
    required this.minDelay,
    required this.maxDelay,
    required this.message,
    required this.totalSent,
    required this.status,
    this.nextRun,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AutopostConfig.fromJson(Map<String, dynamic> json) {
    return AutopostConfig(
      id: json['id'],
      userId: json['user_id'],
      tokenId: json['token_id'],
      serverType: json['server_type'],
      name: json['name'] ?? 'Untitled Config',
      channelId: json['channel_id'],
      webhookUrl: json['webhook_url'],
      delay: json['delay'],
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      minDelay: json['min_delay'],
      maxDelay: json['max_delay'],
      message: json['message'],
      totalSent: json['total_sent'] ?? 0,
      status: json['status'] ?? false,
      nextRun: json['next_run'] != null ? DateTime.parse(json['next_run']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'token_id': tokenId,
      'server_type': serverType,
      'name': name,
      'channel_id': channelId,
      'webhook_url': webhookUrl,
      'delay': delay,
      'end_time': endTime?.toIso8601String(),
      'min_delay': minDelay,
      'max_delay': maxDelay,
      'message': message,
      'total_sent': totalSent,
      'status': status,
      'next_run': nextRun?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper methods
  String get serverDisplayName {
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

  String get statusDisplayText => status ? 'Active' : 'Inactive';

  bool get isExpired {
    if (endTime == null) return false;
    final jakartaEndTime = tz.TZDateTime.from(endTime!, TimezoneUtils.jakartaLocation);
    return jakartaEndTime.isBefore(TimezoneUtils.nowInJakarta());
  }

  bool get isActive => status && !isExpired;

  String get delayDisplayText {
    if (delay < 60) {
      return '${delay}s';
    } else if (delay < 3600) {
      final minutes = delay ~/ 60;
      final seconds = delay % 60;
      return seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
    } else {
      final hours = delay ~/ 3600;
      final minutes = (delay % 3600) ~/ 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }

  String get delayRangeDisplayText {
    return '${_formatDelay(minDelay)} - ${_formatDelay(maxDelay)}';
  }

  String _formatDelay(int delaySeconds) {
    if (delaySeconds < 60) {
      return '${delaySeconds}s';
    } else if (delaySeconds < 3600) {
      final minutes = delaySeconds ~/ 60;
      final seconds = delaySeconds % 60;
      return seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
    } else {
      final hours = delaySeconds ~/ 3600;
      final minutes = (delaySeconds % 3600) ~/ 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }

  DateTime? get endTimeInJakarta {
    if (endTime == null) return null;
    return tz.TZDateTime.from(endTime!, TimezoneUtils.jakartaLocation);
  }

  DateTime? get nextRunInJakarta {
    if (nextRun == null) return null;
    return tz.TZDateTime.from(nextRun!, TimezoneUtils.jakartaLocation);
  }

  // Copy with method for updates
  AutopostConfig copyWith({
    String? id,
    String? userId,
    String? tokenId,
    String? serverType,
    String? name,
    String? channelId,
    String? webhookUrl,
    int? delay,
    DateTime? endTime,
    int? minDelay,
    int? maxDelay,
    String? message,
    int? totalSent,
    bool? status,
    DateTime? nextRun,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AutopostConfig(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tokenId: tokenId ?? this.tokenId,
      serverType: serverType ?? this.serverType,
      name: name ?? this.name,
      channelId: channelId ?? this.channelId,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      delay: delay ?? this.delay,
      endTime: endTime ?? this.endTime,
      minDelay: minDelay ?? this.minDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      message: message ?? this.message,
      totalSent: totalSent ?? this.totalSent,
      status: status ?? this.status,
      nextRun: nextRun ?? this.nextRun,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Token model untuk dropdown selection
class TokenOption {
  final String id;
  final String name;
  final String discordId;
  final String? avatarUrl;
  final bool status;

  TokenOption({
    required this.id,
    required this.name,
    required this.discordId,
    this.avatarUrl,
    required this.status,
  });

  factory TokenOption.fromJson(Map<String, dynamic> json) {
    return TokenOption(
      id: json['id'],
      name: json['name'],
      discordId: json['discord_id'],
      avatarUrl: json['avatar_url'],
      status: json['status'] ?? false,
    );
  }

  String get displayName => '$name (${discordId.length > 10 ? '${discordId.substring(0, 10)}...' : discordId})';
}
