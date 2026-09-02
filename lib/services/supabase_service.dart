import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee.dart';
import '../models/dashboard_stats.dart';
import '../models/attendance_settings.dart';

/// نقطة الاتصال الوحيدة بين التطبيق وقاعدة بيانات Supabase.
class SupabaseService {
  SupabaseService._internal();

  static final SupabaseService instance =
      SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // ================================================================
  // المصادقة
  // ================================================================

  /// تسجيل الدخول باسم المستخدم.
  Future<Employee> login({
    required String username,
    required String password,
  }) async {
    String? email;

    try {
      email = await _client.rpc(
        'email_for_username',
        params: {
          'p_username': username.trim(),
        },
      ) as String?;
    } on PostgrestException catch (e) {
      throw ApiException(e.message);
    }

    if (email == null || email.isEmpty) {
      throw ApiException(
        'اسم المستخدم أو كلمة المرور غير صحيحة',
      );
    }

    final AuthResponse res;

    try {
      res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw ApiException(
        _arabicAuthError(e.message),
      );
    }

    final user = res.user;

    if (user == null) {
      throw ApiException(
        'اسم المستخدم أو كلمة المرور غير صحيحة',
      );
    }

    return _fetchEmployeeProfile(user.id);
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  Future<bool> get isLoggedIn async {
    return _client.auth.currentSession != null;
  }

  /// الموظف الحالي عند فتح التطبيق.
  Future<Employee?> currentEmployee() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return null;
    }

