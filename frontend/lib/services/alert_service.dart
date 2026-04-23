import 'dart:convert';
import 'api_service.dart';
import '../models/alert_model.dart';

class AlertService {
  final ApiService _apiService;

  AlertService(this._apiService);

  // ─── Staff: Report a delay for a specific domiciliary visit ─────────────────
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
    });

    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to report delay');
    }
  }

  // ─── Admin: Get ALL alerts sent by staff to the office ──────────────────────
  Future<List<AlertModel>> getAlerts() async {
    final response = await _apiService.get('/alerts');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => AlertModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch alerts');
    }
  }

  // ─── Admin: Mark an alert as read ───────────────────────────────────────────
  Future<void> markAlertRead(String alertId) async {
    final response = await _apiService.put('/alerts/$alertId/read', {});
    if (response.statusCode != 200) {
      throw Exception('Failed to mark alert as read');
    }
  }

  // ─── Admin: Send a notice to a specific staff member ────────────────────────
  Future<void> sendAlertToStaff(String targetStaffId, String message) async {
    final response = await _apiService.post('/alerts', {
      'alertType': 'admin_notice',
      'message': message,
      'targetStaffId': targetStaffId,
    });

    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to send notice');
    }
  }

  // ─── Staff: Get alerts targeted to current user (typed AlertModel list) ─────
  Future<List<AlertModel>> getMyAlerts({bool unreadOnly = false}) async {
    final response = await _apiService.get('/alerts?unreadOnly=$unreadOnly');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => AlertModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch notifications');
    }
  }

  // ─── Staff: Get count of unread alerts ──────────────────────────────────────
  Future<int> getMyUnreadCount() async {
    final alerts = await getMyAlerts(unreadOnly: true);
    return alerts.length;
  }

  // ─── Shared: Mark as read (generic — alias used by admin dashboard) ──────────
  Future<void> markAsRead(String alertId) => markAlertRead(alertId);

  // ─── Staff: Mark alert as read by staff (alias used by staff dashboard) ──────
  Future<void> markAlertReadByStaff(String alertId) => markAlertRead(alertId);
}
