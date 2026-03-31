// lib/models/rota_model.dart

class RotaShift {
  final String id;
  final String staffId;
  final String staffName;
  final String role;
  final String? departmentName;
  final double scheduledHours;
  final DateTime startTime;
  final DateTime endTime;
  final String status;

  const RotaShift({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.role,
    this.departmentName,
    required this.scheduledHours,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  double get durationHours => endTime.difference(startTime).inMinutes / 60.0;
}
