import 'package:flutter/material.dart';

/// النصوص العربية الموحدة للتطبيق.
class AppLocaleController extends ChangeNotifier {
  AppLocaleController._();

  static final instance = AppLocaleController._();

  Locale _locale = const Locale('ar');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';
  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  String text(
    String key, [
    Map<String, String> values = const {},
  ]) {
    var result = _translations[key] ?? key;

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

const Map<String, String> _translations = {
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
    'adminWelcome': 'تابع حالة الحضور وسجلات الموظفين من مكان واحد',
    'todaySummary': 'ملخص اليوم',
    'totalEmployees': 'إجمالي الموظفين',
    'quickActions': 'إجراءات سريعة',
    'addEmployee': 'إضافة موظف',
    'scanBarcode': 'مسح الباركود',
    'employeeQrPrint': 'عرض باركود الموظفين للطباعة',
    'attendanceReport': 'سجل الحضور والانصراف',
    'monthlyAttendanceReport': 'تقرير موظف - عدد أيام الحضور',
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
};
