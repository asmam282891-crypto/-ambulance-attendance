import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'screens/login_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // التهيئة المباشرة بـ URL و Anon JWT Key الصحيحين
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
      title: 'نظام حضور الإسعاف المركزي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const _SessionGate(),
    );
  }
}

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
        if (employee.isAdmin) {
          return const AdminDashboardScreen();
        }
        return AttendanceScreen(employee: employee);
      },
    );
  }
}
