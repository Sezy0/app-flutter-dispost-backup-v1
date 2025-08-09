import 'package:dispost_autopost/core/services/autopost_config_service.dart';

/// Utility class untuk validasi konfigurasi autopost
/// Menyediakan validasi yang konsisten di seluruh aplikasi
class ConfigValidationUtils {
  
  /// Validasi Channel ID Discord
  /// Channel ID harus berupa angka 17-20 digit
  static String? validateChannelId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Channel ID is required';
    }
    
    final cleanValue = value.trim();
    if (!AutopostConfigService.isValidChannelId(cleanValue)) {
      return 'Channel ID must be 17-20 digits';
    }
    
    return null;
  }
  
  /// Validasi Webhook URL Discord
  /// URL webhook bersifat opsional, tapi jika diisi harus format yang valid
  static String? validateWebhookUrl(String? value) {
    final cleanValue = value?.trim();
    if (cleanValue != null && cleanValue.isNotEmpty) {
      if (!AutopostConfigService.isValidWebhookUrl(cleanValue)) {
        return 'Invalid Discord webhook URL format';
      }
    }
    return null;
  }
  
  /// Validasi delay (dalam detik)
  /// Delay harus antara 10 detik hingga 24 jam (86400 detik)
  static String? validateDelay(String? value, {String fieldName = 'Delay'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    final delay = int.tryParse(value.trim());
    if (delay == null) {
      return '$fieldName must be a number';
    }
    
    if (!AutopostConfigService.isValidDelay(delay)) {
      return '$fieldName must be 10-86400 seconds';
    }
    
    return null;
  }
  
  /// Validasi hierarchy delay (min <= delay <= max)
  /// Memastikan urutan delay yang logis
  static String? validateDelayHierarchy({
    required int minDelay,
    required int delay,
    required int maxDelay,
  }) {
    if (!AutopostConfigService.isValidDelayHierarchy(minDelay, delay, maxDelay)) {
      return 'Invalid delay hierarchy: Min (${minDelay}s) ≤ Delay (${delay}s) ≤ Max (${maxDelay}s)';
    }
    return null;
  }
  
  /// Validasi konten pesan
  /// Pesan harus ada dan tidak boleh lebih dari 2000 karakter
  static String? validateMessage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Message content is required';
    }
    
    final cleanValue = value.trim();
    if (cleanValue.length > 2000) {
      return 'Message too long (${cleanValue.length}/2000 characters)';
    }
    
    return null;
  }
  
  /// Validasi token selection
  /// Token harus dipilih dari dropdown
  static String? validateTokenSelection(dynamic value) {
    if (value == null) {
      return 'Please select a Discord token';
    }
    return null;
  }
  
  /// Validasi waktu akhir (end time)
  /// Jika diset, waktu harus di masa depan
  static String? validateEndTime(DateTime? endTime) {
    if (endTime != null) {
      final now = DateTime.now();
      if (endTime.isBefore(now)) {
        return 'End time must be in the future';
      }
    }
    return null;
  }
  
  /// Format error message untuk delay hierarchy
  static String formatDelayHierarchyError({
    required int minDelay,
    required int delay,
    required int maxDelay,
  }) {
    return 'Invalid delay configuration:\n'
           'Min Delay: ${minDelay}s\n'
           'Delay: ${delay}s\n'
           'Max Delay: ${maxDelay}s\n'
           'Required: Min ≤ Delay ≤ Max';
  }
  
  /// Validasi semua field sekaligus untuk create config
  static Map<String, String> validateCreateConfig({
    required String? channelId,
    required String? webhookUrl,
    required String? delayStr,
    required String? minDelayStr,
    required String? maxDelayStr,
    required String? message,
    required dynamic selectedToken,
    DateTime? endTime,
  }) {
    Map<String, String> errors = {};
    
    // Validasi channel ID
    final channelError = validateChannelId(channelId);
    if (channelError != null) {
      errors['channel_id'] = channelError;
    }
    
    // Validasi webhook URL
    final webhookError = validateWebhookUrl(webhookUrl);
    if (webhookError != null) {
      errors['webhook_url'] = webhookError;
    }
    
    // Validasi delays
    final minDelayError = validateDelay(minDelayStr, fieldName: 'Min Delay');
    if (minDelayError != null) {
      errors['min_delay'] = minDelayError;
    }
    
    final delayError = validateDelay(delayStr, fieldName: 'Delay');
    if (delayError != null) {
      errors['delay'] = delayError;
    }
    
    final maxDelayError = validateDelay(maxDelayStr, fieldName: 'Max Delay');
    if (maxDelayError != null) {
      errors['max_delay'] = maxDelayError;
    }
    
    // Validasi delay hierarchy jika semua delay valid
    if (minDelayError == null && delayError == null && maxDelayError == null) {
      final minDelay = int.parse(minDelayStr!.trim());
      final delay = int.parse(delayStr!.trim());
      final maxDelay = int.parse(maxDelayStr!.trim());
      
      final hierarchyError = validateDelayHierarchy(
        minDelay: minDelay,
        delay: delay,
        maxDelay: maxDelay,
      );
      
      if (hierarchyError != null) {
        errors['delay_hierarchy'] = hierarchyError;
      }
    }
    
    // Validasi message
    final messageError = validateMessage(message);
    if (messageError != null) {
      errors['message'] = messageError;
    }
    
    // Validasi token
    final tokenError = validateTokenSelection(selectedToken);
    if (tokenError != null) {
      errors['token'] = tokenError;
    }
    
    // Validasi end time
    final endTimeError = validateEndTime(endTime);
    if (endTimeError != null) {
      errors['end_time'] = endTimeError;
    }
    
    return errors;
  }
  
  /// Check apakah semua validasi berhasil
  static bool isValidConfig({
    required String? channelId,
    required String? webhookUrl,
    required String? delayStr,
    required String? minDelayStr,
    required String? maxDelayStr,
    required String? message,
    required dynamic selectedToken,
    DateTime? endTime,
  }) {
    final errors = validateCreateConfig(
      channelId: channelId,
      webhookUrl: webhookUrl,
      delayStr: delayStr,
      minDelayStr: minDelayStr,
      maxDelayStr: maxDelayStr,
      message: message,
      selectedToken: selectedToken,
      endTime: endTime,
    );
    
    return errors.isEmpty;
  }
  
  /// Get formatted delay display text
  static String formatDelayDisplay(int delayInSeconds) {
    if (delayInSeconds < 60) {
      return '${delayInSeconds}s';
    } else if (delayInSeconds < 3600) {
      final minutes = delayInSeconds ~/ 60;
      final seconds = delayInSeconds % 60;
      return seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
    } else {
      final hours = delayInSeconds ~/ 3600;
      final minutes = (delayInSeconds % 3600) ~/ 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }
  
  /// Parse delay dari string ke integer
  static int? parseDelay(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return int.tryParse(value.trim());
  }
  
  /// Sanitize input string
  static String sanitizeInput(String? input) {
    if (input == null) return '';
    return input.trim();
  }
}
