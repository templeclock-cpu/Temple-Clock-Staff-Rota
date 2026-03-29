import 'dart:convert';
import '../models/alert_model.dart';
import 'api_service.dart';

class AlertService {
  final ApiService _apiService;

  AlertService(this._apiService);

  /// Staff sends a running-late or emergency alert
  Future<AlertModel> createAlert({
    String? shiftId,
    String alertType = 'running_late',
    String message = '',
    int estimatedDelay = 0,
  }) async {
    final response = await _apiService.post('/alerts', {
      if (shiftId != null) 'shiftId': shiftId,
      'alertType': alertType,
      'message': message,
      'estimatedDelay': estimatedDelay,
    });
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return AlertModel.fromJson(data);
    }
    throw Exception(data['message'] ?? 'Failed to create alert');
  }

  /// Admin sends a notice to a specific staff member
  Future<AlertModel> sendAlertToStaff(String targetStaffId, String message) async {
    final response = await _apiService.post('/alerts/send', {
      'targetStaffId': targetStaffId,
      'message': message,
    });
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return AlertModel.fromJson(data);
    }
    throw Exception(data['message'] ?? 'Failed to send alert');
  }

  /// Admin: get all alerts
  Future<List<AlertModel>> getAlerts() async {
    final response = await _apiService.get('/alerts');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final list = data is List ? data : (data['alerts'] ?? []);
      return (list as List).map((e) => AlertModel.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch alerts');
  }

  /// Staff: get my alerts (notices from admin)
  Future<List<AlertModel>> getMyAlerts() async {
    final response = await _apiService.get('/alerts/my');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final list = data is List ? data : (data['alerts'] ?? []);
      return (list as List).map((e) => AlertModel.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch my alerts');
  }

  /// Admin: unread count
  Future<int> getUnreadCount() async {
    final response = await _apiService.get('/alerts/unread-count');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data['count'] ?? 0;
    }
    return 0;
  }

  /// Staff: unread count
  Future<int> getMyUnreadCount() async {
    final response = await _apiService.get('/alerts/my/unread-count');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data['count'] ?? 0;
    }
    return 0;
  }

  /// Admin marks alert as read
  Future<void> markAlertRead(String alertId) async {
    await _apiService.put('/alerts/$alertId/read', {});
  }

  /// Staff marks their alert as read
  Future<void> markAlertReadByStaff(String alertId) async {
    await _apiService.put('/alerts/$alertId/read-staff', {});
  }
}
