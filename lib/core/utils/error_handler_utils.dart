import 'package:flutter/material.dart';
import 'package:dispost_autopost/core/widgets/custom_notification.dart';

/// Utility class untuk menangani error dan memberikan pesan yang user-friendly
class ErrorHandlerUtils {
  
  /// Handle error untuk operasi config (create/update/delete)
  static void handleConfigError(
    BuildContext context, 
    dynamic error, {
    String? operation,
  }) {
    final operationType = operation ?? 'operation';
    String errorMessage = 'Error during $operationType';
    
    if (error != null) {
      final errorStr = error.toString().toLowerCase();
      
      if (errorStr.contains('timeout')) {
        errorMessage = 'Request timed out. Please check your internet connection and try again.';
      } else if (errorStr.contains('not found') || errorStr.contains('404')) {
        errorMessage = 'Configuration not found. It may have been deleted.';
      } else if (errorStr.contains('permission') || errorStr.contains('403')) {
        errorMessage = 'You do not have permission to perform this action.';
      } else if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
        errorMessage = 'Session expired. Please log in again.';
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (errorStr.contains('server') || errorStr.contains('500')) {
        errorMessage = 'Server error. Please try again later.';
      } else if (errorStr.contains('validation')) {
        errorMessage = 'Invalid data. Please check your input.';
      } else if (errorStr.contains('limit') || errorStr.contains('quota')) {
        errorMessage = 'You have reached your limit. Please upgrade your plan.';
      } else if (errorStr.contains('duplicate')) {
        errorMessage = 'This configuration already exists.';
      } else {
        // Generic error with first part of actual error
        final cleanError = error.toString().split('\n').first;
        if (cleanError.length > 100) {
          errorMessage = '${cleanError.substring(0, 100)}...';
        } else {
          errorMessage = cleanError;
        }
      }
    }
    
    showCustomNotification(
      context,
      errorMessage,
      backgroundColor: Colors.red,
    );
  }
  
  /// Handle success untuk operasi config
  static void handleConfigSuccess(
    BuildContext context,
    String operation,
  ) {
    String message;
    switch (operation.toLowerCase()) {
      case 'create':
      case 'created':
        message = '✅ Configuration created successfully!';
        break;
      case 'update':
      case 'updated':
        message = '✅ Configuration updated successfully!';
        break;
      case 'delete':
      case 'deleted':
        message = '✅ Configuration deleted successfully!';
        break;
      case 'activate':
      case 'activated':
        message = '✅ Configuration activated successfully!';
        break;
      case 'deactivate':
      case 'deactivated':
        message = '✅ Configuration deactivated successfully!';
        break;
      default:
        message = '✅ Operation completed successfully!';
    }
    
    showCustomNotification(
      context,
      message,
      backgroundColor: Colors.green,
    );
  }
  
  /// Handle validation errors
  static void handleValidationErrors(
    BuildContext context,
    Map<String, String> errors,
  ) {
    if (errors.isEmpty) return;
    
    if (errors.length == 1) {
      // Single error
      final error = errors.values.first;
      showCustomNotification(
        context,
        error,
        backgroundColor: Colors.orange,
      );
    } else {
      // Multiple errors - show the most important one
      final priority = [
        'token',
        'channel_id',
        'message',
        'delay_hierarchy',
        'delay',
        'min_delay',
        'max_delay',
        'end_time',
        'webhook_url',
      ];
      
      String? errorToShow;
      for (String key in priority) {
        if (errors.containsKey(key)) {
          errorToShow = errors[key];
          break;
        }
      }
      
      showCustomNotification(
        context,
        errorToShow ?? errors.values.first,
        backgroundColor: Colors.orange,
      );
    }
  }
  
  /// Handle loading data errors
  static void handleDataLoadError(
    BuildContext context,
    dynamic error, {
    String dataType = 'data',
  }) {
    String errorMessage = 'Failed to load $dataType';
    
    if (error != null) {
      final errorStr = error.toString().toLowerCase();
      
      if (errorStr.contains('timeout')) {
        errorMessage = 'Loading timed out. Please try refreshing.';
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        errorMessage = 'Network error. Please check your connection and try refreshing.';
      } else if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
        errorMessage = 'Session expired. Please log in again.';
      } else {
        errorMessage = 'Failed to load $dataType. Please try refreshing.';
      }
    }
    
