import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService;

  AuthService(this._apiService);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _apiService.post('/auth/login', {
      'email': email,
      'password': password,
    });
    
    final data = jsonDecode(response.body);
    
    if (response.statusCode == 200) {
      final token = data['token'] as String;
      // Server returns flat {_id, name, email, role, token, ...} — extract user fields
      final user = Map<String, dynamic>.from(data)..remove('token');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.tokenKey, token);
      await prefs.setString(AppConstants.userKey, jsonEncode(user));
      
      return {'success': true, 'user': user};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(AppConstants.userKey);
    if (userJson != null) {
      return jsonDecode(userJson);
    }
    return null;
  }

  Future<Map<String, dynamic>> resetPassword(String email, String newPassword) async {
    final response = await _apiService.put('/auth/reset-password', {
      'email': email,
      'newPassword': newPassword,
    });

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message'] ?? 'Password reset successfully'};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Password reset failed'};
    }
  }
}
