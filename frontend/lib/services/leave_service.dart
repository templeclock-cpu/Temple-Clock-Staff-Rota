import 'dart:convert';
import '../models/leave_model.dart';
import 'api_service.dart';

class LeaveService {
  final ApiService _apiService;

  LeaveService(this._apiService);

  Future<List<LeaveRequest>> getLeaveRequests({
    String? status,
    String? staffId,
    String? leaveType,
  }) async {
    final query = <String>[];
    if (status != null && status.isNotEmpty) query.add('status=$status');
    if (staffId != null && staffId.isNotEmpty) query.add('staffId=$staffId');
    if (leaveType != null && leaveType.isNotEmpty) query.add('leaveType=$leaveType');

    final endpoint = query.isEmpty ? '/leave' : '/leave?${query.join('&')}';
    final response = await _apiService.get(endpoint);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final list = data is List ? data : (data['leaves'] ?? data['records'] ?? []);
      return (list as List<dynamic>)
          .map((item) => LeaveRequest.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    throw Exception('Failed to fetch leave requests');
  }

  Future<LeaveRequest> createLeaveRequest({
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    final response = await _apiService.post('/leave', {
      'leaveType': leaveType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'reason': reason ?? '',
    });

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return LeaveRequest.fromJson(data as Map<String, dynamic>);
    }

    throw Exception(data['message'] ?? 'Failed to create leave request');
  }

  Future<LeaveRequest> approveLeave(String leaveId) async {
    final response = await _apiService.put('/leave/$leaveId/approve', {});
    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return LeaveRequest.fromJson(data as Map<String, dynamic>);
    }

    throw Exception(data['message'] ?? 'Failed to approve leave request');
  }

  Future<LeaveRequest> rejectLeave(String leaveId, {String reason = ''}) async {
    final response = await _apiService.put('/leave/$leaveId/reject', {
      'reason': reason,
    });
    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return LeaveRequest.fromJson(data as Map<String, dynamic>);
    }

    throw Exception(data['message'] ?? 'Failed to reject leave request');
  }

  Future<LeaveRequest> cancelLeave(String leaveId) async {
    final response = await _apiService.put('/leave/$leaveId/cancel', {});
    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return LeaveRequest.fromJson(data as Map<String, dynamic>);
    }

    throw Exception(data['message'] ?? 'Failed to cancel leave request');
  }

  Future<Map<String, dynamic>> getLeaveBalance(String staffId) async {
    final response = await _apiService.get('/leave/balance/$staffId');
    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data as Map<String, dynamic>;
    }

    throw Exception(data['message'] ?? 'Failed to fetch leave balance');
  }
}
