// lib/screens/admin/timesheet_page.dart
//
// Phase 3: Admin view of all attendance records.
// Filterable by date and staff member.

import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../models/attendance_model.dart";
import "../../services/attendance_service.dart";

class AdminTimesheetPage extends StatefulWidget {
  const AdminTimesheetPage({super.key});

  @override
  State<AdminTimesheetPage> createState() => _AdminTimesheetPageState();
}

class _AdminTimesheetPageState extends State<AdminTimesheetPage> {
  static const Color _navy = Color(0xFF1A2B4A);
  static const Color _teal = Color(0xFF00BFA5);

  DateTime _date = DateTime.now();
  String? _staffFilter;

  List<AttendanceRecord> get _filtered {
    var list = AttendanceService.getRecordsForDate(_date);
    if (_staffFilter != null) {
      list = list.where((r) => r.staffName == _staffFilter).toList();
    }
    return list;
  }

  List<String> get _staffNames {
    return AttendanceService.allRecords
        .map((r) => r.staffName)
        .toSet()
        .toList()
      ..sort();
  }

  int get _totalCount => _filtered.length;
  int get _onTimeCount =>
      _filtered.where((r) => r.status == AttendanceStatus.onTime).length;
  int get _lateCount =>
      _filtered.where((r) => r.status == AttendanceStatus.late).length;
  int get _workingCount => _filtered.where((r) => r.isClockedIn).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildKpis(),
            _buildFilters(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final df = DateFormat("EEE, d MMM yyyy");
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Timesheets",
                  style: TextStyle(
                    fontFamily: "Outfit",
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                Text(
                  df.format(_date),
                  style: const TextStyle(
                    fontFamily: "Outfit",
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 15),
            label: const Text(
              "Date",
              style: TextStyle(fontFamily: "Outfit", fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _navy,
              side: const BorderSide(color: _navy),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  // ─── KPIs ─────────────────────────────────────────────────────────────────────

  Widget _buildKpis() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _kpi("Total", _totalCount, Icons.people_outline, _navy),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _kpi("On Time", _onTimeCount, Icons.check_circle_outline, _teal),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _kpi("Late", _lateCount, Icons.warning_amber_outlined, Colors.orange),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _kpi("Working", _workingCount, Icons.work_outline, Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 3),
          Text(
            value.toString(),
            style: TextStyle(
              fontFamily: "Outfit",
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: "Outfit",
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Filters ─────────────────────────────────────────────────────────────────

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          const Text(
            "Staff: ",
            style: TextStyle(
              fontFamily: "Outfit",
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip("All", null),
                  ..._staffNames.map((n) => _chip(n, n)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String? value) {
    final sel = _staffFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontFamily: "Outfit",
            fontSize: 12,
            color: sel ? Colors.white : _navy,
          ),
        ),
        selected: sel,
        onSelected: (_) => setState(() => _staffFilter = value),
        backgroundColor: Colors.white,
        selectedColor: _navy,
        checkmarkColor: Colors.white,
        side: BorderSide(color: sel ? _navy : Colors.grey.shade300),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  // ─── List ─────────────────────────────────────────────────────────────────────

  Widget _buildList() {
    final records = _filtered;
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              "No records for this date",
              style: TextStyle(
                fontFamily: "Outfit",
                fontSize: 15,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Records appear when staff clock in",
              style: TextStyle(
                fontFamily: "Outfit",
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: records.length,
      itemBuilder: (_, i) => _AttendanceCard(record: records[i]),
    );
  }

  // ─── Date picker ─────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _navy,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }
}

// ─── Attendance Record Card ───────────────────────────────────────────────────

class _AttendanceCard extends StatelessWidget {
  final AttendanceRecord record;
  const _AttendanceCard({required this.record});

  static const Color _navy = Color(0xFF1A2B4A);
  static const Color _teal = Color(0xFF00BFA5);

  Color get _statusColor {
    switch (record.status) {
      case AttendanceStatus.onTime:
        return _teal;
      case AttendanceStatus.late:
        return Colors.orange;
      case AttendanceStatus.overtime:
        return Colors.blue;
      case AttendanceStatus.earlyDeparture:
        return Colors.red.shade300;
      case AttendanceStatus.absent:
        return Colors.red;
    }
  }

  String get _statusLabel {
    switch (record.status) {
      case AttendanceStatus.onTime:
        return "On Time";
      case AttendanceStatus.late:
        return "Late";
      case AttendanceStatus.overtime:
        return "Overtime";
      case AttendanceStatus.earlyDeparture:
        return "Early Departure";
      case AttendanceStatus.absent:
        return "Absent";
    }
  }

  @override
  Widget build(BuildContext context) {
    final tf = DateFormat("HH:mm");
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _photo(),
            const SizedBox(width: 12),
            Expanded(child: _info(tf)),
            _badge(),
          ],
        ),
      ),
    );
  }

  Widget _photo() {
    if (record.photoInPath != null && record.photoInPath!.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Image.network(
            record.photoInPath!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _photoPlaceholder(),
          ),
        ),
      );
    }
    return _photoPlaceholder();
  }

  Widget _photoPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.person_outline, color: Colors.grey, size: 22),
    );
  }

  Widget _info(DateFormat tf) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          record.staffName,
          style: const TextStyle(
            fontFamily: "Outfit",
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
        const SizedBox(height: 2),
        _row(Icons.schedule, "Scheduled",
            tf.format(record.scheduledStart) + " – " + tf.format(record.scheduledEnd),
            Colors.grey),
        if (record.clockInTime != null)
          _row(Icons.login, "In", tf.format(record.clockInTime!),
              record.lateMinutes > 0 ? Colors.orange : _teal),
        if (record.clockOutTime != null)
          _row(Icons.logout, "Out", tf.format(record.clockOutTime!), Colors.grey),
        if (record.isClockedIn)
          _row(Icons.work_outline, "Status", "Currently working", Colors.blue),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (record.lateMinutes > 0)
              _badge2(
                AttendanceService.formatLateMinutes(record.lateMinutes),
                Colors.orange,
              ),
            if (record.extraHours > 0)
              _badge2(
                AttendanceService.formatExtraHours(record.extraHours),
                Colors.blue,
              ),
            if (record.isClockedIn)
              _badge2(
                record.totalHoursWorked.toStringAsFixed(1) + "h so far",
                Colors.grey,
              ),
          ],
        ),
      ],
    );
  }

  Widget _row(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label + ": ",
            style: const TextStyle(
              fontFamily: "Outfit",
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: "Outfit",
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge2(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: "Outfit",
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _badge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel,
        style: TextStyle(
          fontFamily: "Outfit",
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _statusColor,
        ),
      ),
    );
  }
}
