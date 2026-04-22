// lib/screens/staff/staff_dashboard.dart
//
// Phase 3 update: Clock-in / Clock-out wired to real AttendanceService.
// Replaces the demo "Phase 3 coming soon" bottom sheet with navigation
// to ClockInScreen.  Everything else (tabs, Phase-2 My-Shifts, Leave,
// Profile) is preserved exactly as before.

import "dart:async";
import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:provider/provider.dart";

import "../../models/user_model.dart";
import "../../models/rota_model.dart";
import "../../models/attendance_model.dart";
import "../../core/constants.dart";
import "../../core/responsive.dart";
import "../../services/auth_service.dart";
import "../../services/rota_service.dart";
import "../../services/attendance_service.dart";
import "../../services/alert_service.dart";
import "../../services/qr_service.dart";
import "../../models/alert_model.dart";
import "../../widgets/shared_widgets.dart";
import "../../widgets/app_sidebar.dart";
import "../login_screen.dart";
import "shifts_page.dart";
import "clock_in_screen.dart";
import "leave_page.dart";
import "qr_scanner_screen.dart";

class StaffDashboard extends StatefulWidget {
  final UserModel user;
  const StaffDashboard({super.key, required this.user});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard>
{
  int _selectedIndex = 0;
  int _unreadAlertCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final alertService = Provider.of<AlertService>(context, listen: false);
      final count = await alertService.getMyUnreadCount();
      if (mounted) setState(() => _unreadAlertCount = count);
    } catch (_) {}
  }

  void _showNotifications() async {
    try {
      final alertService = Provider.of<AlertService>(context, listen: false);
      final alerts = await alertService.getMyAlerts();

      if (!mounted) return;

      // Mark all unread as read
      for (final alert in alerts.where((a) => !a.readByStaff)) {
        try {
          await alertService.markAlertReadByStaff(alert.id);
        } catch (_) {}
      }
      _loadUnreadCount();

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _NotificationsSheet(alerts: alerts),
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Failed to load notifications', isError: true);
      }
    }
  }

  Future<void> _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final ok = await showConfirmDialog(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
    );
    if (!mounted) return;
    if (ok) {
      await authService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  // ── Staff nav items for sidebar ──────────────────────────────────────────
  static const _navLabels = ['Home', 'My Shifts', 'Leave', 'Notifications', 'Profile'];
  static const _navIcons = [
    Icons.home_rounded,
    Icons.calendar_today_rounded,
    Icons.beach_access_rounded,
    Icons.notifications_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final showSidebar = Responsive.showSidebar(context);

    final pages = [
      _StaffHomePage(
        user: widget.user,
        onNavigate: (i) => setState(() => _selectedIndex = i),
      ),
      StaffShiftsPage(user: widget.user),
      StaffLeavePage(user: widget.user),
      _StaffNotificationsPage(
        user: widget.user,
        onRead: () => _loadUnreadCount(),
      ),
      _ProfileTab(user: widget.user),
    ];

    if (showSidebar) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            AppSidebar(
              selectedIndex: _selectedIndex,
              onItemTap: (i) => setState(() => _selectedIndex = i),
              userName: widget.user.name,
              userRole: 'Staff',
              items: List.generate(
                _navLabels.length,
                (i) => SidebarItem(
                  icon: _navIcons[i],
                  label: _navLabels[i],
                  index: i,
                ),
              ),
              onSignOut: _signOut,
              trailing: IconButton(
                onPressed: _showNotifications,
                tooltip: 'Notifications',
                icon: Badge(
                  isLabelVisible: _unreadAlertCount > 0,
                  label: Text(
                    _unreadAlertCount > 9 ? '9+' : _unreadAlertCount.toString(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.notifications_outlined,
                      size: 22, color: Colors.white70),
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: pages,
              ),
            ),
          ],
        ),
      );
    }

    // Mobile: AppBar + bottom nav
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2C59),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 24),
            const SizedBox(width: 8),
            const Text('Temple Clock',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w800,
                    fontSize: 17)),
          ],
        ),
        actions: [
          // Notification bell
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              onPressed: _showNotifications,
              icon: Badge(
                isLabelVisible: _unreadAlertCount > 0,
                label: Text(
                  _unreadAlertCount > 9 ? '9+' : _unreadAlertCount.toString(),
                  style: const TextStyle(fontSize: 10),
                ),
                child: const Icon(Icons.notifications_outlined, size: 22),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: _signOut,
              child: CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFF00BFA5).withValues(alpha: 0.2),
                child: Text(
                  widget.user.name.isNotEmpty
                      ? widget.user.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Color(0xFF00BFA5),
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0F2C59),
        unselectedItemColor: const Color(0xFF78909C),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 12,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today_rounded),
            label: 'My Shifts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.beach_access_outlined),
            activeIcon: Icon(Icons.beach_access_rounded),
            label: 'Leave',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _unreadAlertCount > 0,
              label: Text(
                _unreadAlertCount > 9 ? '9+' : _unreadAlertCount.toString(),
                style: const TextStyle(fontSize: 10),
              ),
              child: const Icon(Icons.notifications_outlined),
            ),
            activeIcon: const Icon(Icons.notifications_rounded),
            label: 'Alerts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ─── Home Tab ─────────────────────────────────────────────────────────────────

