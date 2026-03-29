import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/rota_model.dart';
import '../../models/user_model.dart';
import '../../services/rota_service.dart';
import '../../core/constants.dart';

class StaffShiftsPage extends StatefulWidget {
  final UserModel user;
  const StaffShiftsPage({super.key, required this.user});

  @override
  State<StaffShiftsPage> createState() => _StaffShiftsPageState();
}

class _StaffShiftsPageState extends State<StaffShiftsPage>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['All', 'Scheduled', 'Completed', 'Cancelled'];

  late final TabController _tabCtrl;
  List<RotaShift>? _shifts;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _fetchShifts();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchShifts() async {
    try {
      final rotaService = Provider.of<RotaService>(context, listen: false);
      final shifts = await rotaService.getMyShifts();
      if (mounted) {
        setState(() {
          _shifts = shifts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching shifts: $e")),
        );
      }
    }
  }

  List<RotaShift> _filtered(int tabIndex) {
    if (_shifts == null) return [];
    if (tabIndex == 0) return _shifts!;
    final status = _tabs[tabIndex].toLowerCase();
    return _shifts!.where((s) => s.status.toLowerCase() == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Tab bar ──
        Material(
          color: Colors.white,
          child: TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.teal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.teal,
            onTap: (_) => setState(() {}),
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
        // ── Content ──
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildList(),
        ),
      ],
    );
  }

  Widget _buildList() {
    final list = _filtered(_tabCtrl.index);
    if (list.isEmpty) {
      return Center(
        child: Text(
          _tabCtrl.index == 0
              ? 'No shifts scheduled.'
              : 'No ${_tabs[_tabCtrl.index].toLowerCase()} shifts.',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchShifts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final shift = list[index];
          final df = DateFormat("EEEE, MMM d");
          final tf = DateFormat("HH:mm");

          Color chipColor;
          switch (shift.status.toLowerCase()) {
            case 'completed':
              chipColor = Colors.green.shade100;
              break;
            case 'cancelled':
              chipColor = Colors.red.shade100;
              break;
            default:
              chipColor = Colors.blue.shade100;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.event),
              title: Text(df.format(shift.startTime)),
              subtitle: Text(
                  "${tf.format(shift.startTime)} – ${tf.format(shift.endTime)}"),
              trailing: Chip(
                label: Text(shift.status),
                backgroundColor: chipColor,
              ),
            ),
          );
        },
      ),
    );
  }
}