    try {
      return await _fetchEmployeeProfile(user.id);
    } catch (_) {
      return null;
    }
  }

  Future<Employee> _fetchEmployeeProfile(
    String userId,
  ) async {
    final row = await _client
        .from('attendance_users')
        .select()
        .eq('id', userId)
        .single();

    final isCheckedIn =
        await _hasOpenAttendance(userId);

    return Employee.fromMap(
      row,
      isCheckedIn: isCheckedIn,
    );
  }

  Future<bool> _hasOpenAttendance(
    String employeeId,
  ) async {
    final rows = await _client
        .from('attendance_records')
        .select('id')
        .eq('user_id', employeeId)
        .isFilter('check_out', null)
        .limit(1);

    return (rows as List).isNotEmpty;
  }

  // ================================================================
  // الحضور والانصراف
  // ================================================================

  Future<void> checkIn({
    String? qrPayload,
    required double latitude,
    required double longitude,
  }) async {
    final userId =
        _client.auth.currentUser?.id;

    if (userId == null) {
      throw ApiException(
        'انتهت الجلسة، سجّل الدخول مجددًا',
      );
    }

    try {
      await _client.rpc(
        'attendance_check_in',
        params: {
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_qr_payload': qrPayload,
        },
      );
    } on PostgrestException catch (e) {
      throw ApiException(
        _arabicDatabaseError(e.message),
      );
    }
  }

  Future<void> checkOut({
    required double latitude,
    required double longitude,
  }) async {
    final userId =
        _client.auth.currentUser?.id;

    if (userId == null) {
      throw ApiException(
        'انتهت الجلسة، سجّل الدخول مجددًا',
      );
    }

    try {
      await _client.rpc(
        'attendance_check_out',
        params: {
          'p_latitude': latitude,
          'p_longitude': longitude,
        },
      );
    } on PostgrestException catch (e) {
      throw ApiException(
        _arabicDatabaseError(e.message),
      );
    }
  }

  // ================================================================
  // لوحة تحكم المدير
  // ================================================================

  Future<DashboardStats> fetchDashboardStats() async {
    try {
      final result = await _client.rpc(
        'attendance_dashboard_stats',
      );

      final row =
          (result as List).first
              as Map<String, dynamic>;

      return DashboardStats.fromJson(row);
    } on PostgrestException catch (e) {
      throw ApiException(e.message);
    }
  }

  // ================================================================
  // قائمة الموظفين
  // ================================================================

  Future<List<Employee>> fetchEmployees({
    String? search,
  }) async {
    try {
      // مهم:
      // لا نستخدم role هنا لأنه غير موجود في الجدول
      // حسب قاعدة البيانات الحالية.
      var query = _client
          .from('attendance_users')
          .select()
          .neq(
            'job_title',
            'مدير النظام',
          );

      if (search != null &&
          search.trim().isNotEmpty) {
        final text = search.trim();

        query = query.or(
          'full_name.ilike.%$text%,'
          'employee_number.ilike.%$text%',
        );
      }

      final rows =
          await query.order('full_name');

      // الموظفون الذين لديهم حضور مفتوح حاليًا.
      final openAttendance =
          await _client
              .from('attendance_records')
              .select('user_id')
              .isFilter(
                'check_out',
                null,
              );

      final presentIds =
          (openAttendance as List)
              .map(
                (r) =>
                    r['user_id'].toString(),
              )
              .toSet();

      return (rows as List)
          .map(
            (row) => Employee.fromMap(
              row,
              isCheckedIn:
                  presentIds.contains(
                row['id'].toString(),
              ),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw ApiException(e.message);
    }
  }

  // ================================================================
  // تقرير الحضور والانصراف
  // ================================================================

  /// يجلب جميع الموظفين الذين سجلوا حضورهم في تاريخ معين.
  ///
  /// البيانات التي يرجعها التقرير:
  /// - username
  /// - full_name
  /// - job_title
  /// - attendance_date
  /// - check_in
  /// - check_out
  /// - status
  Future<List<Map<String, dynamic>>>
      fetchAttendanceReport(
    DateTime date,
  ) async {
    try {
      final dateString =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      final result = await _client.rpc(
        'attendance_report',
        params: {
          'p_date': dateString,
        },
      );

      if (result == null) {
        return [];
      }

      return (result as List)
          .map(
            (row) =>
                Map<String, dynamic>.from(row),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw ApiException(e.message);
    }
  }

  // ================================================================
  // إنشاء موظف
  // ================================================================

  Future<void> createAttendanceUser({
    required String username,
    required String password,
    required String fullName,
    required String employeeNumber,
    required String jobTitle,
    required String role,
    String? department,
    String? phone,
  }) async {
    try {
      final response =
          await _client.functions.invoke(
        'create-attendance-user',
        body: {
          'username': username.trim(),
          'password': password,
          'full_name': fullName.trim(),
          'employee_number':
              employeeNumber.trim(),
          'job_title': jobTitle,
          'role': role,
          'department':
              department?.trim(),
          'phone': phone?.trim(),
        },
      );

      if (response.status < 200 ||
          response.status >= 300) {
        throw ApiException(
          'تعذّر إنشاء المستخدم',
        );
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw ApiException(
        'تعذّر إنشاء المستخدم: ${e.toString()}',
      );
    }
  }

  // ================================================================
  // إعدادات الحضور
  // ================================================================

  Future<AttendanceSettings>
      fetchAttendanceSettings() async {
    try {
      final row = await _client
          .from('attendance_settings')
          .select()
          .eq('id', 1)
          .single();

      return AttendanceSettings.fromMap(row);
    } on PostgrestException catch (e) {
      throw ApiException(e.message);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }

  // ================================================================
  // رسائل الأخطاء
  // ================================================================

  String _arabicAuthError(
    String message,
  ) {
    if (message
        .toLowerCase()
        .contains(
          'invalid login credentials',
        )) {
      return 'اسم المستخدم أو كلمة المرور غير صحيحة';
    }

    return message;
  }

  String _arabicDatabaseError(
    String message,
  ) {
    final lower =
        message.toLowerCase();

    if (lower.contains(
      'open attendance already exists',
    )) {
      return 'لديك تسجيل حضور مفتوح بالفعل';
    }

    if (lower.contains(
      'no open attendance',
    )) {
      return 'لا يوجد تسجيل حضور مفتوح لإغلاقه';
    }

    if (lower.contains(
      'not authenticated',
    )) {
      return 'انتهت الجلسة، سجّل الدخول مجددًا';
    }

    if (lower.contains(
      'not authorized',
    )) {
      return 'ليس لديك صلاحية لتنفيذ هذا الإجراء';
    }

    if (lower.contains(
      'invalid attendance qr code',
    )) {
      return 'باركود الحضور غير صحيح';
    }

    if (lower.contains(
      'outside attendance center range',
    )) {
      return 'أنت خارج نطاق الإسعاف المركزي';
    }

    if (lower.contains(
      'attendance user profile is missing',
    )) {
      return 'لا يوجد ملف حضور مرتبط بهذا المستخدم';
    }

    if (lower.contains(
      'attendance settings are incomplete',
    )) {
      return 'إعدادات المركز غير مكتملة في Supabase';
    }

    return message;
  }
}

// ================================================================
// ApiException
// ================================================================

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}
