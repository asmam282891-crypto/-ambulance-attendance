import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'screens/login_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vdqsdoyqpxuiiznaruuj.supabase.co',
  );
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'Missing Supabase configuration. Run with '
      '--dart-define=SUPABASE_URL=... '
      '--dart-define=SUPABASE_ANON_KEY=...',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const AmbulanceAttendanceApp());
}

class AmbulanceAttendanceApp extends StatelessWidget {
  const AmbulanceAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام حضور الإسعاف المركزي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // ملاحظة: لترجمة عناصر Material الجاهزة (حوارات التاريخ وغيرها)
      // للعربية بالكامل، أضف حزمة flutter_localizations في pubspec.yaml
      // ثم فعّل: locale, supportedLocales, localizationsDelegates.
      home: const _SessionGate(),
    );
  }
}

/// تتحقق هذه الشاشة أولًا من وجود جلسة Supabase محفوظة قبل عرض شاشة
/// تسجيل الدخول، حتى لا يُجبر الموظف على تسجيل الدخول في كل مرة.
class _SessionGate extends StatelessWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: SupabaseService.instance.currentEmployee(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final employee = snapshot.data;
        if (employee == null) {
          return const LoginScreen();
        }
        if (employee.role == 'admin') {
          return const AdminDashboardScreen();
        }
        return AttendanceScreen(employee: employee);
      },
    );
  }
}
