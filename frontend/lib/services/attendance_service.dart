import 'dart:convert';
import '../models/attendance_model.dart';
import 'api_service.dart';

class AttendanceService {
  static const int gracePeriodMinutes = 10;

  static final List<AttendanceRecord> allRecords = <AttendanceRecord>[];

  final ApiService _apiService;

  AttendanceService(this._apiService);

  Future<AttendanceRecord> clockIn({
    required String shiftId,
    double? latitude,
    double? longitude,
    String? photoPath,
  }) async {
    final body = <String, dynamic>{
      'shiftId': shiftId,
    };
    if (latitude != null && longitude != null) {
      body['location'] = {'lat': latitude, 'lng': longitude};
    }

    final response = await _apiService.post('/attendance/clock-in', body);

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      // Backend may return { attendance: {...} } or the record directly
      final record = data is Map && data.containsKey('attendance')
          ? data['attendance']
          : data;
      return _parseRecord(record);
    } else {
      throw Exception(data['message'] ?? 'Failed to clock in');
    }
  }

  Future<AttendanceRecord> clockOut({
    required String shiftId,
    double? latitude,
    double? longitude,
    String? photoPath,
  }) async {
    final body = <String, dynamic>{
      'shiftId': shiftId,
    };
    if (latitude != null && longitude != null) {
      body['location'] = {'lat': latitude, 'lng': longitude};
    }

    final response = await _apiService.post('/attendance/clock-out', body);

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // Backend may return { attendance: {...} } or the record directly
      final record = data is Map && data.containsKey('attendance')
          ? data['attendance']
          : data;
      return _parseRecord(record);
    } else {
      throw Exception(data['message'] ?? 'Failed to clock out');
    }
  }

  Future<List<AttendanceRecord>> getMyAttendance() async {
    final response = await _apiService.get('/attendance/my-history');
    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final List<dynamic> list = data is List ? data : (data['attendance'] ?? []);
      final records = list.map((item) => _parseRecord(item)).toList();

      // Keep a static mirror for pages that still use static accessors.
      allRecords
        ..clear()
        ..addAll(records);

      return records;
    } else {
      throw Exception('Failed to fetch attendance history');
    }
  }

  static List<AttendanceRecord> getRecordsForDate(DateTime date) {
    return allRecords.where((record) {
      final ts = record.clockInTime ?? record.scheduledStart;
      return ts.year == date.year && ts.month == date.month && ts.day == date.day;
    }).toList();
  }

  static List<AttendanceRecord> getRecordsForStaff(String staffId) {
    return allRecords.where((record) => record.staffId == staffId).toList();
  }

  static String formatLateMinutes(int lateMinutes) {
    if (lateMinutes <= 0) return 'On time';
    return '$lateMinutes min late';
  }

  static String formatExtraHours(double extraHours) {
    if (extraHours <= 0) return '0h';
    return '${extraHours.toStringAsFixed(2)}h';
  }

  Future<Map<String, dynamic>> getTodayAdminStats() async {
    final response = await _apiService.get('/attendance/stats/today');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {
      'activeShifts': 0,
      'lateCount': 0,
      'completedShifts': 0,
      'extraHoursTotal': 0.0,
    };
  }

  AttendanceRecord _parseRecord(Map<String, dynamic> json) {
    // staffId may be a populated object or a plain string
    String staffId = '';
    String staffName = '';
    if (json['staffId'] is Map) {
      final s = json['staffId'] as Map<String, dynamic>;
      staffId = s['_id'] ?? '';
      staffName = s['name'] ?? '';
    } else {
      staffId = json['staffId']?.toString() ?? json['staff']?.toString() ?? '';
    }

    // shiftId may be a populated object or a plain string
    String shiftId = '';
    DateTime scheduledStart = DateTime.now();
    DateTime scheduledEnd = DateTime.now();
    if (json['shiftId'] is Map) {
      final sh = json['shiftId'] as Map<String, dynamic>;
      shiftId = sh['_id'] ?? '';
      // Derive scheduled times from shift date + startTime/endTime
      if (sh['date'] != null && sh['startTime'] != null) {
        scheduledStart = _buildDateTime(sh['date'], sh['startTime']);
      }
      if (sh['date'] != null && sh['endTime'] != null) {
        scheduledEnd = _buildDateTime(sh['date'], sh['endTime']);
      }
    } else {
      shiftId = json['shiftId']?.toString() ?? json['shift']?.toString() ?? '';
      // Fallback: if scheduledStart/End are directly provided
      if (json['scheduledStart'] != null) {
        scheduledStart = DateTime.parse(json['scheduledStart']);
      }
      if (json['scheduledEnd'] != null) {
        scheduledEnd = DateTime.parse(json['scheduledEnd']);
      }
    }

    return AttendanceRecord(
      id: json['_id'] ?? json['id'] ?? '',
      staffId: staffId,
      staffName: staffName,
      shiftId: shiftId,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      clockInTime: json['clockInTime'] != null ? DateTime.parse(json['clockInTime']) : null,
      clockOutTime: json['clockOutTime'] != null ? DateTime.parse(json['clockOutTime']) : null,
      lateMinutes: json['lateMinutes'] ?? 0,
      extraHours: (json['extraHours'] ?? 0).toDouble(),
      status: _mapStatus(json['status']),
    );
  }

  /// Build a DateTime from a date string and a "HH:mm" time string.
  DateTime _buildDateTime(String dateStr, String timeStr) {
    final d = DateTime.parse(dateStr);
    final parts = timeStr.split(':');
    return DateTime(d.year, d.month, d.day,
        int.tryParse(parts[0]) ?? 0, int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
  }

  AttendanceStatus _mapStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'on-time': return AttendanceStatus.onTime;
      case 'late': return AttendanceStatus.late;
      case 'early-departure': return AttendanceStatus.earlyDeparture;
      case 'overtime': return AttendanceStatus.overtime;
      case 'absent': return AttendanceStatus.absent;
      default: return AttendanceStatus.onTime;
    }
  }
}
