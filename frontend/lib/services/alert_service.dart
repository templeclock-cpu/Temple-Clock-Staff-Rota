import 'dart:convert';
import 'api_service.dart';

class AlertService {
  final ApiService _apiService;

  AlertService(this._apiService);

  /// Report a delay for a specific domiciliary visit
  Future<void> reportDelay({
    required String shiftId,
    required String clientId,
    required int estimatedDelayMinutes,
    required String message,
  }) async {
    final response = await _apiService.post('/alerts', {
      'shiftId': shiftId,
      'alertType': 'running_late',
      'message': 'Visit Delay: $message',
      'estimatedDelay': estimatedDelayMinutes,
      // Target is implicit (head office/admin)
    });

    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to report delay');
    }
  }

  /// Get alerts targeted to the current staff member (e.g., admin notices)
  Future<List<dynamic>> getMyAlerts({bool unreadOnly = false}) async {
    final response = await _apiService.get('/alerts?unreadOnly=$unreadOnly');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch notifications');
    }
  }

  /// Mark an alert as read
  Future<void> markAsRead(String alertId) async {
    final response = await _apiService.put('/alerts/$alertId/read', {});
    if (response.statusCode != 200) {
      throw Exception('Failed to update notification status');
    }
  }
}
