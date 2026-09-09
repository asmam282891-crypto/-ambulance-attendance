import 'package:flutter/material.dart';

/// Lightweight in-app localization so the app can switch languages instantly
/// without requiring generated ARB files or a restart.
class AppLocaleController extends ChangeNotifier {
  AppLocaleController._();

  static final instance = AppLocaleController._();

  Locale _locale = const Locale('ar');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';
  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  void toggle() {
    _locale = isArabic ? const Locale('en') : const Locale('ar');
    notifyListeners();
  }

  String text(
    String key, [
    Map<String, String> values = const {},
  ]) {
    final language = isArabic ? 'ar' : 'en';
    var result = _translations[language]?[key] ??
        _translations['ar']?[key] ??
        key;

    for (final entry in values.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }

    return result;
  }
}

extension AppLocalization on BuildContext {
  String tr(
    String key, [
    Map<String, String> values = const {},
  ]) {
    return AppLocaleController.instance.text(key, values);
  }
}

class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocaleController.instance.isArabic;

    return TextButton.icon(
      onPressed: AppLocaleController.instance.toggle,
      icon: const Icon(Icons.language, size: 20),
      label: Text(isArabic ? 'EN' : 'ع'),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }
}

const Map<String, Map<String, String>> _translations = {
  'ar': {
    'appTitle': 'نظام حضور الإسعاف المركزي',
    'loginSubtitle': 'سجّل دخولك لمتابعة الحضور والانصراف',
    'username': 'اسم المستخدم',
    'password': 'كلمة المرور',
    'login': 'تسجيل الدخول',
    'invalidFields': 'يرجى إدخال اسم المستخدم وكلمة المرور',
    'networkError': 'حدث خطأ، تحقق من الاتصال بالإنترنت',
    'logout': 'تسجيل الخروج',
    'centralAmbulance': 'الإسعاف المركزي',
    'adminDashboard': 'لوحة تحكم المدير 👨‍💼',
    'employeeManagement': 'إدارة الموظفين',
    'addEmployee': 'إضافة موظف',
    'scanBarcode': 'مسح الباركود',
    'employeeQrPrint': 'عرض باركود الموظفين للطباعة',
    'attendanceReport': 'سجل الحضور والانصراف',
    'searchEmployee': 'البحث عن موظف...',
    'presentNow': 'الحاضرون الآن',
    'absent': 'غير الحاضرين',
    'noEmployees': 'لا يوجد موظفون مطابقون للبحث',
    'checkInLabel': 'الحضور',
    'checkOutLabel': 'الانصراف',
    'present': 'حاضر',
    'departed': 'انصرف',
    'absentStatus': 'غائب',
    'editWorkDays': 'تعديل أيام العمل',
    'workDaysFor': 'أيام عمل {{name}}',
    'cancel': 'إلغاء',
    'saveDays': 'حفظ الأيام',
    'saveDaysSuccess': 'تم حفظ أيام العمل ✅',
    'monday': 'الإثنين',
    'tuesday': 'الثلاثاء',
    'wednesday': 'الأربعاء',
    'thursday': 'الخميس',
    'friday': 'الجمعة',
    'saturday': 'السبت',
    'sunday': 'الأحد',
    'reportTitle': 'تقرير الحضور والانصراف',
    'printReport': 'طباعة التقرير',
    'refreshReport': 'تحديث التقرير',
    'reportDay': 'تقرير يوم {{date}}',
    'recordsCount': 'عدد السجلات: {{count}}',
    'waitLoading': 'انتظر حتى يكتمل تحميل التقرير',
    'noDataPrint': 'لا توجد بيانات لطباعة هذا التقرير',
    'printFailed': 'تعذّرت طباعة التقرير: {{error}}',
    'noRecordsToday': 'لا توجد سجلات حضور لهذا اليوم',
    'reportLoadError': 'حدث خطأ أثناء تحميل التقرير',
    'retry': 'إعادة المحاولة',
    'checkInTime': 'وقت الحضور',
    'checkOutTime': 'وقت الانصراف',
    'status': 'الحالة',
    'unknown': 'غير معروف',
    'unscheduled': 'غير مجدول',
    'jobTitle': 'الوظيفة',
    'employeeName': 'اسم الموظف',
    'centralSystem': 'نظام حضور الإسعاف المركزي',
    'addUserTitle': 'إضافة مستخدم',
    'attendanceUserData': 'بيانات مستخدم نظام الحضور',
    'loginInstruction': 'سيتمكن المستخدم من تسجيل الدخول باسم المستخدم وكلمة المرور.',
    'fullName': 'الاسم الكامل',
    'employeeNumber': 'الرقم الوظيفي',
    'jobTitleLabel': 'المسمى الوظيفي',
    'customJobTitle': 'اكتب اسم الوظيفة',
    'departmentOptional': 'القسم (اختياري)',
    'phoneOptional': 'رقم الهاتف (اختياري)',
    'createUser': 'إنشاء المستخدم',
    'userCreated': 'تم إنشاء المستخدم وربطه بنظام الحضور ✅',
    'createUserFailed': 'تعذّر إنشاء المستخدم، حاول مجددًا',
    'createUserError': 'تعذّر إنشاء المستخدم',
    'enterField': 'أدخل {{field}}',
    'passwordMin': 'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
    'jobTitleShort': 'اسم الوظيفة قصير جدًا',
    'jobTitleMax': 'اسم الوظيفة يجب ألا يتجاوز 100 حرف',
    'qrEmployees': 'باركود الموظفين',
    'sharedQrDescription': 'باركود واحد مشترك لجميع الموظفين لتسجيل الحضور',
    'qrPrintInstructions': 'اطبع هذا الباركود وضعه عند نقطة الحضور. يجب أن يكون واضحًا وبحجم مناسب حتى تتمكن كاميرات الموظفين من قراءته.',
    'updateQr': 'تحديث الباركود',
    'qrMissing': 'لم يتم ضبط باركود نقطة الحضور في Supabase',
    'scanAttendanceQr': 'مسح باركود الحضور',
    'scanInstruction': 'وجّه الكاميرا نحو باركود نقطة الحضور',
    'welcome': 'مرحبًا {{name}} 👋',
    'inService': 'أنت في الخدمة ✅',
    'checkedOut': 'تم تسجيل الانصراف ✅',
    'notChecked': 'الحالة: لم تسجل الحضور',
    'insideRange': 'داخل نطاق الإسعاف المركزي',
    'checkingLocation': 'جاري تحديد موقعك...',
    'outsideRange': 'خارج نطاق المركز، لا يمكن تسجيل الحضور',
    'locationError': 'تعذّر تحديد الموقع، تأكد من تفعيل خدمة الموقع',
    'scanCheckIn': 'مسح باركود الحضور',
    'checkOut': 'تسجيل الانصراف',
    'checkInSuccess': 'تم تسجيل حضور {{name}} بنجاح ✅\nأنت في الخدمة',
    'checkOutSuccess': 'تم تسجيل الانصراف بنجاح 👋',
    'checkInFailed': 'تعذّر تسجيل الحضور، حاول مجددًا',
    'checkOutFailed': 'تعذّر تسجيل الانصراف، حاول مجددًا',
    'authInvalid': 'اسم المستخدم أو كلمة المرور غير صحيحة',
    'attendanceOpen': 'لديك تسجيل حضور مفتوح بالفعل',
    'noOpenAttendance': 'لا يوجد تسجيل حضور مفتوح لإغلاقه',
    'sessionExpired': 'انتهت الجلسة، سجّل الدخول مجددًا',
    'notAuthorized': 'ليس لديك صلاحية لتنفيذ هذا الإجراء',
    'invalidQr': 'باركود الحضور غير صحيح',
    'outsideAttendanceRange': 'أنت خارج نطاق الإسعاف المركزي',
    'missingProfile': 'لا يوجد ملف حضور مرتبط بهذا المستخدم',
    'incompleteSettings': 'إعدادات المركز غير مكتملة في Supabase',
    'roleAdmin': 'مدير',
    'roleDoctor': 'طبيب',
    'roleNurse': 'ممرض/ة',
    'roleParamedic': 'مسعف',
    'roleSecretary': 'سكرتارية',
    'roleDriver': 'سائق',
    'rolePharmacist': 'صيدلي',
    'roleEmployee': 'موظف',
  },
  'en': {
    'appTitle': 'Central Ambulance Attendance',
    'loginSubtitle': 'Sign in to track attendance and departures',
    'username': 'Username',
    'password': 'Password',
    'login': 'Sign in',
    'invalidFields': 'Please enter your username and password',
    'networkError': 'Something went wrong. Check your internet connection',
    'logout': 'Sign out',
    'centralAmbulance': 'Central Ambulance',
    'adminDashboard': 'Admin Dashboard 👨‍💼',
    'employeeManagement': 'Employee management',
    'addEmployee': 'Add employee',
    'scanBarcode': 'Scan barcode',
    'employeeQrPrint': 'Show employee QR code for printing',
    'attendanceReport': 'Attendance and departure log',
    'searchEmployee': 'Search for an employee...',
    'presentNow': 'Currently present',
    'absent': 'Not present',
    'noEmployees': 'No employees match the search',
    'checkInLabel': 'Check-in',
    'checkOutLabel': 'Check-out',
    'present': 'Present',
    'departed': 'Checked out',
    'absentStatus': 'Absent',
    'editWorkDays': 'Edit work days',
    'workDaysFor': 'Work days for {{name}}',
    'cancel': 'Cancel',
    'saveDays': 'Save days',
    'saveDaysSuccess': 'Work days saved ✅',
    'monday': 'Monday',
    'tuesday': 'Tuesday',
    'wednesday': 'Wednesday',
    'thursday': 'Thursday',
    'friday': 'Friday',
    'saturday': 'Saturday',
    'sunday': 'Sunday',
    'reportTitle': 'Attendance and departure report',
    'printReport': 'Print report',
    'refreshReport': 'Refresh report',
    'reportDay': 'Report for {{date}}',
    'recordsCount': 'Records: {{count}}',
    'waitLoading': 'Wait for the report to finish loading',
    'noDataPrint': 'There is no data to print for this report',
    'printFailed': 'Could not print the report: {{error}}',
    'noRecordsToday': 'No attendance records for this day',
    'reportLoadError': 'Could not load the report',
    'retry': 'Try again',
    'checkInTime': 'Check-in time',
    'checkOutTime': 'Check-out time',
    'status': 'Status',
    'unknown': 'Unknown',
    'unscheduled': 'Unscheduled',
    'jobTitle': 'Job title',
    'employeeName': 'Employee name',
    'centralSystem': 'Central Ambulance Attendance System',
    'addUserTitle': 'Add user',
    'attendanceUserData': 'Attendance user details',
    'loginInstruction': 'The user will sign in with a username and password.',
    'fullName': 'Full name',
    'employeeNumber': 'Employee number',
    'jobTitleLabel': 'Job title',
    'customJobTitle': 'Enter a job title',
    'departmentOptional': 'Department (optional)',
    'phoneOptional': 'Phone number (optional)',
    'createUser': 'Create user',
    'userCreated': 'User created and linked to attendance ✅',
    'createUserFailed': 'Could not create the user. Try again',
    'createUserError': 'Could not create the user',
    'enterField': 'Enter {{field}}',
    'passwordMin': 'Password must be at least 6 characters',
    'jobTitleShort': 'Job title is too short',
    'jobTitleMax': 'Job title cannot exceed 100 characters',
    'qrEmployees': 'Employee QR code',
    'sharedQrDescription': 'One shared QR code for all employees to record attendance',
    'qrPrintInstructions': 'Print this QR code and place it at the attendance point. It should be clear and large enough for employee cameras to scan.',
    'updateQr': 'Refresh QR code',
    'qrMissing': 'The attendance point QR code is not configured in Supabase',
    'scanAttendanceQr': 'Scan attendance QR code',
    'scanInstruction': 'Point the camera at the attendance point QR code',
    'welcome': 'Welcome {{name}} 👋',
    'inService': 'You are on duty ✅',
    'checkedOut': 'Check-out recorded ✅',
    'notChecked': 'Status: no check-in recorded',
    'insideRange': 'Inside the central ambulance range',
    'checkingLocation': 'Locating you...',
    'outsideRange': 'Outside the center range; attendance cannot be recorded',
    'locationError': 'Could not determine your location. Enable location services',
    'scanCheckIn': 'Scan attendance QR code',
    'checkOut': 'Record check-out',
    'checkInSuccess': '{{name}} checked in successfully ✅\nYou are on duty',
    'checkOutSuccess': 'Check-out recorded successfully 👋',
    'checkInFailed': 'Could not record check-in. Try again',
    'checkOutFailed': 'Could not record check-out. Try again',
    'authInvalid': 'The username or password is incorrect',
    'attendanceOpen': 'You already have an open attendance record',
    'noOpenAttendance': 'There is no open attendance record to close',
    'sessionExpired': 'Your session expired. Sign in again',
    'notAuthorized': 'You are not authorized to perform this action',
    'invalidQr': 'The attendance QR code is invalid',
    'outsideAttendanceRange': 'You are outside the central ambulance range',
    'missingProfile': 'No attendance profile is linked to this user',
    'incompleteSettings': 'Center settings are incomplete in Supabase',
    'roleAdmin': 'Admin',
    'roleDoctor': 'Doctor',
    'roleNurse': 'Nurse',
    'roleParamedic': 'Paramedic',
    'roleSecretary': 'Secretary',
    'roleDriver': 'Driver',
    'rolePharmacist': 'Pharmacist',
    'roleEmployee': 'Employee',
  },
};