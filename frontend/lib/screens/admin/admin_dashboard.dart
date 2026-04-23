// lib/screens/admin/admin_dashboard.dart
//
// Phase 3 update — replaces Timesheet stub (index 2) with AdminTimesheetPage.
// All other pages unchanged from Phase 2.
//
// Nav index map:
//   0 = Dashboard (overview KPIs)
//   1 = Rota Management (Phase 2)
//   2 = Timesheets ← Phase 3: NOW REAL
//   3 = Staff
//   4 = Leave
//   5 = Payroll
//   6 = Reports
//   7 = Alerts
//   8 = QR Management
//   9 = Settings
//   10 = Sign Out

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/responsive.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/rota_service.dart';
import '../../services/attendance_service.dart';
import '../../services/alert_service.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/app_sidebar.dart';
import '../login_screen.dart';
import 'rota_page.dart';
import 'timesheet_page.dart';
import 'leave_management_page.dart';
import 'staff_management_page.dart';
import 'payroll_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';
import 'alerts_page.dart';
import 'qr_management_page.dart';
import 'client_management_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboard extends StatefulWidget {
  final UserModel user;
  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  Timer? _alertTimer;
  final Set<String> _notifiedAlertIds = {};

  int _unreadAlertCount = 0;

  @override
  void initState() {
    super.initState();
    _startAlertPolling();
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    super.dispose();
  }

  void _startAlertPolling() {
    // Initial check
    _checkAlerts();
    // Poll every 15 seconds
    _alertTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkAlerts());
  }

  Future<void> _checkAlerts() async {
    try {
      final alertSvc = Provider.of<AlertService>(context, listen: false);
      final alerts = await alertSvc.getMyAlerts(unreadOnly: true);
      
      if (mounted) {
        setState(() => _unreadAlertCount = alerts.length);
      }

      for (var alert in alerts) {
        if (!_notifiedAlertIds.contains(alert.id)) {
          _notifiedAlertIds.add(alert.id);
          
          if (mounted && alert.alertType == 'running_late') {
            _showTopNotification(
              "Staff Running Late",
              alert.message.isNotEmpty ? alert.message : "A staff member reported a delay.",
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Alert polling error: $e");
    }
  }

  void _showTopNotification(String title, String body) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(body, style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: "View",
          textColor: Colors.white,
          onPressed: () => setState(() => _selectedIndex = 7), // Navigate to Alerts
        ),
      ),
    );
  }

  // ── Nav items ──────────────────────────────────────────────────────────────
  static const _navItems = [
    _NavItem(icon: FontAwesomeIcons.gaugeHigh, label: 'Dashboard'),
    _NavItem(icon: FontAwesomeIcons.calendarDays, label: 'Rota'),
    _NavItem(icon: FontAwesomeIcons.clockRotateLeft, label: 'Timesheets'),
    _NavItem(icon: FontAwesomeIcons.users, label: 'Staff'),
    _NavItem(icon: FontAwesomeIcons.umbrellaBeach, label: 'Leave'),
    _NavItem(icon: FontAwesomeIcons.moneyBillWave, label: 'Payroll'),
    _NavItem(icon: FontAwesomeIcons.chartBar, label: 'Reports'),
    _NavItem(icon: FontAwesomeIcons.bell, label: 'Alerts'),
    _NavItem(icon: FontAwesomeIcons.qrcode, label: 'Daily QR'),
    _NavItem(icon: FontAwesomeIcons.houseMedical, label: 'Clients'),
    _NavItem(icon: FontAwesomeIcons.gear, label: 'Settings'),
  ];

  // ── Page builder ───────────────────────────────────────────────────────────
  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return _AdminOverviewPage(
          user: widget.user,
          onNavigate: (i) => setState(() => _selectedIndex = i),
        );
      case 1:
        return const AdminRotaPage();
      case 2:
        return const AdminTimesheetPage();
      case 3:
        return const StaffManagementPage();
      case 4:
        return const AdminLeaveManagementPage();
      case 5:
        return const PayrollPage();
      case 6:
        return const ReportsPage();
      case 7:
        return const AlertsPage();
      case 8:
        return const QrManagementPage();
      case 9:
        return const ClientManagementPage();
      case 10:
        return const SettingsPage();
      default:
        return const SizedBox.shrink();
    }
  }

  void _onNavTap(int index) {
    if (index == 11) {
      _confirmSignOut();
      return;
    }
    setState(() => _selectedIndex = index);
  }

  Future<void> _confirmSignOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final ok = await showConfirmDialog(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
      isDestructive: true,
    );
    if (ok == true && mounted) {
      await authService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  // ── Primary bottom-nav indices (shown as tabs) ─────────────────────────────
  static const _primaryMobileIndices = [0, 1, 2, 8]; // Dashboard, Rota, Timesheets, QR Code
  // Everything else is accessible via "More" bottom sheet
  static const _moreMenuIndices = [3, 4, 5, 6, 7, 9, 10]; // Staff, Leave, Payroll, Reports, Alerts, Clients, Settings

  bool get _isMorePage => _moreMenuIndices.contains(_selectedIndex);

  // ── "More" bottom sheet ────────────────────────────────────────────────────
  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('More',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1.1,
                  children: _moreMenuIndices.map((i) {
                    final item = _navItems[i];
                    final selected = _selectedIndex == i;
                    return _MoreMenuItem(
                      icon: item.icon,
                      label: item.label,
                      selected: selected,
                      badgeCount: i == 7 ? _unreadAlertCount : 0,
                      onTap: () {
                        Navigator.pop(ctx);
                        _onNavTap(i);
                      },
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 24),
              // Sign out row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded,
                      size: 20, color: Color(0xFFD32F2F)),
                  title: const Text('Sign Out',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD32F2F))),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmSignOut();
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final showSidebar = Responsive.showSidebar(context);

    if (showSidebar) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            AppSidebar(
                selectedIndex: _selectedIndex,
                onItemTap: _onNavTap,
                userName: widget.user.name,
                userRole: 'Administrator',
                primaryCount: 5, // Dashboard, Rota, Timesheets, Staff, Leave always visible
                items: _navItems
                  .asMap()
                  .entries
                  .map((e) => SidebarItem(
                    icon: e.value.icon,
                    label: e.value.label,
                    index: e.key,
                    badgeCount: e.key == 7 ? _unreadAlertCount : 0,
                    ))
                  .toList(),
                onSignOut: _confirmSignOut,
            ),
            Expanded(child: _buildPage(_selectedIndex)),
          ],
        ),
      );
    }

    // Mobile / Tablet: bottom nav + "More" sheet
    return Scaffold(
      backgroundColor: AppColors.background,
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
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _onNavTap(7),
            tooltip: 'Alerts',
            icon: Badge(
              isLabelVisible: _unreadAlertCount > 0,
              label: Text(
                _unreadAlertCount > 9 ? '9+' : _unreadAlertCount.toString(),
                style: const TextStyle(fontSize: 10),
              ),
              child: const Icon(Icons.notifications_outlined, size: 20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: _confirmSignOut,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.teal.withValues(alpha: 0.2),
                child: Text(
                  widget.user.name.isNotEmpty
                      ? widget.user.name[0].toUpperCase()
                      : 'A',
                  style: const TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildPage(_selectedIndex),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    // Compute which tab is active
    final int activeTabIndex;
    if (_primaryMobileIndices.contains(_selectedIndex)) {
      activeTabIndex = _primaryMobileIndices.indexOf(_selectedIndex);
    } else if (_isMorePage) {
      activeTabIndex = _primaryMobileIndices.length; // "More" tab
    } else {
      activeTabIndex = 0;
    }

    final items = <BottomNavigationBarItem>[
      ..._primaryMobileIndices.map((i) {
        final item = _navItems[i];
        return BottomNavigationBarItem(
          icon: FaIcon(item.icon, size: 17),
          activeIcon: FaIcon(item.icon, size: 17),
          label: item.label,
        );
      }),
      BottomNavigationBarItem(
        icon: Icon(_isMorePage ? Icons.grid_view_rounded : Icons.more_horiz_rounded, size: 20),
        activeIcon: const Icon(Icons.grid_view_rounded, size: 20),
        label: 'More',
      ),
    ];

    return BottomNavigationBar(
      currentIndex: activeTabIndex,
      onTap: (i) {
        if (i == _primaryMobileIndices.length) {
          _showMoreMenu();
        } else {
          _onNavTap(_primaryMobileIndices[i]);
        }
      },
      items: items,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.teal,
      unselectedItemColor: AppColors.textMuted,
      backgroundColor: AppColors.surface,
      elevation: 12,
      selectedFontSize: 10,
      unselectedFontSize: 10,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN OVERVIEW PAGE (index 0)
// ─────────────────────────────────────────────────────────────────────────────
class _AdminOverviewPage extends StatefulWidget {
  final UserModel user;
  final ValueChanged<int> onNavigate;
  const _AdminOverviewPage({required this.user, required this.onNavigate});

  @override
  State<_AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<_AdminOverviewPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _todayAttendance = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rotaService = Provider.of<RotaService>(context, listen: false);
      final attendanceService = Provider.of<AttendanceService>(context, listen: false);
      
      final rotaStats = await rotaService.getStats();
      final attStats = await attendanceService.getTodayAdminStats();
      
      if (mounted) {
        setState(() {
          _stats = rotaStats;
          _todayAttendance = attStats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = Responsive.contentPadding(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.teal,
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.all(pad),
            children: [
              // ── Connection error banner ────────────────────────────────
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 22, color: AppColors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Connection Error',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.error)),
                            const SizedBox(height: 2),
                            Text(
                              _error!.contains('connect')
                                  ? 'Cannot reach the server. Pull down to retry.'
                                  : 'Something went wrong. Pull down to retry.',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.error),
                        tooltip: 'Retry',
                      ),
                    ],
                  ),
                ),
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Temple Clock Admin',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis),
                        Text('Welcome back, ${widget.user.name.split(' ').first}',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.tealLight,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(FontAwesomeIcons.shieldHalved,
                            size: 11, color: AppColors.tealDark),
                        const SizedBox(width: 6),
                        Text('Admin',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.tealDark)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Today\'s Attendance'),
              const SizedBox(height: 12),
              _loading
                  ? const Center(child: CircularProgressIndicator(
                      color: AppColors.teal, strokeWidth: 2))
                  : _buildAttendanceStats(),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Rota Overview'),
              const SizedBox(height: 12),
              _loading
                  ? const SizedBox.shrink()
                  : _buildRotaStats(),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Quick Actions'),
              const SizedBox(height: 12),
              _buildQuickActions(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceStats() {
    final cols = Responsive.gridColumns(context,
        mobile: 2, tablet: 2, desktop: 4);
    final active = _todayAttendance['activeShifts'] ?? 0;
    final late = _todayAttendance['lateCount'] ?? 0;
    final completed = _todayAttendance['completedShifts'] ?? 0;
    final extra =
        (_todayAttendance['extraHoursTotal'] as double? ?? 0.0);
    final screenW = MediaQuery.of(context).size.width;
    final aspectRatio = Responsive.isDesktop(context)
        ? 1.5
        : (screenW < 380 ? 0.95 : 1.1);

    return GridView.count(
      crossAxisCount: cols,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: aspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        KpiCard(
          title: 'Active Now',
          value: '$active',
          subtitle: 'Clocked in',
          icon: FontAwesomeIcons.userCheck,
          accentColor: AppColors.teal,
        ),
        KpiCard(
          title: 'Late Today',
          value: '$late',
          subtitle: 'Past grace period',
          icon: FontAwesomeIcons.triangleExclamation,
          accentColor: const Color(0xFFFF8F00),
        ),
        KpiCard(
          title: 'Completed',
          value: '$completed',
          subtitle: 'Shifts done',
          icon: FontAwesomeIcons.circleCheck,
          accentColor: const Color(0xFF27AE60),
        ),
        KpiCard(
          title: 'Extra Hrs',
          value: extra.toStringAsFixed(1),
          subtitle: 'Overtime today',
          icon: FontAwesomeIcons.hourglass,
          accentColor: const Color(0xFF1565C0),
        ),
      ],
    );
  }

  Widget _buildRotaStats() {
    final total = _stats['totalShifts'] ?? 0;
    final today = _stats['todayShifts'] ?? 0;
    final upcoming = _stats['upcomingShifts'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: FontAwesomeIcons.calendarDays,
            value: '$total',
            label: 'Total Shifts',
            color: AppColors.navy,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: FontAwesomeIcons.calendarDay,
            value: '$today',
            label: 'Today',
            color: AppColors.teal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: FontAwesomeIcons.forward,
            value: '$upcoming',
            label: 'Upcoming',
            color: const Color(0xFF1565C0),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _QuickAction(
          icon: FontAwesomeIcons.calendarPlus,
          label: 'Add Shift',
          color: AppColors.navy,
          onTap: () => widget.onNavigate(1),
        ),
        _QuickAction(
          icon: FontAwesomeIcons.clockRotateLeft,
          label: 'View Timesheets',
          color: AppColors.teal,
          onTap: () => widget.onNavigate(2),
        ),
        _QuickAction(
          icon: FontAwesomeIcons.chartBar,
          label: 'Export Rota',
          color: const Color(0xFF27AE60),
          onTap: () => widget.onNavigate(6),
        ),
        _QuickAction(
          icon: FontAwesomeIcons.userPlus,
          label: 'Add Staff',
          color: const Color(0xFF7B1FA2),
          onTap: () => widget.onNavigate(3),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL HELPERS
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.0),
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF90A4AE)),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, size: 13, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  const _MoreMenuItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? AppColors.teal.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? Border.all(color: AppColors.teal.withValues(alpha: 0.25))
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.teal.withValues(alpha: 0.12)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: FaIcon(icon,
                        size: 18,
                        color: selected ? AppColors.teal : AppColors.textMuted),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.teal : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
