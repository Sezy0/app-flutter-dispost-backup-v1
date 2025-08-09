import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

class ImageUploadService {
  static const String _apiKey = '122200c007afc09e82621cfc0b7e74ff';
  static const String _baseUrl = 'https://api.imgbb.com/1/upload';

  /// Upload image file to imgbb
  static Future<Map<String, dynamic>> uploadImage(File imageFile) async {
    try {
      // Read file as bytes
      final bytes = await imageFile.readAsBytes();
      
      // Convert to base64
      final base64String = base64Encode(bytes);
      
      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(_baseUrl));
      
      // Add API key
      request.fields['key'] = _apiKey;
      
      // Add image data
      request.fields['image'] = base64String;
      
      // Add optional fields
      request.fields['name'] = 'payment_proof_${DateTime.now().millisecondsSinceEpoch}';
      
      // Send request
      final response = await request.send();
      
      // Get response body
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseBody);
      
      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        return {
          'success': true,
          'data': jsonResponse['data'],
          'url': jsonResponse['data']['url'],
          'display_url': jsonResponse['data']['display_url'],
          'delete_url': jsonResponse['data']['delete_url'],
        };
      } else {
        return {
          'success': false,
          'error': jsonResponse['error']?['message'] ?? 'Upload failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Upload failed: $e',
      };
    }
  }

  /// Upload image from bytes
  static Future<Map<String, dynamic>> uploadImageFromBytes(
    List<int> bytes, 
    String fileName
  ) async {
    try {
      // Convert to base64
      final base64String = base64Encode(bytes);
      
      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(_baseUrl));
      
      // Add API key
      request.fields['key'] = _apiKey;
      
      // Add image data
      request.fields['image'] = base64String;
      
      // Add optional fields
      request.fields['name'] = 'payment_proof_${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      // Send request
      final response = await request.send();
      
      // Get response body
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseBody);
      
      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        return {
          'success': true,
          'data': jsonResponse['data'],
          'url': jsonResponse['data']['url'],
          'display_url': jsonResponse['data']['display_url'],
          'delete_url': jsonResponse['data']['delete_url'],
        };
      } else {
        return {
          'success': false,
          'error': jsonResponse['error']?['message'] ?? 'Upload failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Upload failed: $e',
      };
    }
  }

  /// Validate image file
  static bool isValidImageFile(File file) {
    final mimeType = lookupMimeType(file.path);
    if (mimeType == null) return false;
    
    final allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
    return allowedTypes.contains(mimeType);
  }

  /// Get file size in MB
  static double getFileSizeInMB(File file) {
    final bytes = file.lengthSync();
    return bytes / (1024 * 1024);
  }

  /// Check if file size is within limit (imgbb max: 32MB)
  static bool isFileSizeValid(File file) {
    return getFileSizeInMB(file) <= 32;
  }
}
