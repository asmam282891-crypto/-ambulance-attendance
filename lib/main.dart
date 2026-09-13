import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ambulance_attendance/services/supabase_service.dart';
import 'package:ambulance_attendance/models/employee.dart';
import 'package:ambulance_attendance/l10n/app_localizations.dart';
import 'package:ambulance_attendance/screens/login_screen.dart';
import 'package:ambulance_attendance/screens/attendance_screen.dart';
import 'package:ambulance_attendance/screens/admin_dashboard_screen.dart';
import 'package:ambulance_attendance/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // مؤقت للتشخيص: يعرض نص الخطأ الحقيقي بدل المربع الرمادي الفاضي
  // حتى في نسخة الـ release. لا تحذف هذا الجزء حتى نحل المشكلة نهائياً.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Text(
        details.exceptionAsString(),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.red, fontSize: 13),
      ),
    );
  };

  await Supabase.initialize(
    url: 'https://vdqsdoyqpxuiiznaruuj.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZkcXNkb3lxcHh1aWl6bmFydXVqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY5MDU0NTksImV4cCI6MjEwMjQ4MTQ1OX0.BMGUe1XVsee_-gviktC25wbqBDUkzuJu20fv8QBRypg',
  );

  runApp(const AmbulanceAttendanceApp());
}

class AmbulanceAttendanceApp extends StatelessWidget {
  const AmbulanceAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppLocaleController.instance.text('appTitle'),

      // اللغة العربية فقط
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
      ],

      // ضروري حتى تعمل عناصر مثل TextField بدون انهيار (Null check operator)
      // لأنها تحتاج داخلياً إلى MaterialLocalizations.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // اتجاه التطبيق من اليمين إلى اليسار
      builder: (context, child) {
        return Directionality(
          textDirection: AppLocaleController.instance.textDirection,
          child: child ?? const SizedBox.shrink(),
        );
      },

      debugShowCheckedModeBanner: false,

      // الثيم الأساسي للمشروع
      theme: AppTheme.theme,

      home: const _SessionGate(),
    );
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  late final Future<Employee?> _employeeFuture;

  @override
  void initState() {
    super.initState();
    _employeeFuture = _loadEmployee();
  }

  Future<Employee?> _loadEmployee() async {
    try {
      return await SupabaseService.instance.currentEmployee().timeout(
        const Duration(seconds: 8),
      );
    } catch (_) {
      // If Supabase is unavailable, let the user reach the login screen.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Employee?>(
      future: _employeeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final employee = snapshot.data;

        if (employee == null) {
          return const LoginScreen();
        }

        if (employee.isAdmin) {
          return const AdminDashboardScreen();
        }

        return AttendanceScreen(employee: employee);
      },
    );
  }
}