class _StaffHomePage extends StatefulWidget {
  final UserModel user;
  final ValueChanged<int>? onNavigate;
  const _StaffHomePage({required this.user, this.onNavigate});

  @override
  State<_StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends State<_StaffHomePage> {
  static const Color _navy = Color(0xFF1A2B4A);
  static const Color _teal = Color(0xFF00BFA5);

  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  RotaShift? _todayShift;
  List<AttendanceRecord> _attendanceRecords = [];

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadTodayShift();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTodayShift() async {
    try {
      final rotaService = Provider.of<RotaService>(context, listen: false);
      final shifts = await rotaService.getMyShifts();
      
      final today = DateTime.now();
      RotaShift? todayShift;
      
      try {
        todayShift = shifts.firstWhere(
          (s) =>
              s.startTime.year == today.year &&
              s.startTime.month == today.month &&
              s.startTime.day == today.day,
        );
      } catch (_) {
        todayShift = null;
      }

      if (mounted) {
        setState(() => _todayShift = todayShift);
        if (todayShift != null) {
          await _refreshAttendance();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading shifts: $e")),
        );
      }
    }
  }

  Future<void> _refreshAttendance() async {
    if (_todayShift == null) return;
    try {
      final attendanceService = Provider.of<AttendanceService>(context, listen: false);
      final records = await attendanceService.getMyAttendance();
      
       if (mounted) {
        setState(() {
          _attendanceRecords = records.where((r) => r.shiftId == _todayShift!.id).toList();
        });
      }
    } catch (_) {}
  }

  AttendanceRecord? _getRecordForVisit(String? clientId) {
    if (clientId == null) {
      // For standard shifts, we look for the record without a clientId
      try {
        return _attendanceRecords.firstWhere((r) => r.clientId == null || r.clientId!.isEmpty);
      } catch (_) {
        return null;
      }
    }
    try {
      return _attendanceRecords.firstWhere((r) => r.clientId == clientId);
    } catch (_) {
      return null;
    }
  }

  // ─── Navigate to clock screen ────────────────────────────────────────────────

  /// Opens the camera QR scanner screen (or manual-entry fallback).
  /// Verifies the token with the backend, then navigates to ClockInScreen.
  Future<void> _scanAndVerifyQR(bool isClockIn, {String? targetClientId, String? targetClientName}) async {
    if (!isClockIn && _todayShift == null) return;
    if (isClockIn && _todayShift == null) {
      showAppSnackBar(context, 'No shift scheduled today', isError: true);
      return;
    }

    // Open camera QR scanner
    final enteredToken = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(isClockIn: isClockIn),
      ),
    );

    if (enteredToken == null || enteredToken.isEmpty || !mounted) return;

    // Extract the token and clientId from the JSON payload if user scanned a QR image
    String resolvedToken = enteredToken;
    String? resolvedClientId;
    
