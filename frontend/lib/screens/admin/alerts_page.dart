import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/responsive.dart';
import '../../models/alert_model.dart';
import '../../models/user_model.dart';
import '../../services/alert_service.dart';
import '../../services/user_service.dart';
import '../../widgets/shared_widgets.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  List<AlertModel> _alerts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final svc = Provider.of<AlertService>(context, listen: false);
      final alerts = await svc.getAlerts();
      if (mounted) setState(() { _alerts = alerts; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showAppSnackBar(context, 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _markRead(AlertModel alert) async {
    try {
      final svc = Provider.of<AlertService>(context, listen: false);
      await svc.markAlertRead(alert.id);
      _load();
    } catch (_) {}
  }

  void _showSendDialog() {
    final msgCtrl = TextEditingController();
    String? selectedStaffId;
    List<UserModel> staffList = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          // Load staff list on first build
          if (staffList.isEmpty) {
            Provider.of<UserService>(context, listen: false)
                .getUsers()
                .then((users) {
              if (ctx.mounted) {
                setDState(() => staffList = users.where((u) => u.role == 'staff').toList());
              }
            });
          }

          return AlertDialog(
            title: const Text('Send Notice to Staff',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedStaffId,
                    decoration: InputDecoration(
                      labelText: 'Select Staff',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    items: staffList
                        .map((u) => DropdownMenuItem(
                            value: u.id, child: Text(u.name)))
                        .toList(),
                    onChanged: (v) => setDState(() => selectedStaffId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: msgCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (selectedStaffId == null || msgCtrl.text.trim().isEmpty) {
                    showAppSnackBar(context, 'Select staff and enter message',
                        isError: true);
                    return;
                  }
                  try {
                    final svc =
                        Provider.of<AlertService>(context, listen: false);
                    await svc.sendAlertToStaff(
                        selectedStaffId!, msgCtrl.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      showAppSnackBar(context, 'Notice sent');
                      _load();
                    }
                  } catch (e) {
                    if (mounted) showAppSnackBar(context, '$e', isError: true);
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                child: const Text('Send'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = Responsive.contentPadding(context);
    final unread = _alerts.where((a) => !a.readByAdmin).length;

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
                        const Text('Alerts & Notifications',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary)),
                        Text('$unread unread alerts',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _showSendDialog,
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Send Notice'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_loading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                            color: AppColors.teal, strokeWidth: 2)))
              else if (_alerts.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('No alerts yet',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                )
              else
                ..._alerts.map((a) => _AlertTile(
                      alert: a,
                      onMarkRead: () => _markRead(a),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback onMarkRead;

  const _AlertTile({required this.alert, required this.onMarkRead});

  IconData get _icon {
    switch (alert.alertType) {
      case 'running_late':
        return Icons.access_time;
      case 'emergency':
        return Icons.warning_amber;
      case 'admin_notice':
        return Icons.campaign;
      default:
        return Icons.info_outline;
    }
  }

  Color get _color {
    switch (alert.alertType) {
      case 'running_late':
        return Colors.orange;
      case 'emergency':
        return AppColors.error;
      case 'admin_notice':
        return const Color(0xFF1565C0);
      default:
        return AppColors.textMuted;
    }
  }

  String get _typeLabel {
    switch (alert.alertType) {
      case 'running_late':
        return 'Running Late';
      case 'emergency':
        return 'Emergency';
      case 'admin_notice':
        return 'Admin Notice';
      default:
        return 'General';
    }
  }

  String get _displayEntityName {
    if (alert.alertType == 'admin_notice') {
      return 'To: ${alert.targetStaffName ?? 'Staff'}';
    }
    return alert.staffName ?? 'Unknown Staff';
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy, HH:mm');
    final isUnread = !alert.readByAdmin;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnread
            ? AppColors.teal.withValues(alpha: 0.04)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isUnread
                ? AppColors.teal.withValues(alpha: 0.2)
                : AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon, color: _color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_typeLabel,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _color)),
                    ),
                    const SizedBox(width: 6),
                    Text(_displayEntityName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    if (alert.estimatedDelay > 0) ...[
                      const SizedBox(width: 6),
                      Text('~${alert.estimatedDelay} min delay',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.orange)),
                    ],
                  ],
                ),
                if (alert.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(alert.message,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 4),
                Text(df.format(alert.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (isUnread)
            IconButton(
              icon: const Icon(Icons.check_circle_outline,
                  size: 18, color: AppColors.teal),
              onPressed: onMarkRead,
              tooltip: 'Mark as read',
            ),
        ],
      ),
    );
  }
}
