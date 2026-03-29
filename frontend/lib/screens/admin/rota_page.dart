import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/responsive.dart';
import '../../models/rota_model.dart';
import '../../models/user_model.dart';
import '../../services/rota_service.dart';
import '../../services/user_service.dart';
import '../../widgets/shared_widgets.dart';

class AdminRotaPage extends StatefulWidget {
  const AdminRotaPage({super.key});

  @override
  State<AdminRotaPage> createState() => _AdminRotaPageState();
}

class _AdminRotaPageState extends State<AdminRotaPage> {
  bool _loading = true;
  List<RotaShift> _shifts = [];
  List<UserModel> _staffList = [];
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rotaSvc = Provider.of<RotaService>(context, listen: false);
      final userSvc = Provider.of<UserService>(context, listen: false);
      final weekStr = DateFormat('yyyy-MM-dd').format(_weekStart);
      final results = await Future.wait([
        rotaSvc.getAllShifts(week: weekStr),
        userSvc.getUsers(),
      ]);
      if (mounted) {
        setState(() {
          _shifts = results[0] as List<RotaShift>;
          _staffList = (results[1] as List<UserModel>)
              .where((u) => u.role == 'staff' && u.isActive)
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showAppSnackBar(context, 'Failed to load shifts: $e', isError: true);
      }
    }
  }

  void _prevWeek() {
    _weekStart = _weekStart.subtract(const Duration(days: 7));
    _load();
  }

  void _nextWeek() {
    _weekStart = _weekStart.add(const Duration(days: 7));
    _load();
  }

