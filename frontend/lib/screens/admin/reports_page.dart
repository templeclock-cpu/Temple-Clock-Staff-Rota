import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../../core/constants.dart';
import '../../core/responsive.dart';
import '../../services/api_service.dart';
import '../../widgets/shared_widgets.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late String _selectedMonth;
  String _sortOrder = 'default'; // default or reversed

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = Responsive.contentPadding(context);
    final cols = Responsive.gridColumns(context, mobile: 1, tablet: 2, desktop: 3);

    var reports = [
      _ReportType(
        title: 'Rota Report',
        subtitle: 'All scheduled shifts for the month',
        icon: Icons.calendar_month,
        color: const Color(0xFF1565C0),
        endpoint: '/reports/rota',
        filename: 'TempleClock_Rota',
      ),
      _ReportType(
        title: 'Attendance Report',
        subtitle: 'Clock-in/out records, lateness, overtime',
        icon: Icons.schedule,
        color: AppColors.teal,
        endpoint: '/reports/attendance',
        filename: 'TempleClock_Attendance',
      ),
      _ReportType(
        title: 'Payroll Report',
        subtitle: 'Hours worked, pay calculations, adjustments',
        icon: Icons.payments,
        color: const Color(0xFF7B1FA2),
        endpoint: '/reports/payroll',
        filename: 'TempleClock_Payroll',
      ),
      _ReportType(
        title: 'Staff Report',
        subtitle: 'Employee details, rates, departments',
        icon: Icons.people,
        color: const Color(0xFFE65100),
        endpoint: '/reports/staff',
        filename: 'TempleClock_Staff',
      ),
      _ReportType(
        title: 'Leave Report',
        subtitle: 'Leave requests, balances, approvals',
        icon: Icons.beach_access,
        color: const Color(0xFF00838F),
        endpoint: '/reports/leave',
        filename: 'TempleClock_Leave',
      ),
    ];

    if (_sortOrder == 'reversed') {
      reports = reports.reversed.toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(pad),
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reports & Export',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary)),
                      Text('Download Excel reports for any month',
                          style:
                              TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    ],
                  ),
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
              ],
            ),
            const SizedBox(height: 16),

            // Sort control
            Row(
              children: [
                const Icon(Icons.sort, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 8),
                const Text('Order:', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(width: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'default', label: Text('A–Z', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'reversed', label: Text('Z–A', style: TextStyle(fontSize: 12))),
                  ],
                  selected: {_sortOrder},
                  onSelectionChanged: (v) => setState(() => _sortOrder = v.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Report cards grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: cols == 1 ? 3.0 : 1.8,
              ),
              itemCount: reports.length,
              itemBuilder: (_, i) => _ReportCard(
                report: reports[i],
                month: _selectedMonth,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportType {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String endpoint;
  final String filename;

  const _ReportType({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.endpoint,
    required this.filename,
  });
}

class _ReportCard extends StatefulWidget {
  final _ReportType report;
  final String month;

  const _ReportCard({required this.report, required this.month});

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final endpoint = '${widget.report.endpoint}?month=${widget.month}';
      final response = await apiService.get(endpoint);

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final blob = html.Blob([bytes],
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', '${widget.report.filename}_${widget.month}.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);

        if (mounted) {
          showAppSnackBar(context, '${widget.report.title} downloaded successfully');
        }
      } else {
        String msg = 'Download failed';
        try {
          final data = jsonDecode(response.body);
          msg = data['message'] ?? msg;
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Download failed: ${e.toString().replaceAll("Exception: ", "")}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.report.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.report.icon, color: widget.report.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.report.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(widget.report.subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _downloading ? null : _download,
              icon: _downloading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download, size: 14),
              label: Text(
                _downloading ? 'Downloading...' : 'Download',
                style: const TextStyle(fontSize: 12),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: widget.report.color,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
