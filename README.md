# نظام حضور الإسعاف المركزي — Flutter + Supabase

تطبيق Flutter متصل مباشرة بـ Supabase (المصادقة + قاعدة البيانات) بثلاث شاشات:

1. تسجيل الدخول — `lib/screens/login_screen.dart`
2. الحضور والانصراف مع التحقق من الموقع ومسح الباركود —
   `attendance_screen.dart`, `qr_scan_screen.dart`
3. لوحة تحكم المدير بالإحصائيات وقائمة الموظفين —
   `admin_dashboard_screen.dart`

## 1. إعداد قاعدة البيانات

نفّذ محتوى `supabase_schema.sql` في **Supabase Dashboard → SQL Editor**.
هذا الملف ينشئ:
- جدول `employees` (مرتبط بـ `auth.users`)
- جدول `attendance`
- سياسات RLS أساسية (كل موظف يشوف بياناته، المدير يشوف الكل)
- دالة `dashboard_stats()` لإحصائيات لوحة التحكم في استعلام واحد

> إن كانت قاعدة بياناتك الجاهزة تستخدم أسماء جداول/أعمدة مختلفة،
> عدّلها في `lib/services/supabase_service.dart` بدل تغيير الشاشات.

راجع قسم "تسجيل الدخول باسم المستخدم" أدناه لخطوات إضافة موظف تجريبي.

## 2. ربط التطبيق بمشروعك

شغّل التطبيق مع تمرير القيمتين من **Project Settings → API** عبر
`--dart-define` بدل تخزينهما داخل Git:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

في بيئة Replit التي تحتوي على Secret باسم `SUPABASE_ANON_KEY` يمكن تشغيل
النسخة مباشرة عبر:

```bash
./run_with_supabase.sh
```

قاعدة بياناتك الحالية تستخدم جداول `attendance_users` و
`attendance_records` و`attendance_settings`. نفّذ ملف
`supabase_attendance_migration.sql` بعد أي تحديث له؛ فهو يربط تسجيل الدخول
بـ `profiles.username`، ويتحقق خادميًا من QR والموقع، ويمنع الكتابة المباشرة
إلى سجلات الحضور. لا تنفّذ `supabase_schema.sql` القديم على هذه القاعدة؛ فهو
خاص ببنية مختلفة ويُنشئ جداول `employees` و`attendance` جديدة.

## 3. تسجيل الدخول باسم المستخدم

التطبيق يسجّل الدخول باسم مستخدم مباشرة، وليس بريدًا إلكترونيًا:
- جدول `employees` فيه عمود `username` فريد (unique).
- دالة SQL آمنة `email_for_username(p_username)` تبحث عن البريد
  المقابل لاسم المستخدم في `auth.users` وتعيده فقط — بدون كشف أي
  بيانات أخرى، وهي القابلة للاستدعاء من أي شخص (حتى قبل تسجيل الدخول)
  لأنها لازمة لإتمام عملية الدخول أصلًا.
- `supabase_service.dart` يستدعي هذه الدالة أولًا لإيجاد البريد،
  ثم يكمل تسجيل الدخول عبر `signInWithPassword` عاديًا.

### إضافة موظف جديد
عند إنشاء المستخدم من **Authentication → Users → Add user** تحتاج
بريدًا إلكترونيًا فعليًا لأن Supabase Auth يتطلبه داخليًا (لن يظهر
للموظف ولن يستخدمه في الدخول). ثم أضف صفًا في `employees` بنفس الـ
`id` مع `username` و`full_name` و`role`.

## 4. التشغيل

```bash
flutter pub get
flutter run
```

## 5. الصلاحيات المطلوبة على مستوى النظام

### Android — `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

### iOS — `ios/Runner/Info.plist`
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>نحتاج موقعك للتحقق من وجودك داخل نطاق المركز</string>
<key>NSCameraUsageDescription</key>
<string>نحتاج الكاميرا لمسح باركود الحضور</string>
```

## هيكل المشروع

```
supabase_schema.sql              # جداول + RLS + دالة الإحصائيات
lib/
  main.dart                      # تهيئة Supabase + التحقق من الجلسة
  theme/app_theme.dart
  models/
    employee.dart
    dashboard_stats.dart
  services/
    supabase_service.dart        # كل التعامل مع Supabase من هنا فقط
    location_service.dart        # التحقق من النطاق الجغرافي
  screens/
    login_screen.dart
    attendance_screen.dart
    qr_scan_screen.dart
    admin_dashboard_screen.dart
  widgets/
    app_text_field.dart
    stat_card.dart
```

## نقاط لإكمالها لاحقًا

- إحداثيات المركز ونطاق السماح موجودة في صف `attendance_settings` داخل
  Supabase ويقرأها التطبيق مباشرة.
- شاشة "إضافة موظف" الفعلية (الزر جاهز في لوحة التحكم).
- شاشة "عرض التقارير" الفعلية (الزر جاهز).
- Realtime اختياري: يمكن الاشتراك في تغييرات جدول `attendance` عبر
  `supabase.from('attendance').stream(...)` بدل الاعتماد فقط على السحب للتحديث.
