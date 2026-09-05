import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/supabase_service.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() =>
      _AttendanceReportScreenState();
}

class _AttendanceReportScreenState
    extends State<AttendanceReportScreen> {
  bool _loading = true;
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
      final data = await SupabaseService.instance
          .fetchAttendanceReport(_selectedDate);

      if (!mounted) return;

      setState(() {
        _records = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
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
          textDirection: ui.TextDirection.rtl,
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

      return DateFormat(
        'hh:mm a',
        'ar',
      ).format(dateTime);
    } catch (_) {
      return text;
    }
  }

  String _getName(Map<String, dynamic> record) {
    return (
      record['full_name'] ??
      record['fullName'] ??
      record['name'] ??
      record['username'] ??
      'غير معروف'
    ).toString();
  }

  String _getJobTitle(Map<String, dynamic> record) {
    return (
      record['job_title'] ??
      record['jobTitle'] ??
      record['role'] ??
      '-'
    ).toString();
  }

  String _getStatus(Map<String, dynamic> record) {
    final status = record['status']?.toString().trim();

    if (status == null || status.isEmpty) {
      if (record['check_in'] != null &&
          record['check_out'] == null) {
        return 'حاضر';
      }

      if (record['check_in'] != null &&
          record['check_out'] != null) {
        return 'انصرف';
      }

      return '-';
    }

    return status;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'تقرير الحضور والانصراف',
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(
                        Icons.calendar_month,
                      ),
                      label: Text(
                        DateFormat(
                          'yyyy/MM/dd',
                        ).format(_selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _loadReport,
                    tooltip: 'تحديث التقرير',
                    icon: const Icon(
                      Icons.refresh,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'تقرير يوم ${DateFormat('yyyy/MM/dd').format(_selectedDate)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red,
              ),
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
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loadReport,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'إعادة المحاولة',
                ),
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
          physics:
              const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Icon(
              Icons.event_busy,
              size: 60,
              color: Colors.grey,
            ),
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
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24,
        ),
        itemCount: _records.length,
        itemBuilder: (
          context,
          index,
        ) {
          final record = _records[index];

          final name = _getName(record);
          final jobTitle = _getJobTitle(record);

          final checkIn =
              _formatTime(record['check_in']);

          final checkOut =
              _formatTime(record['check_out']);

          final status =
              _getStatus(record);
           final isPresent = status == 'حاضر';
           final isUnscheduled = status == 'غير مجدول';
           final isCompleted = hasCheckOut || status == 'انصرف';

          final hasCheckIn =
              record['check_in'] != null;

          final hasCheckOut =
              record['check_out'] != null;

           return Center(
             child: ConstrainedBox(
               constraints: const BoxConstraints(
                 maxWidth: 920,
               ),
               child: Card(
                 margin: const EdgeInsets.only(
                   bottom: 14,
                 ),
                 child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 25,
                        child: Icon(
                          Icons.person,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style:
                                  const TextStyle(
                                fontSize: 17,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              jobTitle,
                              style: TextStyle(
                                color: Colors
                                    .grey
                                    .shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                           color: isPresent
                               ? Colors.green.withOpacity(0.12)
                               : isUnscheduled || isCompleted
                                   ? Colors.grey.withOpacity(0.12)
                                   : Colors.red.withOpacity(0.12),
                          borderRadius:
                              BorderRadius
                                  .circular(20),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                             color: isPresent
                                 ? Colors.green.shade700
                                 : isUnscheduled || isCompleted
                                     ? Colors.grey.shade700
                                     : Colors.red.shade700,
                            fontWeight:
                                FontWeight.bold,
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
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: active
                ? iconColor
                : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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
                    color: active
                        ? Colors.black87
                        : Colors.grey,
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
