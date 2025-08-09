import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_account.dart';

class PaymentAccountService {
  static final _supabase = Supabase.instance.client;

  /// Mendapatkan semua payment accounts yang aktif
  static Future<List<PaymentAccount>> getActivePaymentAccounts() async {
    try {
      final response = await _supabase.rpc('get_active_payment_accounts');
      
      final responseList = response as List<dynamic>? ?? [];
      return responseList
          .map((json) => PaymentAccount.fromSupabaseMap(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting active payment accounts: $e');
      throw Exception('Failed to load payment accounts: $e');
    }
  }

  /// Mendapatkan payment accounts berdasarkan type (ewallet/bank)
  static Future<List<PaymentAccount>> getPaymentAccountsByType(String type) async {
    try {
      final response = await _supabase.rpc('get_payment_accounts_by_type', params: {
        'payment_type': type,
      });
      
      final responseList = response as List<dynamic>? ?? [];
      return responseList
          .map((json) => PaymentAccount.fromSupabaseMap(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting payment accounts by type: $e');
      throw Exception('Failed to load payment accounts by type: $e');
    }
  }

  /// Mendapatkan payment account berdasarkan provider
  static Future<PaymentAccount?> getPaymentAccountByProvider(String provider) async {
    try {
      final response = await _supabase.rpc('get_payment_account_by_provider', params: {
        'provider_name': provider,
      });
      
      if (response == null) {
        return null;
      }
      
      final responseList = response as List;
      if (responseList.isEmpty) {
        return null;
      }
      
      return PaymentAccount.fromSupabaseMap(responseList.first);
    } catch (e) {
      debugPrint('Error getting payment account by provider: $e');
      return null;
    }
  }

  /// Mendapatkan semua e-wallet accounts
  static Future<List<PaymentAccount>> getEWalletAccounts() async {
    return await getPaymentAccountsByType('ewallet');
  }

  /// Mendapatkan semua bank accounts
  static Future<List<PaymentAccount>> getBankAccounts() async {
    return await getPaymentAccountsByType('bank');
  }

  /// Mendapatkan account ShopeePay
  static Future<PaymentAccount?> getShopeepayAccount() async {
    return await getPaymentAccountByProvider('shopeepay');
  }

  /// Mendapatkan account Dana
  static Future<PaymentAccount?> getDanaAccount() async {
    return await getPaymentAccountByProvider('dana');
  }

  /// Mendapatkan account SeaBank
  static Future<PaymentAccount?> getSeabankAccount() async {
    return await getPaymentAccountByProvider('seabank');
  }

  /// Mendapatkan QRIS account
  static Future<PaymentAccount?> getQRISAccount() async {
    return await getPaymentAccountByProvider('qris');
  }

  /// Mendapatkan semua QRIS accounts
  static Future<List<PaymentAccount>> getQRISAccounts() async {
    return await getPaymentAccountsByType('qris');
  }

  /// Format nomor rekening untuk ditampilkan
  static String formatAccountNumber(PaymentAccount account) {
    if (account.type == 'ewallet') {
      // Format nomor telepon untuk e-wallet
      String number = account.accountNumber;
      if (number.length >= 10) {
        return '${number.substring(0, 4)}-${number.substring(4, 8)}-${number.substring(8)}';
      }
      return number;
    } else {
      // Format nomor rekening bank
      String number = account.accountNumber;
      if (number.length >= 8) {
        return '${number.substring(0, 4)} ${number.substring(4, 8)} ${number.substring(8)}';
      }
      return number;
    }
  }

  /// Mendapatkan icon provider
  static String getProviderIcon(String provider) {
    switch (provider.toLowerCase()) {
      case 'shopeepay':
        return '🛒';
      case 'dana':
        return '💰';
      case 'seabank':
        return '🏦';
      case 'gopay':
        return '🏍️';
      case 'ovo':
        return '🔵';
      case 'bca':
        return '🏧';
      case 'bni':
        return '🟠';
      case 'bri':
        return '🔷';
      case 'mandiri':
        return '🟡';
      case 'qris':
        return '📱';
      default:
        return '💳';
    }
  }

  /// Mendapatkan warna provider
  static String getProviderColor(String provider) {
    switch (provider.toLowerCase()) {
      case 'shopeepay':
        return '#FF6600';
      case 'dana':
        return '#1890FF';
      case 'seabank':
        return '#00A6E8';
      case 'gopay':
        return '#00AED6';
      case 'ovo':
        return '#5A47AB';
      case 'bca':
        return '#0066CC';
      case 'bni':
        return '#FF8C00';
      case 'bri':
        return '#003399';
      case 'mandiri':
        return '#FFD700';
      case 'qris':
        return '#8B5CF6';
      default:
        return '#6B7280';
    }
  }

  /// Mendapatkan display name provider
  static String getProviderDisplayName(String provider) {
    switch (provider.toLowerCase()) {
      case 'shopeepay':
        return 'ShopeePay';
      case 'dana':
        return 'DANA';
      case 'seabank':
        return 'SeaBank';
      case 'gopay':
        return 'GoPay';
      case 'ovo':
        return 'OVO';
      case 'bca':
        return 'BCA';
      case 'bni':
        return 'BNI';
      case 'bri':
        return 'BRI';
      case 'mandiri':
        return 'Mandiri';
      case 'qris':
        return 'QRIS';
      default:
        return provider.toUpperCase();
    }
  }

  /// Validasi apakah provider mendukung QR code
  static bool supportsQRCode(String provider) {
    switch (provider.toLowerCase()) {
      case 'shopeepay':
      case 'dana':
      case 'gopay':
      case 'ovo':
        return true;
      default:
        return false;
    }
  }

  /// Cache untuk performa (opsional - bisa diimplementasi kemudian)
  static final Map<String, List<PaymentAccount>> _cache = {};
  static DateTime? _lastCacheUpdate;
  static const int _cacheValidityMinutes = 30;

  /// Clear cache
  static void clearCache() {
    _cache.clear();
    _lastCacheUpdate = null;
  }

  /// Check if cache is valid
  static bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!).inMinutes < _cacheValidityMinutes;
  }

  /// Get cached data atau fetch baru
  static Future<List<PaymentAccount>> getCachedActivePaymentAccounts() async {
    const cacheKey = 'active_accounts';
    
    if (_isCacheValid() && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final accounts = await getActivePaymentAccounts();
    _cache[cacheKey] = accounts;
    _lastCacheUpdate = DateTime.now();
    
    return accounts;
  }
}
