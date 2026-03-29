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
//   7 = Settings
//   8 = Sign Out

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/responsive.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/rota_service.dart';
import '../../services/attendance_service.dart';
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
        return const SettingsPage();
      default:
        return const SizedBox.shrink();
    }
  }

  void _onNavTap(int index) {
    if (index == 9) {
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
                items: _navItems
                  .asMap()
                  .entries
                  .map((e) => SidebarItem(
                    icon: e.value.icon,
                    label: e.value.label,
                    index: e.key,
                    ))
                  .toList(),
                onSignOut: _confirmSignOut,
            ),
            Expanded(child: _buildPage(_selectedIndex)),
          ],
        ),
      );
    }

    // Mobile: bottom nav
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2C59),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.health_and_safety_rounded,
                  size: 16, color: AppColors.teal),
            ),
            const SizedBox(width: 8),
            const Text('CareShift',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        actions: [
          // Export / Reports shortcut
          IconButton(
            onPressed: () => _onNavTap(6),
            tooltip: 'Export Reports',
            icon: const Icon(Icons.download_rounded, size: 20),
          ),
          // Alerts shortcut
          IconButton(
            onPressed: () => _onNavTap(7),
            tooltip: 'Alerts',
            icon: const Icon(Icons.notifications_outlined, size: 20),
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
    // Mobile bottom nav: Dashboard, Rota, Timesheets, Leave, Alerts
    const mobileItems = [0, 1, 2, 4, 7];
    return BottomNavigationBar(
      currentIndex: mobileItems.contains(_selectedIndex)
          ? mobileItems.indexOf(_selectedIndex)
          : 0,
      onTap: (i) => _onNavTap(mobileItems[i]),
      items: mobileItems.map((i) {
        final item = _navItems[i];
        return BottomNavigationBarItem(
          icon: FaIcon(item.icon, size: 17),
          activeIcon: FaIcon(item.icon, size: 17),
          label: item.label,
        );
      }).toList(),
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
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _todayAttendance = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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
        setState(() => _loading = false);
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
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CareShift Admin',
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

    return GridView.count(
      crossAxisCount: cols,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: Responsive.isDesktop(context) ? 1.5 : 1.1,
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