  void _goToday() {
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _load();
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  List<RotaShift> _shiftsForDay(DateTime day) {
    return _shifts.where((s) {
      return s.startTime.year == day.year &&
          s.startTime.month == day.month &&
          s.startTime.day == day.day;
    }).toList();
  }

  Future<void> _showAddShiftDialog({DateTime? presetDate}) async {
    if (_staffList.isEmpty) {
      showAppSnackBar(context, 'No staff available', isError: true);
      return;
    }
    String? selectedStaffId = _staffList.first.id;
    final today = DateTime.now();
    DateTime selectedDate = presetDate != null && presetDate.isAfter(today.subtract(const Duration(days: 1)))
        ? presetDate
        : today;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);
    final locationCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              FaIcon(FontAwesomeIcons.calendarPlus,
                  size: 18, color: AppColors.teal),
              const SizedBox(width: 10),
              const Text('Add Shift',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedStaffId,
                    decoration: InputDecoration(
                      labelText: 'Staff Member',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    items: _staffList
                        .map((u) => DropdownMenuItem(
                            value: u.id, child: Text(u.name)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedStaffId = v),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setDialogState(() => selectedDate = d);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        suffixIcon: const Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(DateFormat('EEE, d MMM yyyy')
                          .format(selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final t = await showTimePicker(
                              context: ctx,
                              initialTime: startTime,
                            );
                            if (t != null) {
                              setDialogState(() => startTime = t);
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Start',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                            ),
                            child: Text(startTime.format(ctx)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final t = await showTimePicker(
                              context: ctx,
                              initialTime: endTime,
                            );
                            if (t != null) {
                              setDialogState(() => endTime = t);
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'End',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                            ),
                            child: Text(endTime.format(ctx)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: locationCtrl,
                    decoration: InputDecoration(
                      labelText: 'Location (optional)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              child: const Text('Add Shift'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedStaffId != null) {
      try {
        final rotaSvc = Provider.of<RotaService>(context, listen: false);
        final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
        final startStr =
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
        final endStr =
            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
        await rotaSvc.createShift(
          staffId: selectedStaffId!,
          date: dateStr,
          startTime: startStr,
          endTime: endStr,
          location:
              locationCtrl.text.isNotEmpty ? locationCtrl.text : null,
          notes: notesCtrl.text.isNotEmpty ? notesCtrl.text : null,
        );
        if (mounted) {
          showAppSnackBar(context, 'Shift created');
          _load();
        }
      } catch (e) {
        if (mounted) {
          showAppSnackBar(context, 'Error: $e', isError: true);
        }
      }
    }
  }

  Future<void> _deleteShift(RotaShift shift) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Shift',
      message:
          'Delete ${shift.staffName}\'s shift on ${DateFormat('d MMM').format(shift.startTime)}?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (ok && mounted) {
      try {
        final rotaSvc = Provider.of<RotaService>(context, listen: false);
        await rotaSvc.deleteShift(shift.id);
        showAppSnackBar(context, 'Shift deleted');
        _load();
      } catch (e) {
        if (mounted) {
          showAppSnackBar(context, 'Error: $e', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = Responsive.contentPadding(context);
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddShiftDialog(),
        backgroundColor: AppColors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.teal,
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.all(pad),
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rota Management',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          '${DateFormat('d MMM').format(_weekStart)} – ${DateFormat('d MMM yyyy').format(weekEnd)}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  _WeekNav(
                    onPrev: _prevWeek,
                    onNext: _nextWeek,
                    onToday: _goToday,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_loading)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: CircularProgressIndicator(
                      color: AppColors.teal, strokeWidth: 2),
                ))
              else if (isDesktop)
                _buildWeekGrid()
              else
                _buildDayList(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Desktop: week grid ───────────────────────────────────────────────────
  Widget _buildWeekGrid() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Day headers
          Container(
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg)),
            ),
            child: Row(
              children: _weekDays.map((day) {
                final isToday = _isToday(day);
                return Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        right: day.weekday < 7
                            ? BorderSide(
                                color: AppColors.border.withValues(alpha: 0.5))
                            : BorderSide.none,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(DateFormat('EEE').format(day),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isToday
                                    ? AppColors.teal
                                    : AppColors.textMuted)),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: isToday
                              ? BoxDecoration(
                                  color: AppColors.teal,
                                  borderRadius: BorderRadius.circular(12))
                              : null,
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isToday
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Shift cells
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _weekDays.map((day) {
                final dayShifts = _shiftsForDay(day);
                return Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 200),
                    decoration: BoxDecoration(
                      border: Border(
                        right: day.weekday < 7
                            ? BorderSide(
                                color: AppColors.border.withValues(alpha: 0.5))
                            : BorderSide.none,
                      ),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      children: [
                        ...dayShifts.map((s) => _ShiftChip(
                              shift: s,
                              onDelete: () => _deleteShift(s),
                            )),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _showAddShiftDialog(presetDate: day),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppColors.teal.withValues(alpha: 0.3),
                                  style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.add,
                                size: 14, color: AppColors.teal),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile: day-by-day list ──────────────────────────────────────────────
  Widget _buildDayList() {
    return Column(
      children: _weekDays.map((day) {
        final dayShifts = _shiftsForDay(day);
        final isToday = _isToday(day);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
                color: isToday
                    ? AppColors.teal.withValues(alpha: 0.4)
                    : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isToday
                      ? AppColors.tealLight
                      : AppColors.navy.withValues(alpha: 0.03),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg)),
                ),
                child: Row(
                  children: [
                    Text(
                      DateFormat('EEEE, d MMM').format(day),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color:
                            isToday ? AppColors.tealDark : AppColors.textPrimary,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Today',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                    const Spacer(),
                    Text('${dayShifts.length} shifts',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              if (dayShifts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No shifts scheduled',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textMuted)),
                )
              else
                ...dayShifts.map((s) => _ShiftTile(
                      shift: s,
                      onDelete: () => _deleteShift(s),
                    )),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: InkWell(
                  onTap: () => _showAddShiftDialog(presetDate: day),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: AppColors.teal),
                      const SizedBox(width: 4),
                      Text('Add Shift',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.teal)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

// ── Week nav arrows ─────────────────────────────────────────────────────────
class _WeekNav extends StatelessWidget {
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _WeekNav({
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _navBtn(Icons.chevron_left, onPrev),
        const SizedBox(width: 4),
        InkWell(
          onTap: onToday,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Today',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
        ),
        const SizedBox(width: 4),
        _navBtn(Icons.chevron_right, onNext),
      ],
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}

// ── Desktop shift chip (inside weekly grid cell) ────────────────────────────
class _ShiftChip extends StatelessWidget {
  final RotaShift shift;
  final VoidCallback onDelete;

  const _ShiftChip({required this.shift, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${DateFormat.Hm().format(shift.startTime)} – ${DateFormat.Hm().format(shift.endTime)}';
    final statusColor = shift.status == 'completed'
        ? AppColors.success
        : shift.status == 'cancelled'
            ? AppColors.error
            : AppColors.teal;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(shift.staffName,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor),
                    overflow: TextOverflow.ellipsis),
              ),
              InkWell(
                onTap: onDelete,
                child:
                    Icon(Icons.close, size: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(timeStr,
              style:
                  const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          if (shift.departmentName != null && shift.departmentName!.isNotEmpty)
            Text(shift.departmentName!,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted),
                overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Mobile shift tile ───────────────────────────────────────────────────────
class _ShiftTile extends StatelessWidget {
  final RotaShift shift;
  final VoidCallback onDelete;

  const _ShiftTile({required this.shift, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${DateFormat.Hm().format(shift.startTime)} – ${DateFormat.Hm().format(shift.endTime)}';
    final statusColor = shift.status == 'completed'
        ? AppColors.success
        : shift.status == 'cancelled'
            ? AppColors.error
            : AppColors.teal;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shift.staffName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(timeStr,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (shift.departmentName != null &&
              shift.departmentName!.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(shift.departmentName!,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              shift.status[0].toUpperCase() + shift.status.substring(1),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            iconSize: 18,
            onSelected: (v) {
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete',
                      style: TextStyle(fontSize: 13, color: AppColors.error))),
            ],
          ),
        ],
      ),
    );
  }
}
