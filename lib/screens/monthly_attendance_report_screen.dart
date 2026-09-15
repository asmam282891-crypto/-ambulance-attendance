import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/employee.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';

/// شاشة تقرير شامل لموظف واحد بعينه: نسبة الحضور، متوسط التأخير،
/// وقائمة تفصيلية بكل يوم في الفترة المحددة، مع إمكانية الطباعة.
class MonthlyAttendanceReportScreen extends StatefulWidget {
  const MonthlyAttendanceReportScreen({super.key});

  @override
  State<MonthlyAttendanceReportScreen> createState() =>
      _MonthlyAttendanceReportScreenState();
}

class _MonthlyAttendanceReportScreenState
    extends State<MonthlyAttendanceReportScreen> {
  bool _loadingEmployees = true;
  bool _loadingReport = false;
  bool _printing = false;
  String? _error;

  List<Employee> _employees = [];
  Employee? _selectedEmployee;

  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay _officialStartTime = const TimeOfDay(hour: 8, minute: 0);

  List<Map<String, dynamic>> _dailyRecords = [];
  bool _hasReport = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loadingEmployees = true;
      _error = null;
    });

    try {
      final employees = await SupabaseService.instance.fetchEmployees();
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _loadingEmployees = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'حدث خطأ أثناء تحميل قائمة الموظفين: $e';
        _loadingEmployees = false;
      });
    }
  }

  Future<void> _pickStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Directionality(textDirection: ui.TextDirection.rtl, child: child!);
      },
    );
    if (selected == null) return;
    setState(() {
      _startDate = selected;
      if (_endDate.isBefore(_startDate)) _endDate = _startDate;
    });
  }

  Future<void> _pickEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Directionality(textDirection: ui.TextDirection.rtl, child: child!);
      },
    );
    if (selected == null) return;
    setState(() {
      _endDate = selected;
    });
  }

  Future<void> _pickOfficialStartTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _officialStartTime,
      builder: (context, child) {
        return Directionality(textDirection: ui.TextDirection.rtl, child: child!);
      },
    );
    if (selected == null) return;
    setState(() {
      _officialStartTime = selected;
    });
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    if (value is String && value.trim().isNotEmpty) {
      try {
        return DateTime.parse(value).toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// يرجع مدة التأخير بالدقايق (0 لو مفيش تأخير)، أو null لو مفيش حضور أصلاً.
  int? _delayMinutes(dynamic checkInValue) {
    final checkInTime = _parseDateTime(checkInValue);
    if (checkInTime == null) return null;

    final officialDateTime = DateTime(
      checkInTime.year,
      checkInTime.month,
      checkInTime.day,
      _officialStartTime.hour,
      _officialStartTime.minute,
    );

    final diff = checkInTime.difference(officialDateTime).inMinutes;
    return diff > 0 ? diff : 0;
  }

  String _formatDelay(dynamic checkInValue) {
    final minutes = _delayMinutes(checkInValue);
    if (minutes == null) return '-';
    if (minutes == 0) return 'لا يوجد';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) return '$hours س $mins د';
    return '$mins دقيقة';
  }

  String _formatTime(dynamic value) {
    final parsed = _parseDateTime(value);
    if (parsed == null) return '-';
    return DateFormat('hh:mm a').format(parsed);
  }

  Future<void> _viewReport() async {
    final employee = _selectedEmployee;
    if (employee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('من فضلك اختر موظفًا أولًا')),
      );
      return;
    }

    setState(() {
      _loadingReport = true;
      _error = null;
      _hasReport = false;
    });

    try {
      final records = await SupabaseService.instance.fetchEmployeeMonthlyDetail(
        userId: employee.id,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (!mounted) return;
      setState(() {
        _dailyRecords = records;
        _hasReport = true;
        _loadingReport = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'حدث خطأ أثناء تحميل التقرير: $e';
        _loadingReport = false;
      });
    }
  }

  // ================================================================
  // حسابات ملخص التقرير
  // ================================================================

  int get _presentDays => _dailyRecords
      .where((r) => r['status'] == 'حاضر' || r['status'] == 'انصرف')
      .length;

  int get _absentDays =>
      _dailyRecords.where((r) => r['status'] == 'غائب').length;

  int get _scheduledDays =>
      _dailyRecords.where((r) => r['is_scheduled'] == true).length;

  double get _attendancePercentage {
    if (_scheduledDays == 0) return 0;
    return (_presentDays / _scheduledDays) * 100;
  }

  String get _averageDelay {
    final delays = _dailyRecords
        .where((r) => r['status'] == 'حاضر' || r['status'] == 'انصرف')
        .map((r) => _delayMinutes(r['check_in']))
        .whereType<int>()
        .toList();

    if (delays.isEmpty) return 'لا يوجد';

    final avgMinutes = delays.reduce((a, b) => a + b) / delays.length;
    if (avgMinutes < 1) return 'لا يوجد';

    final rounded = avgMinutes.round();
    final hours = rounded ~/ 60;
    final mins = rounded % 60;
    if (hours > 0) return '$hours س $mins د';
    return '$mins دقيقة';
  }

  Future<void> _printReport() async {
    if (_printing || !_hasReport) return;
    final employee = _selectedEmployee;
    if (employee == null) return;

    setState(() {
      _printing = true;
    });

    try {
      final regularFont = await PdfGoogleFonts.amiriRegular();
      final boldFont = await PdfGoogleFonts.amiriBold();

      final rows = _dailyRecords.map((r) {
        final date = DateTime.parse(r['the_date'].toString());
        return <String>[
          _formatDelay(r['check_in']),
          (r['status'] ?? '-').toString(),
          _formatTime(r['check_out']),
          _formatTime(r['check_in']),
          DateFormat('yyyy/MM/dd').format(date),
        ];
      }).toList();

      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
          build: (pw.Context pdfContext) => [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text(
                    'الإسعاف القومي',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'تقرير حضور الموظف: ${employee.fullName}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'الفترة: ${DateFormat('yyyy/MM/dd').format(_startDate)} '
                    'إلى ${DateFormat('yyyy/MM/dd').format(_endDate)}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('أيام الحضور: $_presentDays'),
                      pw.Text('أيام الغياب: $_absentDays'),
                      pw.Text(
                        'نسبة الحضور: ${_attendancePercentage.toStringAsFixed(0)}%',
                      ),
                      pw.Text('متوسط التأخير: $_averageDelay'),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Table.fromTextArray(
                    headers: [
                      'مدة التأخير',
                      'الحالة',
                      'وقت الانصراف',
                      'وقت الحضور',
                      'التاريخ',
                    ],
                    data: rows,
                    headerStyle: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFD32F2F),
                    ),
                    rowDecoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE3E6EA)),
                      ),
                    ),
                    cellAlignment: pw.Alignment.center,
                    headerAlignment: pw.Alignment.center,
                    cellPadding:
                        const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    border: pw.TableBorder.all(
                      color: const PdfColor.fromInt(0xFFE3E6EA),
                      width: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) => document.save(),
        name: 'employee-report-${employee.fullName}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشلت عملية الطباعة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _printing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تقرير موظف - عدد أيام الحضور'),
          centerTitle: true,
          backgroundColor: AppColors.ambulanceRed,
          foregroundColor: Colors.white,
          actions: [
            if (_hasReport)
              IconButton(
                onPressed: _printing ? null : _printReport,
                tooltip: 'طباعة التقرير',
                icon: _printing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.print_outlined),
              ),
          ],
        ),
        backgroundColor: AppColors.background,
        body: _loadingEmployees
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.ambulanceRed),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildEmployeePicker(),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickStartDate,
                                icon: const Icon(Icons.calendar_month),
                                label: Text(
                                  'من: ${DateFormat('yyyy/MM/dd').format(_startDate)}',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickEndDate,
                                icon: const Icon(Icons.calendar_month),
                                label: Text(
                                  'إلى: ${DateFormat('yyyy/MM/dd').format(_endDate)}',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _pickOfficialStartTime,
                          icon: const Icon(Icons.schedule),
                          label: Text(
                            'بداية الدوام الرسمي: ${_officialStartTime.format(context)}',
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _loadingReport ? null : _viewReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.ambulanceRed,
                              foregroundColor: Colors.white,
                            ),
                            icon: _loadingReport
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.assignment_outlined),
                            label: const Text('عرض التقرير'),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_error != null)
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        if (_hasReport) ..._buildReportContent(),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildEmployeePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Employee>(
          isExpanded: true,
          hint: const Text('اختر الموظف'),
          value: _selectedEmployee,
          items: _employees
              .map(
                (employee) => DropdownMenuItem<Employee>(
                  value: employee,
                  child: Text('${employee.fullName} — ${employee.roleLabel}'),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedEmployee = value;
              _hasReport = false;
            });
          },
        ),
      ),
    );
  }

  List<Widget> _buildReportContent() {
    final employee = _selectedEmployee!;

    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(radius: 25, child: Icon(Icons.person)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.fullName,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      employee.roleLabel,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        'الفترة: ${DateFormat('yyyy/MM/dd').format(_startDate)} '
        'إلى ${DateFormat('yyyy/MM/dd').format(_endDate)}',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: StatCard(
              emoji: '✅',
              label: 'أيام الحضور',
              value: _presentDays,
              color: AppColors.success,
              backgroundColor: AppColors.successBg,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatCard(
              emoji: '❌',
              label: 'أيام الغياب',
              value: _absentDays,
              color: AppColors.danger,
              backgroundColor: AppColors.dangerBg,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text(
                    '${_attendancePercentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('نسبة الحضور', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text(
                    _averageDelay,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('متوسط التأخير', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      StatCard(
        emoji: '📅',
        label: 'إجمالي أيام الدوام المفروضة',
        value: _scheduledDays,
        color: AppColors.navy,
        backgroundColor: AppColors.background,
      ),
      const SizedBox(height: 20),
      const Align(
        alignment: Alignment.centerRight,
        child: Text(
          'التفاصيل اليومية',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 10),
      ..._dailyRecords.map(_buildDayTile),
    ];
  }

  Widget _buildDayTile(Map<String, dynamic> record) {
    final date = DateTime.parse(record['the_date'].toString());
    final status = (record['status'] ?? '-').toString();
    final checkIn = _formatTime(record['check_in']);
    final checkOut = _formatTime(record['check_out']);
    final delay = _formatDelay(record['check_in']);

    final isPresent = status == 'حاضر' || status == 'انصرف';
    final isAbsent = status == 'غائب';

    final Color badgeColor = isPresent
        ? AppColors.success
        : isAbsent
            ? AppColors.danger
            : Colors.grey;
    final Color badgeBg = isPresent
        ? AppColors.successBg
        : isAbsent
            ? AppColors.dangerBg
            : Colors.grey.shade200;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                DateFormat('yyyy/MM/dd').format(date),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const Spacer(),
            if (isPresent) ...[
              Text('حضور $checkIn', style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 8),
              Text('انصراف $checkOut', style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 8),
              Text(
                'تأخير $delay',
                style: const TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
