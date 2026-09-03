import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/supabase_service.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() =>
      _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
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
      final date = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final data = await SupabaseService.instance.fetchAttendanceReport(
        date: date,
      );

      if (!mounted) return;

      setState(() {
        _records = List<Map<String, dynamic>>.from(data);
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
      locale: const Locale('ar'),
    );

    if (selected == null) return;

    setState(() {
      _selectedDate = selected;
    });

    await _loadReport();
  }

  String _formatTime(dynamic value) {
    if (value == null) return '-';

    try {
      final dateTime = DateTime.parse(value.toString()).toLocal();
      return DateFormat('hh:mm a', 'ar').format(dateTime);
    } catch (_) {
      return value.toString();
    }
  }

  String _getName(Map<String, dynamic> record) {
    final profile = record['profiles'];

    if (profile is Map<String, dynamic>) {
      return (profile['full_name'] ??
              profile['fullName'] ??
              profile['name'] ??
              record['full_name'] ??
              record['name'] ??
              'غير معروف')
          .toString();
    }

    return (record['full_name'] ??
            record['fullName'] ??
            record['name'] ??
            'غير معروف')
        .toString();
  }

  String _getRole(Map<String, dynamic> record) {
    final profile = record['profiles'];

    if (profile is Map<String, dynamic>) {
      return (profile['role'] ?? record['role'] ?? '-').toString();
    }

    return (record['role'] ?? '-').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تقرير الحضور والانصراف'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(Icons.calendar_month),
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
                    tooltip: 'تحديث',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 55,
                color: Colors.red,
              ),
              const SizedBox(height: 15),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: _loadReport,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (_records.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد سجلات حضور لهذا اليوم',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        itemCount: _records.length,
        itemBuilder: (context, index) {
          final record = _records[index];

          final name = _getName(record);
          final role = _getRole(record);

          final checkIn = _formatTime(record['check_in']);
          final checkOut = _formatTime(record['check_out']);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    child: const Icon(Icons.person),
                  ),
                  const SizedBox(width: 14),
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
                          role,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.login,
                              size: 18,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 5),
                            Text('الحضور: $checkIn'),
                            const SizedBox(width: 14),
                            const Icon(
                              Icons.logout,
                              size: 18,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 5),
                            Text('الانصراف: $checkOut'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
