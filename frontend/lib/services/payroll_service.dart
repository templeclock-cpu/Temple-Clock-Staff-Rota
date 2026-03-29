import 'dart:convert';
import '../models/payroll_model.dart';
import 'api_service.dart';

class PayrollService {
  final ApiService _apiService;

  PayrollService(this._apiService);

  Future<Map<String, dynamic>> generatePayroll(String month, {String? staffId}) async {
    final body = <String, dynamic>{'month': month};
    if (staffId != null) body['staffId'] = staffId;

    final response = await _apiService.post('/payroll/generate', body);
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return data as Map<String, dynamic>;
    }
    throw Exception(data['message'] ?? 'Failed to generate payroll');
  }

  Future<List<PayrollRecord>> getPayroll({String? month}) async {
    final endpoint = month != null ? '/payroll?month=$month' : '/payroll';
    final response = await _apiService.get(endpoint);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final list = data is List ? data : (data['payroll'] ?? []);
      return (list as List).map((e) => PayrollRecord.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch payroll');
  }

  Future<List<PayrollRecord>> getStaffPayroll(String staffId, {String? month}) async {
    final q = month != null ? '?month=$month' : '';
    final response = await _apiService.get('/payroll/$staffId$q');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final list = data is List ? data : (data['payroll'] ?? []);
      return (list as List).map((e) => PayrollRecord.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch staff payroll');
  }

  Future<PayrollRecord> addAdjustment(String payrollId, String description, double amount) async {
    final response = await _apiService.put('/payroll/$payrollId/adjust', {
      'description': description,
      'amount': amount,
    });
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return PayrollRecord.fromJson(data);
    }
    throw Exception(data['message'] ?? 'Failed to add adjustment');
  }

  Future<PayrollRecord> finalizePayroll(String payrollId) async {
    final response = await _apiService.put('/payroll/$payrollId/finalize', {});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return PayrollRecord.fromJson(data);
    }
    throw Exception(data['message'] ?? 'Failed to finalize payroll');
  }
}
