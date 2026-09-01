import 'dart:async';
import 'package:flutter/material.dart';

import '../models/dashboard_stats.dart';
import '../models/employee.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';

import 'add_user_screen.dart';
import 'attendance_qr_screen.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _searchController = TextEditingController();

  DashboardStats _stats = DashboardStats.empty();
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
      final results = await Future.wait([
        SupabaseService.instance.fetchDashboardStats(),
        SupabaseService.instance.fetchEmployees(),
      ]);

      if (!mounted) return;

      setState(() {
        _stats = results[0] as DashboardStats;
        _employees = results[1] as List<Employee>;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'تعذّر تحميل بيانات اللوحة';
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
      final results = await SupabaseService.instance.fetchEmployees(
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'لوحة تحكم المدير 👨‍💼',
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _logout,
              icon: const Icon(
                Icons.logout,
                size: 20,
              ),
              tooltip: 'تسجيل الخروج',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(
                          bottom: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.danger,
                          ),
                        ),
                      ),

                    // إحصائيات الموظفين
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        StatCard(
                          emoji: '👨‍⚕️',
                          label: 'الأطباء',
                          value: _stats.doctorsCount,
                          color: AppColors.navy,
                          backgroundColor: AppColors.navy.withOpacity(0.08),
                        ),
                        StatCard(
                          emoji: '👩‍⚕️',
                          label: 'الممرضين',
                          value: _stats.nursesCount,
                          color: AppColors.navySoft,
                          backgroundColor: AppColors.navySoft.withOpacity(0.08),
                        ),
                        StatCard(
                          emoji: '✅',
                          label: 'الحاضرون',
                          value: _stats.presentCount,
                          color: AppColors.success,
                          backgroundColor: AppColors.successBg,
                        ),
                        StatCard(
                          emoji: '❌',
                          label: 'الغائبون',
                          value: _stats.absentCount,
                          color: AppColors.danger,
                          backgroundColor: AppColors.dangerBg,
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    Text(
                      'إدارة الموظفين',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),

                    const SizedBox(height: 12),

                    // أزرار الإدارة
                    Row(
                      children: [
                        // إضافة موظف
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final created = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => const AddUserScreen(),
                                ),
                              );

                              if (created == true && mounted) {
                                await _loadData();
                              }
                            },
                            icon: const Icon(
                              Icons.person_add_alt_1,
                              size: 18,
                            ),
                            label: const Text('إضافة موظف'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // باركود الحضور
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AttendanceQrScreen(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.qr_code_2,
                              size: 22,
                            ),
                            label: const Text(
                              'باركود الحضور',
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // البحث
                    TextField(
                      controller: _searchController,
                      onChanged: _scheduleEmployeeSearch,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        hintText: 'البحث عن موظف...',
                        prefixIcon: Icon(
                          Icons.search,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // قائمة الموظفين
                    ..._employees.map(
                      _buildEmployeeTile,
                    ),

                    if (_employees.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 32,
                        ),
                        child: Text(
                          'لا يوجد موظفون مطابقون للبحث',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmployeeTile(Employee employee) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.ambulanceRed.withOpacity(0.1),
            child: Text(
              employee.fullName.isNotEmpty ? employee.fullName[0] : '؟',
              style: const TextStyle(
                color: AppColors.ambulanceRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  employee.roleLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: employee.isCheckedIn
                  ? AppColors.successBg
                  : AppColors.dangerBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              employee.isCheckedIn ? 'حاضر' : 'غائب',
              style: TextStyle(
                fontSize: 12,
import 'dart:async';
import 'package:flutter/material.dart';

import '../models/dashboard_stats.dart';
import '../models/employee.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';

import 'add_user_screen.dart';
import 'attendance_screen.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _searchController = TextEditingController();

  DashboardStats _stats = DashboardStats.empty();
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
      final results = await Future.wait([
        SupabaseService.instance.fetchDashboardStats(),
        SupabaseService.instance.fetchEmployees(),
      ]);

      if (!mounted) return;

      setState(() {
        _stats = results[0] as DashboardStats;
        _employees = results[1] as List<Employee>;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'تعذّر تحميل بيانات اللوحة';
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
      final results = await SupabaseService.instance.fetchEmployees(
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'لوحة تحكم المدير 👨‍💼',
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _logout,
              icon: const Icon(
                Icons.logout,
                size: 20,
              ),
              tooltip: 'تسجيل الخروج',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(
                          bottom: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.danger,
                          ),
                        ),
                      ),

                    // إحصائيات الموظفين
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        StatCard(
                          emoji: '👨‍⚕️',
                          label: 'الأطباء',
                          value: _stats.doctorsCount,
                          color: AppColors.navy,
                          backgroundColor:
                              AppColors.navy.withOpacity(0.08),
                        ),
                        StatCard(
                          emoji: '👩‍⚕️',
                          label: 'الممرضين',
                          value: _stats.nursesCount,
                          color: AppColors.navySoft,
                          backgroundColor:
                              AppColors.navySoft.withOpacity(0.08),
                        ),
                        StatCard(
                          emoji: '✅',
                          label: 'الحاضرون',
                          value: _stats.presentCount,
                          color: AppColors.success,
                          backgroundColor: AppColors.successBg,
                        ),
                        StatCard(
                          emoji: '❌',
                          label: 'الغائبون',
                          value: _stats.absentCount,
                          color: AppColors.danger,
                          backgroundColor: AppColors.dangerBg,
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    Text(
                      'إدارة الموظفين',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),

                    const SizedBox(height: 12),

                    // أزرار الإدارة
                    Row(
                      children: [
                        // إضافة موظف
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final created =
                                  await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AddUserScreen(),
                                ),
                              );

                              if (created == true && mounted) {
                                await _loadData();
                              }
                            },
                            icon: const Icon(
                              Icons.person_add_alt_1,
                              size: 18,
                            ),
                            label: const Text('إضافة موظف'),
                            style: OutlinedButton.styleFrom(
                              minimumSize:
                                  const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // باركود الحضور
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const QrScanScreen(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.qr_code_2,
                              size: 22,
                            ),
                            label: const Text(
                              'باركود الحضور',
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize:
                                  const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // البحث
                    TextField(
                      controller: _searchController,
                      onChanged: _scheduleEmployeeSearch,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        hintText: 'البحث عن موظف...',
                        prefixIcon: Icon(
                          Icons.search,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // قائمة الموظفين
                    ..._employees.map(
                      _buildEmployeeTile,
                    ),

                    if (_employees.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 32,
                        ),
                        child: Text(
                          'لا يوجد موظفون مطابقون للبحث',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmployeeTile(Employee employee) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                AppColors.ambulanceRed.withOpacity(0.1),
            child: Text(
              employee.fullName.isNotEmpty
                  ? employee.fullName[0]
                  : '؟',
              style: const TextStyle(
                color: AppColors.ambulanceRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  employee.roleLabel,
                  style:
                      Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: employee.isCheckedIn
                  ? AppColors.successBg
                  : AppColors.dangerBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              employee.isCheckedIn ? 'حاضر' : 'غائب',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: employee.isCheckedIn
                    ? AppColors.success
                    : AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
