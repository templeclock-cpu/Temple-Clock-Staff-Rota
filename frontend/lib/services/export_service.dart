import 'dart:convert';
import 'dart:html' as html; // For web download
import 'package:intl/intl.dart';
import '../models/rota_model.dart';
import '../models/attendance_model.dart';
import '../models/payroll_model.dart';

class ExportService {
  /// Export Rota to CSV
  static void exportRotaCsv(List<RotaShift> shifts, String filename) {
    final List<List<String>> rows = [
      ['Staff Name', 'Date', 'Start Time', 'End Time', 'Department', 'Status', 'Role'],
    ];

    final df = DateFormat('yyyy-MM-dd');
    final tf = DateFormat('HH:mm');

    for (var s in shifts) {
      rows.add([
        s.staffName,
        df.format(s.startTime),
        tf.format(s.startTime),
        tf.format(s.endTime),
        s.departmentName ?? '',
        s.status,
        s.role,
      ]);
    }

    _downloadCsv(rows, filename);
  }

  /// Export Timesheets (Attendance) to CSV
  static void exportAttendanceCsv(List<AttendanceRecord> records, String filename) {
    final List<List<String>> rows = [
      ['Staff Name', 'Shift Date', 'Clock In', 'Clock Out', 'Status', 'Late (min)', 'Overtime (hr)', 'Notes'],
    ];

    final df = DateFormat('yyyy-MM-dd');
    final tf = DateFormat('HH:mm');

    for (var r in records) {
      rows.add([
        r.staffName,
        r.clockInTime != null ? df.format(r.clockInTime!) : 'N/A',
        r.clockInTime != null ? tf.format(r.clockInTime!) : 'N/A',
        r.clockOutTime != null ? tf.format(r.clockOutTime!) : 'N/A',
        r.status.toString().split('.').last,
        r.lateMinutes.toString(),
        r.extraHours.toString(),
        r.notes ?? '',
      ]);
    }

    _downloadCsv(rows, filename);
  }

  /// Export Payroll to CSV
  static void exportPayrollCsv(List<PayrollRecord> records, String filename) {
    final List<List<String>> rows = [
      ['Staff Name', 'Month', 'Hours Worked', 'Overtime', 'Rate', 'Gross Pay', 'Final Pay', 'Status'],
    ];

    for (var p in records) {
      rows.add([
        p.staffName ?? 'Unknown',
        p.month,
        p.totalHoursWorked.toStringAsFixed(2),
        p.overtimeHours.toStringAsFixed(2),
        p.hourlyRate.toStringAsFixed(2),
        p.grossPay.toStringAsFixed(2),
        p.finalPay.toStringAsFixed(2),
        p.status,
      ]);
    }

    _downloadCsv(rows, filename);
  }

  /// Helper to generate and download CSV file in browser
  static void _downloadCsv(List<List<String>> rows, String filename) {
    String csv = const ListToCsvConverter().convert(rows);
    
    // Create a blob and anchor element for download
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    // ignore: unused_local_variable
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '$filename.csv')
      ..click();
    
    html.Url.revokeObjectUrl(url);
  }
}


/// Simple CSV converter (since I don't want to add a package just for this if not needed, 
/// but usually 'csv' package is preferred. I'll check pubspec.yaml later)
class ListToCsvConverter {
  const ListToCsvConverter();

  String convert(List<List<String>> rows) {
    return rows.map((row) {
      return row.map((field) {
        // Escape quotes and wrap in quotes if contains comma
        String f = field.toString().replaceAll('"', '""');
        if (f.contains(',') || f.contains('\n') || f.contains('"')) {
          return '"$f"';
        }
        return f;
      }).join(',');
    }).join('\n');
  }
}
