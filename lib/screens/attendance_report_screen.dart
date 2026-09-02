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
  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _records = [];

  bool _loading = true;
  String? _error;

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
      final records =
          await SupabaseService.instance.fetchAttendanceReport(
        _selectedDate,
      );

      if (!mounted) return;

      setState(() {
        _records = records;
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
    });

    await _loadReport();
  }

  String _formatTime(dynamic value) {
    if (value == null) return '—';

    final dateTime = DateTime.tryParse(
      value.toString(),
    );

    if (dateTime == null) return '—';

    return DateFormat(
      'hh:mm a',
    ).format(dateTime.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat(
      'dd/MM/yyyy',
    ).format(_selectedDate);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'سجل الحضور والانصراف',
          ),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: _loadReport,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month,
                        color: Color(0xFFC62828),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'تاريخ التقرير',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateText,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 45,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadReport,
                        child: const Text(
                          'إعادة المحاولة',
                        ),
                      ),
                    ],
                  ),
                )
              else if (_records.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(45),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 60,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 15),
                      Text(
                        'لا يوجد موظفون سجلوا حضورهم في هذا اليوم',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Row(
                  children: [
                    const Icon(
                      Icons.people,
                      color: Color(0xFFC62828),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'المسجلون: ${_records.length}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                ..._records.map(
                  _buildAttendanceCard,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(
    Map<String, dynamic> record,
  ) {
    final username =
        record['username']?.toString().trim() ?? '';

    final fullName =
        record['full_name']?.toString().trim() ?? '';

    final jobTitle =
        record['job_title']?.toString().trim() ?? '';

    final status =
        record['status']?.toString() ?? '';

    final checkIn =
        _formatTime(record['check_in']);

    final checkOut =
        _formatTime(record['check_out']);

    final hasCheckedOut =
        record['check_out'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.red.shade50,
                child: Text(
                  username.isNotEmpty
                      ? username[0].toUpperCase()
                      : 'م',
                  style: const TextStyle(
                    color: Color(0xFFC62828),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty
                          ? 'بدون اسم'
                          : fullName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '@$username',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      jobTitle.isEmpty
                          ? 'موظف'
                          : jobTitle,
                      style: const TextStyle(
                        color: Color(0xFFC62828),
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
                  color: hasCheckedOut
                      ? Colors.grey.shade100
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.isEmpty
                      ? (hasCheckedOut
                          ? 'انصرف'
                          : 'حاضر')
                      : status,
                  style: TextStyle(
                    color: hasCheckedOut
                        ? Colors.grey.shade700
                        : Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 25),

          Row(
            children: [
              Expanded(
                child: _timeBox(
                  icon: Icons.login,
                  title: 'وقت الحضور',
                  value: checkIn,
                  color: Colors.green,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _timeBox(
                  icon: Icons.logout,
                  title: 'وقت الانصراف',
                  value: checkOut,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeBox({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 22,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
