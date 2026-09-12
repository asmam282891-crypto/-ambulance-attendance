import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/employee.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';

/// شاشة تقرير شهري لموظف واحد بعينه: عدد أيام الحضور والغياب
/// خلال فترة زمنية يختارها المدير.
class MonthlyAttendanceReportScreen extends StatefulWidget {
  const MonthlyAttendanceReportScreen({super.key});

  @override
  State<MonthlyAttendanceReportScreen> createState() =>
      _MonthlyAttendanceReportScreenState();
}

class _MonthlyAttendanceReportScreenState
    extends State<MonthlyAttendanceReportScreen> {
  bool _loadingEmployees = true;
  bool _loadingSummary = false;
  String? _error;

  List<Employee> _employees = [];
  Employee? _selectedEmployee;

  late DateTime _startDate;
  late DateTime _endDate;

  Map<String, dynamic>? _summary;

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
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: child!,
        );
      },
    );

    if (selected == null) return;

    setState(() {
      _startDate = selected;
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
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
      _endDate = selected;
    });
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
      _loadingSummary = true;
      _error = null;
      _summary = null;
    });

    try {
      final result = await SupabaseService.instance.fetchEmployeeMonthlySummary(
        userId: employee.id,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (!mounted) return;

      setState(() {
        _summary = result;
        _loadingSummary = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'حدث خطأ أثناء تحميل التقرير: $e';
        _loadingSummary = false;
      });
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
                    constraints: const BoxConstraints(maxWidth: 620),
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
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _loadingSummary ? null : _viewReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.ambulanceRed,
                              foregroundColor: Colors.white,
                            ),
                            icon: _loadingSummary
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
                        if (_summary != null) _buildSummary(),
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
                  child: Text(
                    '${employee.fullName} — ${employee.roleLabel}',
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedEmployee = value;
              _summary = null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final summary = _summary!;
    final fullName = (summary['full_name'] ?? '').toString();
    final jobTitle = (summary['job_title'] ?? '').toString();
    final presentDays = (summary['present_days'] ?? 0) as num;
    final absentDays = (summary['absent_days'] ?? 0) as num;
    final workDaysCount = (summary['work_days_count'] ?? 0) as num;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                        fullName,
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
                value: presentDays.toInt(),
                color: AppColors.success,
                backgroundColor: AppColors.successBg,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                emoji: '❌',
                label: 'أيام الغياب',
                value: absentDays.toInt(),
                color: AppColors.danger,
                backgroundColor: AppColors.dangerBg,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StatCard(
          emoji: '📅',
          label: 'إجمالي أيام الدوام المفروضة',
          value: workDaysCount.toInt(),
          color: AppColors.navy,
          backgroundColor: AppColors.background,
        ),
      ],
    );
  }
}
