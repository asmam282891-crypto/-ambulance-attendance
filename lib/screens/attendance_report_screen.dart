import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:ambulance_attendance/services/supabase_service.dart';

enum ReportType { daily, monthly, employee, absent, late }

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  ReportType _selectedReportType = ReportType.daily;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _officialStartTime = const TimeOfDay(hour: 8, minute: 0);
  bool _loading = false;
  bool _printing = false;
  String? _error;

  String? _selectedEmployeeName;

  List<Map<String, dynamic>> _allRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // جلب السجلات مباشرة من خدمة Supabase
      _allRecords = await SupabaseService.instance.getAttendanceReport(
        date: _selectedDate,
      );
      _applyReportFilter();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _applyReportFilter() {
    setState(() {
      switch (_selectedReportType) {
        case ReportType.daily:
          _filteredRecords = _allRecords.where((r) {
            final checkIn = _parseDateTime(r['check_in']);
            if (checkIn == null) return true;
            return checkIn.year == _selectedDate.year &&
                checkIn.month == _selectedDate.month &&
                checkIn.day == _selectedDate.day;
          }).toList();
          break;

        case ReportType.monthly:
          _filteredRecords = _allRecords.where((r) {
            final checkIn = _parseDateTime(r['check_in']);
            if (checkIn == null) return false;
            return checkIn.year == _selectedDate.year &&
                checkIn.month == _selectedDate.month;
          }).toList();
          break;

        case ReportType.absent:
          _filteredRecords = _allRecords.where((r) {
            final isSameDay = _isSameDay(r['check_in'], _selectedDate);
            return isSameDay && _getStatus(r) == 'غائب';
          }).toList();
          break;

        case ReportType.late:
          _filteredRecords = _allRecords.where((r) {
            final isSameDay = _isSameDay(r['check_in'], _selectedDate);
            final delay = _formatDelay(r['check_in']);
            return isSameDay && delay != 'لا يوجد' && delay != '-';
          }).toList();
          break;

        case ReportType.employee:
          if (_selectedEmployeeName == null || _selectedEmployeeName!.isEmpty) {
            _filteredRecords = List.from(_allRecords);
          } else {
            _filteredRecords = _allRecords
                .where((r) => _getName(r) == _selectedEmployeeName)
                .toList();
          }
          break;
      }
    });
  }

  bool _isSameDay(dynamic dateValue, DateTime targetDate) {
    final parsed = _parseDateTime(dateValue);
    if (parsed == null) return false;
    return parsed.year == targetDate.year &&
        parsed.month == targetDate.month &&
        parsed.day == targetDate.day;
  }

  DateTime? _parseDateTime(dynamic timeValue) {
    if (timeValue == null) return null;
    if (timeValue is DateTime) return timeValue.toLocal();
    if (timeValue is String && timeValue.trim().isNotEmpty) {
      try {
        return DateTime.parse(timeValue).toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _getReportTitle() {
    final formattedDate = DateFormat('yyyy/MM/dd').format(_selectedDate);
    final formattedMonth = DateFormat('yyyy/MM').format(_selectedDate);

    switch (_selectedReportType) {
      case ReportType.daily:
        return 'تقرير الحضور اليومي — $formattedDate';
      case ReportType.monthly:
        return 'التقرير الشهري — $formattedMonth';
      case ReportType.absent:
        return 'تقرير الغياب — $formattedDate';
      case ReportType.late:
        return 'تقرير التأخيرات — $formattedDate';
      case ReportType.employee:
        return _selectedEmployeeName != null
            ? 'تقرير حضور الموظف: $_selectedEmployeeName'
            : 'تقرير حضور موظف';
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadReport();
    }
  }

  Future<void> _pickOfficialStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _officialStartTime,
    );
    if (picked != null && picked != _officialStartTime) {
      setState(() {
        _officialStartTime = picked;
      });
      _applyReportFilter();
    }
  }

  String _formatTime(dynamic timeValue) {
    final parsed = _parseDateTime(timeValue);
    if (parsed == null) return '-';
    return DateFormat('hh:mm a').format(parsed);
  }

  String _formatDelay(dynamic checkInValue) {
    final checkInTime = _parseDateTime(checkInValue);
    if (checkInTime == null) return '-';

    final officialDateTime = DateTime(
      checkInTime.year,
      checkInTime.month,
      checkInTime.day,
      _officialStartTime.hour,
      _officialStartTime.minute,
    );

    if (checkInTime.isAfter(officialDateTime)) {
      final difference = checkInTime.difference(officialDateTime);
      final hours = difference.inHours;
      final minutes = difference.inMinutes.remainder(60);

      if (hours > 0) {
        return '$hours س $minutes د';
      }
      return '$minutes دقيقة';
    }

    return 'لا يوجد';
  }

  String _getName(Map<String, dynamic> record) {
    return (record['full_name'] ??
            record['fullName'] ??
            record['name'] ??
            record['username'] ??
            'غير معروف')
        .toString();
  }

  String _getJobTitle(Map<String, dynamic> record) {
    return (record['job_title'] ??
            record['jobTitle'] ??
            record['role'] ??
            '-')
        .toString();
  }

  String _getStatus(Map<String, dynamic> record) {
    final status = record['status']?.toString().trim();

    if (status == null || status.isEmpty) {
      if (record['check_in'] != null && record['check_out'] == null) {
        return 'حاضر';
      }
      if (record['check_in'] != null && record['check_out'] != null) {
        return 'انصرف';
      }
      return '-';
    }

    switch (status.toLowerCase()) {
      case 'present':
      case 'checked_in':
      case 'حاضر':
        return 'حاضر';
      case 'checked_out':
      case 'departed':
      case 'انصرف':
        return 'انصرف';
      case 'absent':
      case 'غائب':
        return 'غائب';
      case 'unscheduled':
      case 'غير مجدول':
        return 'غير مجدول';
      default:
        return status;
    }
  }

  List<String> _getUniqueEmployeeNames() {
    final names = _allRecords.map((r) => _getName(r)).toSet().toList();
    names.sort();
    return names;
  }

  Future<void> _printReport() async {
    if (_printing) return;

    if (_loading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى الانتظار لحين اكتمال التحميل')),
      );
      return;
    }

    if (_filteredRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات للطباعة في هذا التقرير')),
      );
      return;
    }

    setState(() {
      _printing = true;
    });

    try {
      final regularFont = await PdfGoogleFonts.amiriRegular();
      final boldFont = await PdfGoogleFonts.amiriBold();

      final rows = _filteredRecords.map((record) {
        return <String>[
          _formatDelay(record['check_in']),
          _getStatus(record),
          _formatTime(record['check_out']),
          _formatTime(record['check_in']),
          _getJobTitle(record),
          _getName(record),
        ];
      }).toList();

      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          theme: pw.ThemeData.withFont(
            base: regularFont,
            bold: boldFont,
          ),
          build: (pw.Context pdfContext) => [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text(
                    'الإسعاف المركزي',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    _getReportTitle(),
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                  pw.SizedBox(height: 18),
                  pw.Text(
                    'إجمالي السجلات: ${_filteredRecords.length}',
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Table.fromTextArray(
                    headers: [
                      'مدة التأخير',
                      'الحالة',
                      'وقت الانصراف',
                      'وقت الحضور',
                      'المسمى الوظيفي',
                      'اسم الموظف',
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
                        bottom: pw.BorderSide(
                          color: PdfColor.fromInt(0xFFE3E6EA),
                        ),
                      ),
                    ),
                    cellAlignment: pw.Alignment.center,
                    headerAlignment: pw.Alignment.center,
                    cellPadding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    border: pw.TableBorder.all(
                      color: const PdfColor.fromInt(0xFFE3E6EA),
                      width: 0.6,
                    ),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.1),
                      1: const pw.FlexColumnWidth(1.1),
                      2: const pw.FlexColumnWidth(1.3),
                      3: const pw.FlexColumnWidth(1.3),
                      4: const pw.FlexColumnWidth(1.6),
                      5: const pw.FlexColumnWidth(2.2),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) => document.save(),
        name: 'report-${DateFormat('yyyyMMdd').format(_selectedDate)}',
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
    final employeeNames = _getUniqueEmployeeNames();

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نظام التقارير الشاملة'),
          centerTitle: true,
          backgroundColor: const Color(0xFFD32F2F),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: _printing ? null : _printReport,
              tooltip: 'طباعة التقرير الحالية',
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
        body: Column(
          children: [
            Container(
              height: 50,
              margin: const EdgeInsets.only(top: 12),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildReportChip(ReportType.daily, 'اليومي'),
                  _buildReportChip(ReportType.monthly, 'الشهري'),
                  _buildReportChip(ReportType.late, 'التأخيرات'),
                  _buildReportChip(ReportType.absent, 'الغياب'),
                  _buildReportChip(ReportType.employee, 'حضور موظف'),
                ],
              ),
            ),
            if (_selectedReportType == ReportType.employee)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: DropdownButtonFormField<String>(
                  value: _selectedEmployeeName,
                  decoration: const InputDecoration(
                    labelText: 'اختر الموظف',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: employeeNames
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedEmployeeName = val;
                    });
                    _applyReportFilter();
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        _selectedReportType == ReportType.monthly
                            ? DateFormat('yyyy/MM').format(_selectedDate)
                            : DateFormat('yyyy/MM/dd').format(_selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _loadReport,
                    tooltip: 'تحديث البيانات',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickOfficialStartTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        'بداية الدوام الرسمي: ${_officialStartTime.format(context)}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _getReportTitle(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildReportChip(ReportType type, String label) {
    final isSelected = _selectedReportType == type;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFFD32F2F),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedReportType = type;
            });
            _applyReportFilter();
          }
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
      );
    }

    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'حدث خطأ أثناء تحميل التقرير',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loadReport,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredRecords.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadReport,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Icon(Icons.event_busy, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Center(
              child: Text(
                'لا توجد سجلات تنطبق على هذا التقرير',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _filteredRecords.length,
        itemBuilder: (context, index) {
          final record = _filteredRecords[index];

          final name = _getName(record);
          final jobTitle = _getJobTitle(record);

          final checkIn = _formatTime(record['check_in']);
          final checkOut = _formatTime(record['check_out']);
          final delay = _formatDelay(record['check_in']);

          final status = _getStatus(record);

          final hasCheckIn = record['check_in'] != null;
          final hasCheckOut = record['check_out'] != null;

          final isPresent = status == 'حاضر';
          final isUnscheduled = status == 'غير مجدول';
          final isCompleted = hasCheckOut || status == 'انصرف';

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 25,
                            child: Icon(Icons.person),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  jobTitle,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isPresent
                                  ? Colors.green.withOpacity(0.12)
                                  : isUnscheduled || isCompleted
                                      ? Colors.grey.withOpacity(0.12)
                                      : Colors.red.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: isPresent
                                    ? Colors.green.shade700
                                    : isUnscheduled || isCompleted
                                        ? Colors.grey.shade700
                                        : Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _TimeBox(
                              icon: Icons.login,
                              title: 'وقت الحضور',
                              value: checkIn,
                              active: hasCheckIn,
                              iconColor: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TimeBox(
                              icon: Icons.logout,
                              title: 'وقت الانصراف',
                              value: checkOut,
                              active: hasCheckOut,
                              iconColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _TimeBox(
                        icon: Icons.timer_outlined,
                        title: 'مدة التأخير',
                        value: delay,
                        active: delay != '-' && delay != 'لا يوجد',
                        iconColor: Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool active;
  final Color iconColor;

  const _TimeBox({
    required this.icon,
    required this.title,
    required this.value,
    required this.active,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: active ? iconColor : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: active ? Colors.black87 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