    if (enteredToken.contains('token')) {
      try {
        final tokenMatch = RegExp(r'"token"\s*:\s*"([^"]+)"').firstMatch(enteredToken);
        if (tokenMatch != null) resolvedToken = tokenMatch.group(1)!;
        
        final clientMatch = RegExp(r'"clientId"\s*:\s*"([^"]+)"').firstMatch(enteredToken);
        if (clientMatch != null) resolvedClientId = clientMatch.group(1);
      } catch (_) {}
    }

    // Verify the token with the backend
    try {
      final qrService = Provider.of<QrService>(context, listen: false);
      await qrService.verifyQR(resolvedToken);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
      return;
    }

    // Token is valid — proceed to ClockInScreen
    if (!mounted) return;

    final result = await Navigator.of(context).push<AttendanceRecord>(
      MaterialPageRoute(
        builder: (_) => ClockInScreen(
          shift: _todayShift!,
          isClockIn: isClockIn,
          staffId: widget.user.id,
          staffName: widget.user.name,
          qrToken: resolvedToken,
          clientId: targetClientId ?? resolvedClientId,
          clientName: targetClientName,
        ),
      ),
    );

    if (result != null && mounted) {
      // Find and update or add the record in our local list
      setState(() {
        final idx = _attendanceRecords.indexWhere((r) => r.id == result.id);
        if (idx != -1) {
          _attendanceRecords[idx] = result;
        } else {
          _attendanceRecords.add(result);
        }
      });
      showAppSnackBar(
        context,
        isClockIn ? 'Clocked in successfully!' : 'Clocked out successfully!',
      );
    }
  }

  Future<void> _openClockScreen(bool isClockIn, {String? clientId, String? clientName}) async {
    // All clock-in / clock-out goes through QR verification
    await _scanAndVerifyQR(isClockIn, targetClientId: clientId, targetClientName: clientName);
  }

  @override
  Widget build(BuildContext context) {
    final tf = DateFormat("HH:mm:ss");
    final df = DateFormat("EEEE, d MMMM yyyy");
    final isWide = MediaQuery.of(context).size.width >= 800;

    if (isWide) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreeting(df),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _buildClockDisplay(tf),
                        const SizedBox(height: 16),
                        _buildClockCard(),
                        const SizedBox(height: 16),
                        _buildTodaySummary(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Right column
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _buildQuickActions(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      );
    }

    // Mobile layout
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreeting(df),
            const SizedBox(height: 16),
            _buildClockDisplay(tf),
            const SizedBox(height: 16),
            _buildClockCard(),
            const SizedBox(height: 16),
            _buildQuickActions(),
            const SizedBox(height: 16),
            _buildTodaySummary(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.flash_on_rounded, color: _teal, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                "Quick Actions",
                style: TextStyle(
                  fontFamily: "Outfit",
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              _quickActionTile(
                icon: Icons.login_rounded,
                label: "Clock In",
                color: _teal,
                onTap: () => _openClockScreen(true),
              ),
              _quickActionTile(
                icon: Icons.calendar_today_rounded,
                label: "My Shifts",
                color: const Color(0xFF1565C0),
                onTap: () => widget.onNavigate?.call(1),
              ),
              _quickActionTile(
                icon: Icons.beach_access_rounded,
                label: "Request Leave",
                color: const Color(0xFF7B1FA2),
                onTap: () => widget.onNavigate?.call(2),
              ),
              _quickActionTile(
                icon: Icons.person_rounded,
                label: "My Profile",
                color: const Color(0xFF00838F),
                onTap: () => widget.onNavigate?.call(3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: "Outfit",
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(DateFormat df) {
    final hour = _now.hour;
    final greeting = hour < 12
        ? "Good morning"
        : hour < 17
            ? "Good afternoon"
            : "Good evening";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          greeting + ", " + widget.user.name.split(" ").first + "!",
          style: const TextStyle(
            fontFamily: "Outfit",
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A2B4A),
          ),
        ),
        Text(
          df.format(_now),
          style: const TextStyle(
            fontFamily: "Outfit",
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildClockDisplay(DateFormat tf) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        tf.format(_now),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: "Outfit",
          fontSize: 44,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildClockCard() {
    if (_todayShift == null) {
      return _card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            const Text(
              "No shift scheduled today",
              style: TextStyle(
                fontFamily: "Outfit",
                fontSize: 15,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    final shift = _todayShift!;
    final sf = DateFormat("HH:mm");

    // Check if this is a domiciliary shift with visits
    final hasVisits = shift.visits != null && shift.visits!.isNotEmpty;

    if (hasVisits) {
      return _buildItineraryCard(shift, sf);
    }

    // Standard shift logic
    final record = _getRecordForVisit(null);
    final bool canClockIn = record == null;
    final bool canClockOut = record != null && record.isClockedIn;
    final bool alreadyOut = record != null && record.isClockedOut;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.work_outline, color: _teal, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Today's Shift",
                      style: TextStyle(
                        fontFamily: "Outfit",
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _navy,
                      ),
                    ),
                    Text(
                      "${shift.role}  •  ${sf.format(shift.startTime)} – ${sf.format(shift.endTime)}",
                      style: const TextStyle(
                        fontFamily: "Outfit",
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (record != null) _buildAttendanceSummary(record, sf),
          const SizedBox(height: 14),
          if (alreadyOut)
            _statusBanner("Shift complete — clocked out", _teal)
          else
            Row(
              children: [
                if (canClockIn)
                  Expanded(
                    child: _ClockButton(
                      label: "Clock In",
                      icon: Icons.login,
                      color: _teal,
                      onPressed: () => _openClockScreen(true),
                    ),
                  ),
                if (canClockOut) ...[
                  Expanded(
                    child: _ClockButton(
                      label: "Clock Out",
                      icon: Icons.logout,
                      color: Colors.redAccent,
                      onPressed: () => _openClockScreen(false),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildItineraryCard(RotaShift shift, DateFormat sf) {
    return Column(
      children: [
        _card(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.map_outlined, color: _navy.withValues(alpha: 0.7), size: 20),
              const SizedBox(width: 10),
              const Text(
                "Today's Itinerary (Domiciliary)",
                style: TextStyle(
                  fontFamily: "Outfit",
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...shift.visits!.map((visit) {
          final record = _getRecordForVisit(visit.clientId);
          final bool canClockIn = record == null;
          final bool canClockOut = record != null && record.isClockedIn;
          final bool isCompleted = record != null && record.isClockedOut;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isCompleted ? Colors.green : _teal).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCompleted ? Icons.check_circle_outline : Icons.house_outlined,
                          color: isCompleted ? Colors.green : _teal,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              visit.clientName,
                              style: const TextStyle(
                                fontFamily: "Outfit",
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _navy,
                              ),
                            ),
                            Text(
                              "${sf.format(visit.expectedStartTime)} – ${sf.format(visit.expectedEndTime)}",
                              style: TextStyle(
                                fontFamily: "Outfit",
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 42),
                    child: Text(
                      visit.clientAddress,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (record != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildAttendanceSummary(record, sf),
                    ),
                  if (isCompleted)
                    _statusBanner("Visit Completed", Colors.green)
                  else
                    Row(
                      children: [
                        if (canClockIn) ...[
                          Expanded(
                            child: _ClockButton(
                              label: "Clock In",
                              icon: Icons.login,
                              color: _teal,
                              onPressed: () => _openClockScreen(true, clientId: visit.clientId, clientName: visit.clientName),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // "Report Delay" Button
                          _miniActionButton(
                            icon: Icons.notification_important_outlined,
                            color: Colors.orange.shade700,
                            onPressed: () => _showReportDelayDialog(visit),
                            tooltip: "Report Delay to Office",
                          ),
                        ],
                        if (canClockOut)
                          Expanded(
                            child: _ClockButton(
                              label: "Clock Out",
                              icon: Icons.logout,
                              color: Colors.redAccent,
                              onPressed: () => _openClockScreen(false, clientId: visit.clientId, clientName: visit.clientName),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

        ],
      ),
    );
  }

  Widget _miniActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Future<void> _showReportDelayDialog(ShiftVisit visit) async {
    int delayMinutes = 15;
    final reasonController = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            "Report Delay: ${visit.clientName}",
            style: const TextStyle(fontFamily: "Outfit", fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("How long will you be delayed?", style: TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: delayMinutes,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                items: [15, 30, 45, 60]
                    .map((m) => DropdownMenuItem(value: m, child: Text("$m Minutes")))
                    .toList(),
                onChanged: (val) => setState(() => delayMinutes = val!),
              ),
              const SizedBox(height: 16),
              const Text("Reason (optional):", style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Traffic, previous visit ran over..."),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      setState(() => submitting = true);
                      try {
                        final alertService = Provider.of<AlertService>(context, listen: false);
                        await alertService.reportDelay(
                          shiftId: _todayShift!.id,
                          clientId: visit.clientId,
                          estimatedDelayMinutes: delayMinutes,
                          message: reasonController.text.trim().isEmpty ? "Staff running late" : reasonController.text.trim(),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Delay reported to Head Office")),
                          );
                        }
                      } catch (e) {
                         if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                          );
                         }
                      } finally {
                        if (context.mounted) setState(() => submitting = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
              child: Text(submitting ? "Reporting..." : "Report Delay"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSummary(AttendanceRecord record, DateFormat sf) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _summaryRow(
            Icons.login,
            "Clocked in",
            sf.format(record.clockInTime!),
            record.lateMinutes > 0 ? Colors.orange : _teal,
          ),
          if (record.lateMinutes > 0)
            _summaryRow(
              Icons.warning_amber_outlined,
              "Late by",
              AttendanceService.formatLateMinutes(record.lateMinutes)
                  .replaceAll(" late", ""),
              Colors.orange,
            ),
          if (record.clockOutTime != null)
            _summaryRow(
              Icons.logout,
              "Clocked out",
              sf.format(record.clockOutTime!),
              Colors.grey,
            ),
          if (record.extraHours > 0)
            _summaryRow(
              Icons.more_time,
              "Overtime",
              AttendanceService.formatExtraHours(record.extraHours),
              Colors.blue,
            ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label + ": ",
            style: const TextStyle(
              fontFamily: "Outfit",
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: "Outfit",
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySummary() {
    final records = AttendanceService.getRecordsForStaff(widget.user.id);
    final weekStart = _now.subtract(Duration(days: _now.weekday - 1));
    final weekRecords = records.where((r) {
      return r.clockInTime != null &&
          r.clockInTime!.isAfter(weekStart.subtract(const Duration(seconds: 1)));
    }).toList();

    final double weekHours = weekRecords.fold(
      0.0,
      (sum, r) => sum + r.totalHoursWorked,
    );

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "This Week",
            style: TextStyle(
              fontFamily: "Outfit",
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _navy,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _weekStat(
                  "Shifts",
                  weekRecords.length.toString(),
                  Icons.work_outline,
                  _navy,
                ),
              ),
              Expanded(
                child: _weekStat(
                  "Hours",
                  weekHours.toStringAsFixed(1) + "h",
                  Icons.schedule,
                  _teal,
                ),
              ),
              Expanded(
                child: _weekStat(
                  "On Time",
                  weekRecords
                      .where((r) => r.status == AttendanceStatus.onTime)
                      .length
                      .toString(),
                  Icons.check_circle_outline,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weekStat(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: "Outfit",
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: "Outfit",
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _statusBanner(String msg, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: "Outfit",
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
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
      child: child,
    );
  }
}

// ─── Clock Button ─────────────────────────────────────────────────────────────

class _ClockButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ClockButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 18),
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: "Outfit",
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontSize: 14,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
      ),
    );
  }
}

// ─── Profile Tab ──────────────────────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  final UserModel user;
  const _ProfileTab({required this.user});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  static const Color _navy = Color(0xFF1A2B4A);
  static const Color _teal = Color(0xFF00BFA5);

  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _passwordLoading = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass.isEmpty || confirmPass.isEmpty) {
      showAppSnackBar(context, 'Please fill in all fields', isError: true);
      return;
    }
    if (newPass.length < 6) {
      showAppSnackBar(context, 'Password must be at least 6 characters', isError: true);
      return;
    }
    if (newPass != confirmPass) {
      showAppSnackBar(context, 'Passwords do not match', isError: true);
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Reset Password',
      message: 'Are you sure you want to change your password?',
      confirmLabel: 'Reset',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _passwordLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final result = await authService.resetPassword(widget.user.email, newPass);

      if (!mounted) return;
      if (result['success'] == true) {
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        showAppSnackBar(context, result['message'] ?? 'Password reset successfully');
      } else {
        showAppSnackBar(context, result['message'] ?? 'Password reset failed', isError: true);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Error: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _passwordLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // ── Profile header card ─────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F2C59), Color(0xFF1A3B6E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F2C59).withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: _teal,
                    child: Text(
                      widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : "?",
                      style: const TextStyle(
                        fontFamily: "Outfit",
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.user.name,
                    style: const TextStyle(
                      fontFamily: "Outfit",
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _teal.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.user.role.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: "Outfit",
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00BFA5),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.user.email,
                    style: TextStyle(
                      fontFamily: "Outfit",
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Quick stats row ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatMini(
                    label: 'Hourly Rate',
                    value: widget.user.hourlyRate != null
                        ? '\u00A3${widget.user.hourlyRate!.toStringAsFixed(2)}'
                        : 'N/A',
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF7B1FA2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatMini(
                    label: 'Weekly Hours',
                    value: widget.user.weeklyHours != null
                        ? '${widget.user.weeklyHours!.toStringAsFixed(0)}h'
                        : 'N/A',
                    icon: Icons.schedule_outlined,
                    color: const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatMini(
                    label: 'Leave Balance',
                    value: widget.user.annualLeaveBalance != null
                        ? '${widget.user.annualLeaveBalance!.toStringAsFixed(0)} days'
                        : 'N/A',
                    icon: Icons.beach_access_outlined,
                    color: const Color(0xFF00838F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Personal Information ────────────────────────────────────
            _sectionCard(
              title: 'Personal Information',
              icon: Icons.person_outline,
              children: [
                _detailRow(Icons.badge_outlined, 'Employee ID', widget.user.id.substring(widget.user.id.length > 8 ? widget.user.id.length - 8 : 0)),
                _detailRow(Icons.email_outlined, 'Email', widget.user.email),
                _detailRow(Icons.phone_outlined, 'Phone', widget.user.phone ?? 'Not set'),
                _detailRow(Icons.business_outlined, 'Department', widget.user.department ?? 'Not assigned'),
              ],
            ),
            const SizedBox(height: 14),

            // ── Employment Details ──────────────────────────────────────
            _sectionCard(
              title: 'Employment Details',
              icon: Icons.work_outline,
              children: [
                _detailRow(Icons.payments_outlined, 'Hourly Rate',
                    widget.user.hourlyRate != null ? '\u00A3${widget.user.hourlyRate!.toStringAsFixed(2)}/hr' : 'N/A'),
                _detailRow(Icons.schedule_outlined, 'Weekly Hours',
                    widget.user.weeklyHours != null ? '${widget.user.weeklyHours!.toStringAsFixed(0)} hours' : 'N/A'),
                _detailRow(Icons.beach_access_outlined, 'Annual Leave',
                    widget.user.annualLeaveBalance != null ? '${widget.user.annualLeaveBalance!.toStringAsFixed(1)} days remaining' : 'N/A'),
                _detailRow(Icons.check_circle_outline, 'Status',
                    widget.user.isActive ? 'Active' : 'Inactive'),
              ],
            ),
            const SizedBox(height: 14),

            // ── Reset Password ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD32F2F).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.lock_outline, size: 18, color: Color(0xFFD32F2F)),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Reset Password',
                        style: TextStyle(
                          fontFamily: "Outfit",
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter a new password below to change your login credentials.',
                    style: TextStyle(
                      fontFamily: "Outfit",
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // New password field
                  TextField(
                    controller: _newPasswordController,
                    obscureText: !_showNewPassword,
                    style: const TextStyle(fontFamily: "Outfit", fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: TextStyle(fontFamily: "Outfit", fontSize: 13, color: Colors.grey.shade600),
                      prefixIcon: Icon(Icons.lock_outline, size: 18, color: Colors.grey.shade500),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18,
                          color: Colors.grey.shade500,
                        ),
                        onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _teal, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Confirm password field
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: !_showConfirmPassword,
                    style: const TextStyle(fontFamily: "Outfit", fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      labelStyle: TextStyle(fontFamily: "Outfit", fontSize: 13, color: Colors.grey.shade600),
                      prefixIcon: Icon(Icons.lock_outline, size: 18, color: Colors.grey.shade500),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18,
                          color: Colors.grey.shade500,
                        ),
                        onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _teal, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Reset button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _passwordLoading ? null : _handleResetPassword,
                      icon: _passwordLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.lock_reset_rounded, size: 18),
                      label: Text(
                        _passwordLoading ? 'Resetting...' : 'Reset Password',
                        style: const TextStyle(
                          fontFamily: "Outfit",
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _navy),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: "Outfit",
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: "Outfit",
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: "Outfit",
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _navy,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatMini({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: "Outfit",
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: "Outfit",
              fontSize: 10,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Staff Notifications Page (full tab) ────────────────────────────────────

class _StaffNotificationsPage extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onRead;
  const _StaffNotificationsPage({required this.user, this.onRead});

  @override
  State<_StaffNotificationsPage> createState() =>
      _StaffNotificationsPageState();
}

class _StaffNotificationsPageState extends State<_StaffNotificationsPage> {
  List<AlertModel>? _alerts;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final svc = Provider.of<AlertService>(context, listen: false);
      final alerts = await svc.getMyAlerts();
      if (!mounted) return;

      // Auto-mark unread as read
      for (final a in alerts.where((a) => !a.readByStaff)) {
        try {
          await svc.markAlertReadByStaff(a.id);
        } catch (_) {}
      }
      widget.onRead?.call();

      if (mounted) setState(() { _alerts = alerts; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showAppSnackBar(context, 'Failed to load notifications', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_alerts == null || _alerts!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            const Text('No notifications yet',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _alerts!.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => _NotificationTile(alert: _alerts![i]),
      ),
    );
  }
}

// ─── Notifications Sheet ────────────────────────────────────────────────────

class _NotificationsSheet extends StatelessWidget {
  final List<AlertModel> alerts;
  const _NotificationsSheet({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, controller) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.notifications_rounded,
                      size: 20, color: Color(0xFF0F2C59)),
                  const SizedBox(width: 8),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2B4A),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${alerts.length} total',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            Expanded(
              child: alerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          const Text('No notifications yet',
                              style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: alerts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final alert = alerts[i];
                        return _NotificationTile(alert: alert);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AlertModel alert;
  const _NotificationTile({required this.alert});

  IconData get _icon {
    switch (alert.alertType) {
      case 'admin_notice':
        return Icons.campaign_outlined;
      case 'emergency':
        return Icons.warning_amber_rounded;
      case 'running_late':
        return Icons.schedule;
      default:
        return Icons.info_outline;
    }
  }

  Color get _color {
    switch (alert.alertType) {
      case 'admin_notice':
        return const Color(0xFF1565C0);
      case 'emergency':
        return Colors.red;
      case 'running_late':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTimeAgo(alert.createdAt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon, size: 18, color: _color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.message.isNotEmpty ? alert.message : alert.alertType.replaceAll('_', ' '),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight: alert.readByStaff ? FontWeight.w400 : FontWeight.w600,
                    color: const Color(0xFF1A2B4A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeAgo,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (!alert.readByStaff)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF00BFA5),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

