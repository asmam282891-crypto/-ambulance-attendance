import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/attendance_settings.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

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
    _error = e.toString();
    _loading = false;
  });
}

}

@override
Widget build(BuildContext context) {
return Directionality(
 textDirection: AppLocaleController.instance.textDirection,
child: Scaffold(
appBar: AppBar(
 title: Text(context.tr('qrEmployees')),
centerTitle: true,
 actions: const [LanguageToggleButton()],
),
body: _buildBody(),
),
);
}

Widget _buildBody() {
if (_loading) {
return const Center(
child: CircularProgressIndicator(),
);
}

if (_error != null) {
  return _MessageView(
    icon: Icons.error_outline,
    message: _error!,
    actionLabel: context.tr('retry'),
    onAction: _loadSettings,
  );
}

final settings = _settings;
final value = settings?.qrCode.trim() ?? '';

if (settings == null || value.isEmpty) {
  return _MessageView(
    icon: Icons.qr_code_2,
    message: context.tr('qrMissing'),
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
      ),

      const SizedBox(height: 10),

      Text(
        settings.centerName,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),

      const SizedBox(height: 6),

       Text(
         context.tr('sharedQrDescription'),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textSecondary,
        ),
      ),

      const SizedBox(height: 22),

      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.border,
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
          size: 280,
          backgroundColor: Colors.white,
        ),
      ),

      const SizedBox(height: 18),

       Text(
         context.tr('qrPrintInstructions'),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),

      const SizedBox(height: 14),

      OutlinedButton.icon(
        onPressed: _loadSettings,
        icon: const Icon(Icons.refresh),
         label: Text(context.tr('updateQr')),
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
color: AppColors.textSecondary,
),

        const SizedBox(height: 14),

        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
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
