import 'package:supabase_flutter/supabase_flutter.dart';

// ================================================================
// AppLocaleController (لإدارة الرسائل والنصوص المترجمة)
// ================================================================
class AppLocaleController {
  AppLocaleController._();
  static final AppLocaleController instance = AppLocaleController._();

  String text(String key) {
    switch (key) {
      case 'sessionExpired':
        return 'انتهت جلسة التسجيل، يرجى إعادة الدخول';
      case 'createUserError':
        return 'حدث خطأ أثناء إنشاء حساب الموظف';
      case 'authInvalid':
        return 'بيانات الدخول غير صحيحة';
      case 'attendanceOpen':
        return 'لديك تسجيل حضور مفتوح بالفعل';
      case 'noOpenAttendance':
        return 'لا يوجد تسجيل حضور مفتوح لتسجيل الانصراف';
      case 'notAuthorized':
        return 'ليس لديك صلاحية لإجراء هذه العملية';
      case 'invalidQr':
        return 'رمز الـ QR الخاص بالحضور غير صالح';
      case 'outsideAttendanceRange':
        return 'أنت خارج نطاق موقع الحضور المسموح به';
      case 'missingProfile':
        return 'ملف الموظف غير مكتمل أو غير موجود';
      case 'incompleteSettings':
        return 'إعدادات الحضور غير مكتملة في النظام';
      default:
        return key;
    }
  }
}

// ================================================================
// Models
// ================================================================
class DashboardStats {
  final int totalEmployees;
  final int presentCount;
  final int absentCount;
  final int lateCount;

  DashboardStats({
    required this.totalEmployees,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalEmployees: json['total_employees'] ?? 0,
      presentCount: json['present_count'] ?? 0,
      absentCount: json['absent_count'] ?? 0,
      lateCount: json['late_count'] ?? 0,
    );
  }
}

class Employee {
  final String id;
  final String fullName;
  final String employeeNumber;
  final String jobTitle;
  final List<int> workDays;
  final bool isCheckedIn;
  final String? checkInTime;
  final String? checkOutTime;

  Employee({
    required this.id,
    required this.fullName,
    required this.employeeNumber,
    required this.jobTitle,
    required this.workDays,
    this.isCheckedIn = false,
    this.checkInTime,
    this.checkOutTime,
  });

  factory Employee.fromMap(
    Map<String, dynamic> map, {
    bool isCheckedIn = false,
    String? checkInTime,
    String? checkOutTime,
  }) {
    final rawWorkDays = map['work_days'];
    List<int> parsedWorkDays = [];
    if (rawWorkDays is List) {
      parsedWorkDays = rawWorkDays.map((e) => int.parse(e.toString())).toList();
    }

    return Employee(
      id: map['id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      employeeNumber: map['employee_number']?.toString() ?? '',
      jobTitle: map['job_title']?.toString() ?? '',
      workDays: parsedWorkDays,
      isCheckedIn: isCheckedIn,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
    );
  }
}

class AttendanceSettings {
  final double centerLatitude;
  final double centerLongitude;
  final double allowedRadiusMeters;
  final String qrSecret;

  AttendanceSettings({
    required this.centerLatitude,
    required this.centerLongitude,
    required this.allowedRadiusMeters,
    required this.qrSecret,
  });

  factory AttendanceSettings.fromMap(Map<String, dynamic> map) {
    return AttendanceSettings(
      centerLatitude: (map['center_latitude'] as num?)?.toDouble() ?? 0.0,
      centerLongitude: (map['center_longitude'] as num?)?.toDouble() ?? 0.0,
      allowedRadiusMeters: (map['allowed_radius_meters'] as num?)?.toDouble() ?? 0.0,
      qrSecret: map['qr_secret']?.toString() ?? '',
    );
  }
}

// ================================================================
// SupabaseService Class Definition
// ================================================================
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  final SupabaseClient _client = Supabase.instance.client;

  String? _formatAttendanceTime(dynamic timeValue) {
    if (timeValue == null) return null;
    return timeValue.toString();
  }

  // ================================================================
  // الحضور والانصراف
  // ================================================================

