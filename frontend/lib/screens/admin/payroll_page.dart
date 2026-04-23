import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants.dart';
import '../../core/responsive.dart';
import '../../models/payroll_model.dart';
import '../../services/payroll_service.dart';
import '../../services/export_service.dart';
import '../../widgets/shared_widgets.dart';

class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key});

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  List<PayrollRecord> _records = [];
  bool _loading = false;
  bool _generating = false;
  late String _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateFormat('yyyy-MM').format(now);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final svc = Provider.of<PayrollService>(context, listen: false);
      final records = await svc.getPayroll(month: _selectedMonth);
      if (mounted) setState(() { _records = records; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showAppSnackBar(context, 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final svc = Provider.of<PayrollService>(context, listen: false);
      final result = await svc.generatePayroll(_selectedMonth);
      if (mounted) {
        showAppSnackBar(context,
            'Payroll generated for ${result['count']} staff');
        _load();
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _finalize(PayrollRecord rec) async {
    final ok = await showConfirmDialog(context,
        title: 'Finalize Payroll',
        message: 'Finalize payroll for ${rec.staffName}? This cannot be undone.',
        confirmLabel: 'Finalize');
    if (ok == true) {
      try {
        final svc = Provider.of<PayrollService>(context, listen: false);
        await svc.finalizePayroll(rec.id);
        if (mounted) { showAppSnackBar(context, 'Payroll finalized'); _load(); }
      } catch (e) {
        if (mounted) showAppSnackBar(context, '$e', isError: true);
      }
    }
  }

  void _showAdjustmentDialog(PayrollRecord rec) {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Adjustment — ${rec.staffName ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: InputDecoration(
                  labelText: 'Amount (£) — negative for deductions',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final desc = descCtrl.text.trim();
              final amt = double.tryParse(amountCtrl.text);
              if (desc.isEmpty || amt == null) {
                showAppSnackBar(context, 'Fill all fields', isError: true);
                return;
              }
              try {
                final svc = Provider.of<PayrollService>(context, listen: false);
                await svc.addAdjustment(rec.id, desc, amt);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) { showAppSnackBar(context, 'Adjustment added'); _load(); }
              } catch (e) {
                if (mounted) showAppSnackBar(context, '$e', isError: true);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _pickMonth() async {
    final now = DateTime.now();
    final parts = _selectedMonth.split('-');
    final initDate = DateTime(int.parse(parts[0]), int.parse(parts[1]));

    final picked = await showDatePicker(
      context: context,
      initialDate: initDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(now.year + 1, 12),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null && mounted) {
      setState(() => _selectedMonth = DateFormat('yyyy-MM').format(picked));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = Responsive.contentPadding(context);
    final totalGross = _records.fold(0.0, (s, r) => s + r.grossPay);
    final totalFinal = _records.fold(0.0, (s, r) => s + r.finalPay);
    final totalHours = _records.fold(0.0, (s, r) => s + r.totalHoursWorked);
    final finalized = _records.where((r) => r.status == 'finalized').length;

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
                  const Expanded(
                    child: Text('Payroll',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickMonth,
                    icon: const Icon(Icons.calendar_month, size: 16),
                    label: Text(_selectedMonth),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _generating ? null : _generate,
                    icon: _generating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.calculate, size: 16),
                    label: const Text('Generate'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Export Button
                  IconButton(
                    onPressed: () {
                      ExportService.exportPayrollCsv(_records, "payroll_$_selectedMonth");
                    },
                    icon: const Icon(Icons.download, color: AppColors.teal),
                    tooltip: 'Export to Excel/CSV',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.teal.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // KPI cards
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  KpiCard(
                      title: 'Total Hours',
                      value: '${totalHours.toStringAsFixed(1)}h',
                      subtitle: 'this month',
                      icon: FontAwesomeIcons.clock,
                      accentColor: AppColors.navy),
                  KpiCard(
                      title: 'Gross Pay',
                      value: '£${totalGross.toStringAsFixed(2)}',
                      subtitle: 'before adjustments',
                      icon: FontAwesomeIcons.sterlingSign,
                      accentColor: AppColors.teal),
                  KpiCard(
                      title: 'Final Pay',
                      value: '£${totalFinal.toStringAsFixed(2)}',
                      subtitle: 'after adjustments',
                      icon: FontAwesomeIcons.wallet,
                      accentColor: const Color(0xFF7B1FA2)),
                  KpiCard(
                      title: 'Finalized',
                      value: '$finalized / ${_records.length}',
                      subtitle: 'records locked',
                      icon: FontAwesomeIcons.circleCheck,
                      accentColor: AppColors.success),
                ],
              ),
              const SizedBox(height: 20),

              // Payroll list
              if (_loading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                            color: AppColors.teal, strokeWidth: 2)))
              else if (_records.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('No payroll records for this month.\nTap Generate to create.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                )
              else
                ..._records.map((r) => _PayrollCard(
                      record: r,
                      onAdjust: () => _showAdjustmentDialog(r),
                      onFinalize: () => _finalize(r),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayrollCard extends StatelessWidget {
  final PayrollRecord record;
  final VoidCallback onAdjust;
  final VoidCallback onFinalize;

  const _PayrollCard({
    required this.record,
    required this.onAdjust,
    required this.onFinalize,
  });

  @override
  Widget build(BuildContext context) {
    final isFinalized = record.status == 'finalized';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isFinalized
                ? AppColors.teal.withValues(alpha: 0.3)
                : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                child: Text(
                  record.staffName?.isNotEmpty == true
                      ? record.staffName![0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.staffName ?? 'Unknown',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    if (record.staffDepartment?.isNotEmpty == true)
                      Text(record.staffDepartment!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isFinalized
                      ? AppColors.teal.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isFinalized ? 'Finalized' : 'Draft',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isFinalized ? AppColors.teal : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              _stat('Hours', '${record.totalHoursWorked.toStringAsFixed(1)}h'),
              _stat('OT', '${record.overtimeHours.toStringAsFixed(1)}h'),
              _stat('Rate', '£${record.hourlyRate.toStringAsFixed(2)}'),
              _stat('Gross', '£${record.grossPay.toStringAsFixed(2)}'),
              _stat('Final', '£${record.finalPay.toStringAsFixed(2)}',
                  bold: true),
            ],
          ),
          // Adjustments
          if (record.adjustments.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...record.adjustments.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Icon(
                          a.amount >= 0
                              ? Icons.add_circle_outline
                              : Icons.remove_circle_outline,
                          size: 13,
                          color:
                              a.amount >= 0 ? AppColors.success : AppColors.error),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(a.description,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                      ),
                      Text(
                        '${a.amount >= 0 ? '+' : ''}£${a.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              a.amount >= 0 ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          if (!isFinalized) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onAdjust,
                  icon: const Icon(Icons.tune, size: 14),
                  label: const Text('Adjust', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: onFinalize,
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text('Finalize', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value, {bool bold = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: AppColors.textPrimary)),
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
