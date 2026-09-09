import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/supabase_service.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() =>
      _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  bool _loading = true;
  bool _printing = false;
  String? _error;

  List<Map<String, dynamic>> _records = [];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data =
          await SupabaseService.instance.fetchAttendanceReport(_selectedDate);

      if (!mounted) return;

      setState(() {
        _records = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'حدث خطأ أثناء تحميل التقرير: $e';
        _loading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );

    if (selected == null) return;

    setState(() {
      _selectedDate = selected;
    });

    await _loadReport();
  }

  String _formatTime(dynamic value) {
    if (value == null) return '-';
    final text = value.toString().trim();
    if (text.isEmpty) return '-';

    try {
      final dateTime = DateTime.parse(text).toLocal();
      return DateFormat('hh:mm a', 'ar').format(dateTime);
    } catch (_) {
      return text;
    }
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

  Future<void> _printReport() async {
    if (_printing) return;

    if (_loading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى الانتظار لحين اكتمال التحميل')),
      );
      return;
    }

    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات للطباعة')),
      );
      return;
    }

    setState(() {
      _printing = true;
    });

    try {
      final regularFont = await PdfGoogleFonts.amiriRegular();
      final boldFont = await PdfGoogleFonts.amiriBold();
      final reportDate = DateFormat('yyyy/MM/dd').format(_selectedDate);

      final rows = _records.map((record) {
        return <String>[
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
                    'تقرير الحضور واليومي — $reportDate',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                  pw.SizedBox(height: 18),
                  pw.Text(
                    'عدد السجلات: ${_records.length}',
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Table.fromTextArray(
                    headers: [
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
                      1: const pw.FlexColumnWidth(1.3),
                      2: const pw.FlexColumnWidth(1.3),
                      3: const pw.FlexColumnWidth(1.6),
                      4: const pw.FlexColumnWidth(2.2),
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
        name: 'attendance-report-$reportDate',
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
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تقرير الحضور واليومي'),
          centerTitle: true,
          backgroundColor: const Color(0xFFD32F2F),
          foregroundColor: Colors.white,
          actions: [
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
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        DateFormat('yyyy/MM/dd').format(_selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _loadReport,
                    tooltip: 'تحديث التقرير',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'تقرير يوم: ${DateFormat('yyyy/MM/dd').format(_selectedDate)}',
                  style: const TextStyle(
                    fontSize: 16,
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

    if (_records.isEmpty) {
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
                'لا توجد سجلات حضور لهذا اليوم',
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
        itemCount: _records.length,
        itemBuilder: (context, index) {
          final record = _records[index];

          final name = _getName(record);
          final jobTitle = _getJobTitle(record);

          final checkIn = _formatTime(record['check_in']);
          final checkOut = _formatTime(record['check_out']);

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
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
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
