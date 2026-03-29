import 'dart:convert';
import '../models/user_model.dart';
import 'api_service.dart';

class UserService {
  final ApiService _apiService;

  UserService(this._apiService);

  Future<List<UserModel>> getUsers() async {
    final response = await _apiService.get('/users');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final list = data is List ? data : (data['users'] ?? []);
      return (list as List).map((e) => UserModel.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch users');
  }

  Future<UserModel> getUserById(String id) async {
    final response = await _apiService.get('/users/$id');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return UserModel.fromJson(data);
    }
    throw Exception(data['message'] ?? 'Failed to fetch user');
  }

  Future<UserModel> createUser({
    required String name,
    required String email,
    required String password,
    String role = 'staff',
    double hourlyRate = 0,
    String phone = '',
    String department = '',
  }) async {
    final response = await _apiService.post('/users', {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      'hourlyRate': hourlyRate,
      'phone': phone,
      'department': department,
    });
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return UserModel.fromJson(data);
    }
    throw Exception(data['message'] ?? 'Failed to create user');
  }

  Future<UserModel> updateUser(String id, Map<String, dynamic> fields) async {
    final response = await _apiService.put('/users/$id', fields);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return UserModel.fromJson(data);
    }
    throw Exception(data['message'] ?? 'Failed to update user');
  }

  Future<void> deleteUser(String id) async {
    final response = await _apiService.delete('/users/$id');
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to deactivate user');
    }
  }
}
