import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DiscordWebhookService {
  // Webhook for paid purchases
  static const String _purchaseWebhookUrl = 'https://discord.com/api/webhooks/1390292571862990908/F1uVZh_J20ZrqP4JJboJ-slrKDjF1PlFuwknvMZppn8356JupFKrpSRL5e-tEETjW51p';
  
  // Webhook for free plan claims
  static const String _freeClaimWebhookUrl = 'https://discord.com/api/webhooks/1402284189205663776/e3j81HQgMHP798Xy716l4bNqz4cMFK6riOzcc0oRDk2WJ6nkK5q36Xb3DEyMuirt_gkI';

  /// Send purchase notification to Discord
  static Future<bool> sendPurchaseNotification({
    required String userEmail,
    required String planName,
    required double finalPrice,
    required String paymentMethod,
    String? transactionId,
    String? notes,
    required String purchaseId,
    String? proofImageUrl,
  }) async {
    try {
      // Determine if this is a free plan
      bool isFreeplan = finalPrice == 0 || planName.toLowerCase().contains('free');
      
      // Select appropriate webhook URL
      String webhookUrl = isFreeplan ? _freeClaimWebhookUrl : _purchaseWebhookUrl;
      
      // Format the purchase amount
      String formattedPrice = _formatCurrency(finalPrice);
      
      // Create fields list explicitly
      final List<Map<String, Object>> fields = [
        {
          "name": "👤 Customer",
          "value": userEmail,
          "inline": true,
        },
        {
          "name": "📦 Plan",
          "value": planName,
          "inline": true,
        },
        {
          "name": "💰 Amount",
          "value": formattedPrice,
          "inline": true,
        },
        {
          "name": "💳 Payment Method",
          "value": _formatPaymentMethod(paymentMethod),
          "inline": true,
        },
        {
          "name": "🆔 Purchase ID",
          "value": purchaseId,
          "inline": true,
        },
        {
          "name": "⏰ Time",
          "value": DateTime.now().toString().substring(0, 19),
          "inline": true,
        },
      ];

      // Add transaction ID if available
      if (transactionId != null && transactionId.isNotEmpty) {
        fields.add({
          "name": "🧾 Transaction ID",
          "value": transactionId,
          "inline": false,
        });
      }

      // Add notes if available
      if (notes != null && notes.isNotEmpty) {
        fields.add({
          "name": "📝 Notes",
          "value": notes,
          "inline": false,
        });
      }

      // Add payment proof status field
      if (proofImageUrl != null && proofImageUrl.isNotEmpty) {
        fields.add({
          "name": "📸 Payment Proof",
          "value": "✅ Attached (see image below)",
          "inline": false,
        });
      } else {
        fields.add({
          "name": "📸 Payment Proof",
          "value": "❌ Not provided",
          "inline": false,
        });
      }

      // Create embed with proper typing
      final Map<String, Object> embed = {
        "title": isFreeplan 
            ? "🎁 Free Plan Claimed!" 
            : (proofImageUrl != null && proofImageUrl.isNotEmpty 
                ? "🛒 New Purchase with Payment Proof!" 
                : "🛒 New Purchase Alert!"),
        "color": isFreeplan 
            ? 0x00ff00 // Green color for free plans
            : (proofImageUrl != null && proofImageUrl.isNotEmpty 
                ? 0x00ff00 // Green color for purchases with proof
                : 0xffa500), // Orange color for purchases without proof
        "fields": fields,
        "footer": {
          "text": "DisPost App Purchase System",
        },
        "timestamp": DateTime.now().toIso8601String(),
      };

      // Add image if proof is provided
      if (proofImageUrl != null && proofImageUrl.isNotEmpty) {
        embed["image"] = {
          "url": proofImageUrl,
        };
      }

      final Map<String, Object> payload = {
        "username": "DisPost App",
        "avatar_url": "https://i.ibb.co.com/B5qwRyqF/Nama-Proyek-8.png",
        "embeds": [embed],
      };
      
      // Add role mention for paid purchases only (not for free plans)
      if (!isFreeplan) {
        payload["content"] = "<@&1336022376789573643>"; // Role mention for paid purchases
      }

      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 204) {
        debugPrint('Discord webhook sent successfully');
        return true;
      } else {
        debugPrint('Discord webhook failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error sending Discord webhook: $e');
      return false;
    }
  }


  /// Send test notification to verify webhook is working
  static Future<bool> sendTestNotification({bool usePurchaseWebhook = true}) async {
    try {
      // Select webhook URL
      String webhookUrl = usePurchaseWebhook ? _purchaseWebhookUrl : _freeClaimWebhookUrl;
      
      final Map<String, Object> embed = {
        "title": "🧪 Test Notification",
        "description": "This is a test notification from DisPost App.",
        "color": 0x0099ff, // Blue color
        "footer": {
          "text": "DisPost App Test System",
        },
        "timestamp": DateTime.now().toIso8601String(),
      };

      final Map<String, Object> payload = {
        "username": "DisPost App",
        "avatar_url": "https://i.ibb.co.com/B5qwRyqF/Nama-Proyek-8.png",
        "embeds": [embed],
      };

      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      return response.statusCode == 204;
    } catch (e) {
      debugPrint('Error sending test Discord webhook: $e');
      return false;
    }
  }

  /// Format currency for display
  static String _formatCurrency(double amount) {
    String formatted = amount.toStringAsFixed(0);
    
    // Add thousand separators
    formatted = formatted.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );

    return 'Rp $formatted';
  }

  /// Format payment method for display
  static String _formatPaymentMethod(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'bank':
        return '🏦 Bank Transfer';
      case 'ewallet':
        return '💳 E-Wallet';
      case 'qris':
        return '📱 QRIS';
      case 'manual':
        return '📄 Manual';
      default:
        return '💰 $paymentMethod';
    }
  }
}
