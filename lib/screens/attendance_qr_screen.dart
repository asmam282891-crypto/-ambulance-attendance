import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/attendance_settings.dart';
import '../services/supabase_service.dart';

class AttendanceQrScreen extends StatefulWidget {
  const AttendanceQrScreen({super.key});

  @override
  State<AttendanceQrScreen> createState() => _AttendanceQrScreenState();
}

class _AttendanceQrScreenState extends State<AttendanceQrScreen> {
  AttendanceSettings? _settings;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final settings =
          await SupabaseService.instance.fetchAttendanceSettings();

      if (!mounted) return;

      setState(() {
        _settings = settings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'حدث خطأ أثناء تحميل البيانات: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('رمز QR للموظفين'),
          centerTitle: true,
          backgroundColor: const Color(0xFFD32F2F),
          foregroundColor: Colors.white,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
      );
    }

    if (_error != null) {
      return _MessageView(
        icon: Icons.error_outline,
        message: _error!,
        actionLabel: 'إعادة المحاولة',
        onAction: _loadSettings,
      );
    }

    final settings = _settings;
    final value = settings?.qrCode.trim() ?? '';

    if (settings == null || value.isEmpty) {
      return const _MessageView(
        icon: Icons.qr_code_2,
        message: 'لا يوجد رمز QR متاح حالياً',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSettings,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Image.asset(
            'app_icon.png',
            width: 64,
            height: 64,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.local_hospital,
              size: 64,
              color: Color(0xFFD32F2F),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            settings.centerName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'امسح رمز QR المسجل لتسجيل الحضور أو الانصراف',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.grey.shade300,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: value,
                size: 260,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'يمكنك طباعة هذا الرمز وتعليقه في مدخل المركز لتسهيل عملية المسح',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              height: 1.5,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD32F2F),
              side: const BorderSide(color: Color(0xFFD32F2F)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _loadSettings,
            icon: const Icon(Icons.refresh),
            label: const Text('تحديث الرمز'),
          ),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageView({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 52,
              color: Colors.grey,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 15,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
 