    showCustomNotification(
      context,
      errorMessage,
      backgroundColor: Colors.red,
    );
  }
  
  /// Handle token-related errors
  static void handleTokenError(
    BuildContext context,
    dynamic error,
  ) {
    String errorMessage = 'Token error';
    
    if (error != null) {
      final errorStr = error.toString().toLowerCase();
      
      if (errorStr.contains('invalid')) {
        errorMessage = 'Invalid Discord token. Please check your token.';
      } else if (errorStr.contains('expired') || errorStr.contains('unauthorized')) {
        errorMessage = 'Token expired or invalid. Please update your token.';
      } else if (errorStr.contains('duplicate')) {
        errorMessage = 'This Discord account is already added.';
      } else if (errorStr.contains('network')) {
        errorMessage = 'Cannot verify token. Please check your internet connection.';
      } else {
        errorMessage = 'Token validation failed. Please try again.';
      }
    }
    
    showCustomNotification(
      context,
      errorMessage,
      backgroundColor: Colors.red,
    );
  }
  
  /// Handle permission/access errors
  static void handleAccessError(
    BuildContext context, {
    String? feature,
  }) {
    String message = feature != null 
        ? 'You need a valid plan to access $feature'
        : 'Access denied. Please upgrade your plan.';
        
    showCustomNotification(
      context,
      message,
      backgroundColor: Colors.orange,
    );
  }
  
  /// Handle quota/limit errors
  static void handleQuotaError(
    BuildContext context, {
    String? resourceType,
  }) {
    String message = resourceType != null
        ? 'You have reached your $resourceType limit'
        : 'You have reached your limit';
        
    message += '. Please upgrade your plan for more resources.';
    
    showCustomNotification(
      context,
      message,
      backgroundColor: Colors.orange,
    );
  }
  
  /// Show info message
  static void showInfo(
    BuildContext context,
    String message, {
    String? emoji,
  }) {
    final displayMessage = emoji != null ? '$emoji $message' : message;
    showCustomNotification(
      context,
      displayMessage,
      backgroundColor: Colors.blue,
    );
  }
  
  /// Show warning message
  static void showWarning(
    BuildContext context,
    String message, {
    String? emoji,
  }) {
    final displayMessage = emoji != null ? '$emoji $message' : message;
    showCustomNotification(
      context,
      displayMessage,
      backgroundColor: Colors.orange,
    );
  }
  
  /// Show success message
  static void showSuccess(
    BuildContext context,
    String message, {
    String? emoji,
  }) {
    final displayMessage = emoji != null ? '$emoji $message' : '✅ $message';
    showCustomNotification(
      context,
      displayMessage,
      backgroundColor: Colors.green,
    );
  }
  
  /// Extract user-friendly message from exception
  static String extractUserFriendlyMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred';
    
    final errorStr = error.toString();
    
    // Common error patterns
    if (errorStr.contains('SocketException') || errorStr.contains('NetworkException')) {
      return 'Network connection error. Please check your internet.';
    }
    
    if (errorStr.contains('TimeoutException')) {
      return 'Request timed out. Please try again.';
    }
    
    if (errorStr.contains('FormatException')) {
      return 'Invalid data format received from server.';
    }
    
    if (errorStr.contains('PostgrestException')) {
      // Supabase-specific errors
      if (errorStr.contains('duplicate key')) {
        return 'This item already exists.';
      }
      if (errorStr.contains('foreign key')) {
        return 'Referenced item not found.';
      }
      if (errorStr.contains('not found')) {
        return 'Item not found.';
      }
      if (errorStr.contains('unauthorized')) {
        return 'Access denied.';
      }
    }
    
    // Return first line of error if it's reasonable length
    final firstLine = errorStr.split('\n').first.trim();
    if (firstLine.length <= 100) {
      return firstLine;
    }
    
    return 'An error occurred. Please try again.';
  }
  
  /// Log error for debugging (only in debug mode)
  static void logError(String operation, dynamic error, [StackTrace? stackTrace]) {
    debugPrint('❌ Error in $operation: $error');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
  }
}
