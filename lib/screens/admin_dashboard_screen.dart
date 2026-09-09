import 'dart:async';
import 'package:flutter/material.dart';

import '../models/employee.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

import 'add_user_screen.dart';
import 'attendance_report_screen.dart';
import 'login_screen.dart';
import 'qr_scan_screen.dart';
import 'attendance_qr_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState
    extends State<AdminDashboardScreen> {
  final _searchController = TextEditingController();

  List<Employee> _employees = [];

  bool _isLoading = true;
  String? _errorMessage;

  Timer? _searchDebounce;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final employees =
          await SupabaseService.instance.fetchEmployees();

      if (!mounted) return;

      setState(() {
        _employees = employees;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = context.tr('reportLoadError');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchEmployees(String query) async {
    final requestId = ++_searchRequestId;

    try {
      final results =
          await SupabaseService.instance.fetchEmployees(
        search: query,
      );

      if (!mounted || requestId != _searchRequestId) {
        return;
      }

      setState(() {
        _employees = results;
      });
    } catch (_) {
      // نتجاهل أخطاء البحث المؤقتة
    }
  }

  void _scheduleEmployeeSearch(String query) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchEmployees(query),
    );
  }

  Future<void> _logout() async {
    await SupabaseService.instance.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // عرض باركود الموظفين المشترك للمدير
  void _openAttendanceQr() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AttendanceQrScreen(),
      ),
    );
  }

  // فتح سجل الحضور والانصراف
  void _openAttendanceReport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const AttendanceReportScreen(),
      ),
    );
  }

  Future<void> _editEmployeeSchedule(Employee employee) async {
    final selected = employee.workDays.toSet();
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) {
        var draft = {...selected};
        final days = <MapEntry<int, String>>[
          MapEntry(1, context.tr('monday')),
          MapEntry(2, context.tr('tuesday')),
          MapEntry(3, context.tr('wednesday')),
          MapEntry(4, context.tr('thursday')),
          MapEntry(5, context.tr('friday')),
          MapEntry(6, context.tr('saturday')),
          MapEntry(7, context.tr('sunday')),
        ];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                context.tr(
                  'workDaysFor',
                  {'name': employee.fullName},
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: days
                      .map(
                        (day) => FilterChip(
                          label: Text(day.value),
                          selected: draft.contains(day.key),
                          onSelected: (checked) {
                            setDialogState(() {
                              if (checked) {
                                draft.add(day.key);
                              } else {
                                draft.remove(day.key);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.tr('cancel')),
                ),
                FilledButton(
                  onPressed: draft.isEmpty
                      ? null
                      : () => Navigator.pop(dialogContext, draft),
                   child: Text(context.tr('saveDays')),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || result.isEmpty) return;

    try {
      final days = result.toList()..sort();
      await SupabaseService.instance.updateEmployeeWorkDays(
        employeeId: employee.id,
        workDays: days,
      );
      if (!mounted) return;
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('saveDaysSuccess'))),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocaleController.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('adminDashboard')),
          centerTitle: true,
          actions: [
            const LanguageToggleButton(),
            IconButton(
              onPressed: _logout,
              icon: const Icon(
                Icons.logout,
                size: 20,
              ),
               tooltip: context.tr('logout'),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  final horizontalPadding = isWide ? 32.0 : 20.0;

                  return RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    20,
                    horizontalPadding,
                    28,
                  ),
                  children: [
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(12),
                        margin:
                            const EdgeInsets.only(
                          bottom: 16,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              AppColors.dangerBg,
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          textAlign:
                              TextAlign.center,
                          style:
                              const TextStyle(
                            color:
                                AppColors.danger,
                          ),
                        ),
                      ),

                    // =========================
                    const SizedBox(height: 8),

                    Text(
                      context.tr('employeeManagement'),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge,
                    ),

                    const SizedBox(height: 12),

                    // =========================
                    // أزرار الإدارة
                    // =========================
                    Row(
                      children: [
                        Expanded(
                          child:
                              OutlinedButton.icon(
                            onPressed: () async {
                              final created =
                                  await Navigator.of(
                                context,
                              ).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AddUserScreen(),
                                ),
                              );

                              if (created == true &&
                                  mounted) {
                                await _loadData();
                              }
                            },
                            icon: const Icon(
                              Icons
                                  .person_add_alt_1,
                              size: 18,
                            ),
                              label: Text(context.tr('addEmployee')),
                            style:
                                OutlinedButton.styleFrom(
                              minimumSize:
                                  const Size
                                      .fromHeight(
                                46,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  12,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child:
                              OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const QrScanScreen(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons
                                  .qr_code_scanner,
                              size: 22,
                            ),
                             label: Text(context.tr('scanBarcode')),
                            style:
                                OutlinedButton.styleFrom(
                              minimumSize:
                                  const Size
                                      .fromHeight(
                                46,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // =========================
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openAttendanceQr,
                        icon: const Icon(Icons.qr_code_2, size: 22),
                         label: Text(context.tr('employeeQrPrint')),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          foregroundColor: AppColors.navy,
                          side: const BorderSide(color: AppColors.navy),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    // سجل الحضور والانصراف
                    // =========================
                    SizedBox(
                      width: double.infinity,
                      child:
                          OutlinedButton.icon(
                        onPressed:
                            _openAttendanceReport,
                        icon: const Icon(
                          Icons
                              .assignment_outlined,
                          size: 23,
                        ),
                         label: Text(
                           context.tr('attendanceReport'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        style:
                            OutlinedButton.styleFrom(
                          minimumSize:
                              const Size
                                  .fromHeight(
                            50,
                          ),
                          foregroundColor:
                              AppColors
                                  .ambulanceRed,
                          side:
                              const BorderSide(
                            color: AppColors
                                .ambulanceRed,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // =========================
                    // البحث
                    // =========================
                    TextField(
                      controller:
                          _searchController,
                      onChanged:
                          _scheduleEmployeeSearch,
                      textAlign:
                          TextAlign.right,
                       decoration:
                           InputDecoration(
                         hintText: context.tr('searchEmployee'),
                        prefixIcon:
                            Icon(
                          Icons.search,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // =========================
                    // قائمة الموظفين المرتبة حسب الحالة
                    // =========================
                    if (_presentEmployees.isNotEmpty) ...[
                      _buildEmployeeSectionHeader(
                         title: context.tr('presentNow'),
                        count: _presentEmployees.length,
                        color: AppColors.success,
                      ),
                      ..._presentEmployees.map(_buildEmployeeTile),
                    ],

                    if (_absentEmployees.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildEmployeeSectionHeader(
                         title: context.tr('absent'),
                        count: _absentEmployees.length,
                        color: AppColors.danger,
                      ),
                      ..._absentEmployees.map(_buildEmployeeTile),
                    ],

                    if (_employees.isEmpty)
                      Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 32,
                        ),
                        child: Text(
                           context.tr('noEmployees'),
                          textAlign:
                              TextAlign.center,
                          style:
                              Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                        ),
                      ),
                  ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  List<Employee> get _presentEmployees =>
      _employees.where((employee) => employee.isCheckedIn).toList();

  List<Employee> get _absentEmployees =>
      _employees.where((employee) => !employee.isCheckedIn).toList();

  Widget _buildEmployeeSectionHeader({
    required String title,
    required int count,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // بطاقة الموظف
  // =========================
  Widget _buildEmployeeTile(
    Employee employee,
  ) {
    final hasCheckedOut = employee.checkOutTime != null;

    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration:
          BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.circular(12),
        border:
            Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                AppColors.ambulanceRed
                    .withOpacity(0.1),
            child: Text(
              employee.fullName.isNotEmpty
                  ? employee.fullName[0]
                  : '؟',
              style:
                  const TextStyle(
                color:
                    AppColors.ambulanceRed,
                fontWeight:
                    FontWeight.bold,
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
                  employee.title,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                Text(
                  employee.roleLabel,
                  style:
                      Theme.of(context)
                          .textTheme
                          .bodySmall,
                ),

                if (employee.checkInTime != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 2,
                    ),
                    child: Text(
                       '⏰ ${context.tr('checkInLabel')}: ${employee.checkInTime}',
                      style:
                          const TextStyle(
                        fontSize: 11,
                        color:
                            AppColors.success,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ),

                if (employee.checkOutTime != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 2,
                    ),
                    child: Text(
                       '🚪 ${context.tr('checkOutLabel')}: ${employee.checkOutTime}',
                      style:
                          const TextStyle(
                        fontSize: 11,
                        color:
                            AppColors.textSecondary,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration:
                BoxDecoration(
              color: employee.isCheckedIn
                  ? AppColors.successBg
                  : hasCheckedOut
                      ? Colors.grey.shade200
                      : AppColors.dangerBg,
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: Text(
              employee.isCheckedIn
                   ? context.tr('present')
                  : hasCheckedOut
                       ? context.tr('departed')
                       : context.tr('absentStatus'),
              style:
                  TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w600,
                color: employee.isCheckedIn
                    ? AppColors.success
                    : hasCheckedOut
                        ? AppColors.textSecondary
                        : AppColors.danger,
              ),
            ),
          ),

           IconButton(
             onPressed: () => _editEmployeeSchedule(employee),
             icon: const Icon(Icons.calendar_month_outlined),
              tooltip: context.tr('editWorkDays'),
             color: AppColors.navy,
           ),
        ],
      ),
    );
  }
}