  Future<void> checkIn({
    String? qrPayload,
    required double latitude,
    required double longitude,
  }) async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw ApiException(
        AppLocaleController.instance.text('sessionExpired'),
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
    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw ApiException(
        AppLocaleController.instance.text('sessionExpired'),
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

      final row = (result as List).first as Map<String, dynamic>;

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
      var query = _client
          .from('attendance_users')
          .select()
          .neq(
            'job_title',
            'مدير النظام',
          );

      if (search != null && search.trim().isNotEmpty) {
        final text = search.trim();

        query = query.or(
          'full_name.ilike.%$text%,'
          'employee_number.ilike.%$text%',
        );
      }

      final rows = await query.order('full_name');

      final now = DateTime.now();
      final dateString =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final attendanceRows = await _client
          .from('attendance_records')
          .select('user_id, check_in, check_out')
          .eq('attendance_date', dateString)
          .order('check_in', ascending: false);

      final latestAttendance = <String, Map<String, dynamic>>{};
      for (final record in (attendanceRows as List)) {
        final userId = record['user_id']?.toString();
        if (userId != null && !latestAttendance.containsKey(userId)) {
          latestAttendance[userId] = Map<String, dynamic>.from(record);
        }
      }

      final presentIds = <String>{};
      final checkInTimes = <String, String>{};
      final checkOutTimes = <String, String>{};
      for (final entry in latestAttendance.entries) {
        final record = entry.value;
        final checkIn = _formatAttendanceTime(record['check_in']);
        final checkOut = _formatAttendanceTime(record['check_out']);
        if (checkIn != null) checkInTimes[entry.key] = checkIn;
        if (checkOut != null) {
          checkOutTimes[entry.key] = checkOut;
        } else {
          presentIds.add(entry.key);
        }
      }

      return (rows as List)
          .map(
            (row) => Employee.fromMap(
              row,
              isCheckedIn: presentIds.contains(row['id'].toString()),
              checkInTime: checkInTimes[row['id'].toString()],
              checkOutTime: checkOutTimes[row['id'].toString()],
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw ApiException(e.message);
    }
  }

  Future<void> updateEmployeeWorkDays({
    required String employeeId,
    required List<int> workDays,
  }) async {
    try {
      await _client
          .from('attendance_users')
          .update({'work_days': workDays})
          .eq('id', employeeId);
    } on PostgrestException catch (e) {
      throw ApiException(e.message);
    }
  }

  // ================================================================
  // تقرير الحضور والانصراف
  // ================================================================

  Future<List<Map<String, dynamic>>> fetchAttendanceReport(
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
            (row) => Map<String, dynamic>.from(row),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw ApiException(e.message);
    }
  }

  // ================================================================
  // تقرير شهري لموظف واحد
  // ================================================================

  Future<Map<String, dynamic>?> fetchEmployeeMonthlySummary({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      String formatDate(DateTime date) =>
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      final result = await _client.rpc(
        'attendance_user_monthly_summary',
        params: {
          'p_user_id': userId,
          'p_start_date': formatDate(startDate),
          'p_end_date': formatDate(endDate),
        },
      );

      if (result == null) return null;

      final rows = result as List;
      if (rows.isEmpty) return null;

      return Map<String, dynamic>.from(rows.first);
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
      final response = await _client.functions.invoke(
        'create-attendance-user',
        body: {
          'username': username.trim(),
          'password': password,
          'full_name': fullName.trim(),
          'employee_number': employeeNumber.trim(),
          'job_title': jobTitle,
          'role': role,
          'department': department?.trim(),
          'phone': phone?.trim(),
        },
      );

      if (response.status < 200 || response.status >= 300) {
        throw ApiException(
          AppLocaleController.instance.text('createUserError'),
        );
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw ApiException(
        '${AppLocaleController.instance.text('createUserError')}: ${e.toString()}',
      );
    }
  }

  // ================================================================
  // إعدادات الحضور
  // ================================================================

  Future<AttendanceSettings> fetchAttendanceSettings() async {
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

  String _arabicAuthError(String message) {
    if (message.toLowerCase().contains('invalid login credentials')) {
      return AppLocaleController.instance.text('authInvalid');
    }

    return message;
  }

  String _arabicDatabaseError(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('open attendance already exists')) {
      return AppLocaleController.instance.text('attendanceOpen');
    }

    if (lower.contains('no open attendance')) {
      return AppLocaleController.instance.text('noOpenAttendance');
    }

    if (lower.contains('not authenticated')) {
      return AppLocaleController.instance.text('sessionExpired');
    }

    if (lower.contains('not authorized')) {
      return AppLocaleController.instance.text('notAuthorized');
    }

    if (lower.contains('invalid attendance qr code')) {
      return AppLocaleController.instance.text('invalidQr');
    }

    if (lower.contains('outside attendance center range')) {
      return AppLocaleController.instance.text('outsideAttendanceRange');
    }

    if (lower.contains('attendance user profile is missing')) {
      return AppLocaleController.instance.text('missingProfile');
    }

    if (lower.contains('attendance settings are incomplete')) {
      return AppLocaleController.instance.text('incompleteSettings');
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
