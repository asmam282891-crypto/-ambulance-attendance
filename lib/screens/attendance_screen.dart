import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/employee.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'qr_scan_screen.dart';
import 'login_screen.dart';

enum _LocationState {
  checking,
  inRange,
  outOfRange,
  error,
}

class AttendanceScreen extends StatefulWidget {
  final Employee employee;

  const AttendanceScreen({
    super.key,
    required this.employee,
  });

  @override
  State<AttendanceScreen> createState() =>
      _AttendanceScreenState();
}

class _AttendanceScreenState
    extends State<AttendanceScreen> {
  _LocationState _locationState =
      _LocationState.checking;

  Position? _position;

  bool _isCheckedIn = false;

  String? _checkInTime;

  String? _checkOutTime;

  bool _isSubmitting = false;

  String? _feedback;

  @override
  void initState() {
    super.initState();

    _isCheckedIn =
        widget.employee.isCheckedIn;

    _checkInTime =
        widget.employee.checkInTime;

    _checkOutTime =
        widget.employee.checkOutTime;

    _loadSettingsAndLocation();
  }

  Future<void> _loadSettingsAndLocation() async {
    if (!mounted) return;

    setState(() {
      _locationState =
          _LocationState.checking;
    });

    try {
      final settings =
          await SupabaseService.instance
              .fetchAttendanceSettings();

      final position =
          await LocationService
              .getCurrentPosition();

      final inRange =
          LocationService.isWithinRange(
        position,
        settings,
      );

      if (!mounted) return;

      setState(() {
        _position = position;

        _locationState = inRange
            ? _LocationState.inRange
            : _LocationState.outOfRange;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _locationState =
            _LocationState.error;
      });
    }
  }

  Future<void> _refreshLocation() =>
      _loadSettingsAndLocation();

  Future<void> _scanAndCheckIn() async {
    // لا نفتح الكاميرا إلا بعد نجاح التحقق من موقع الموظف.
    if (!_canAct) return;

    final qrPayload =
        await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            const QrScanScreen(),
      ),
    );

    if (qrPayload == null) return;

    await _submitCheckIn(
      qrPayload: qrPayload,
    );
  }

  Future<void> _submitCheckIn({
    String? qrPayload,
  }) async {
    if (_position == null) return;

    setState(() {
      _isSubmitting = true;
      _feedback = null;
    });

    try {
      await SupabaseService.instance.checkIn(
        qrPayload: qrPayload,
        latitude: _position!.latitude,
        longitude: _position!.longitude,
      );

      if (!mounted) return;

      final now = DateTime.now();

      final formattedTime =
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}';

      setState(() {
        _isCheckedIn = true;

        _checkInTime =
            formattedTime;
        _checkOutTime = null;

        _feedback =
            context.tr(
              'checkInSuccess',
              {'name': widget.employee.title},
            );
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _feedback = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _feedback =
            context.tr('checkInFailed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitCheckOut() async {
    if (_position == null) return;

    setState(() {
      _isSubmitting = true;
      _feedback = null;
    });

    try {
      await SupabaseService.instance.checkOut(
        latitude: _position!.latitude,
        longitude: _position!.longitude,
      );

      if (!mounted) return;

      final now = DateTime.now();
      final formattedTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      setState(() {
        _isCheckedIn = false;

        // نحتفظ بوقت الحضور ونضيف وقت الانصراف.
        _checkOutTime = formattedTime;

        _feedback =
            context.tr('checkOutSuccess');
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _feedback = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _feedback =
            context.tr('checkOutFailed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await SupabaseService.instance.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            const LoginScreen(),
      ),
      (route) => false,
    );
  }

  bool get _canAct =>
      _locationState ==
          _LocationState.inRange &&
      !_isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocaleController.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'app_icon.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              Text(context.tr('centralAmbulance')),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _logout,
              icon: const Icon(
                Icons.logout,
                size: 20,
              ),
              tooltip: context.tr('logout'),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refreshLocation,
          child: ListView(
            padding:
                const EdgeInsets.all(20),
            children: [
              Text(
                context.tr(
                  'welcome',
                  {'name': widget.employee.title},
                ),
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium,
              ),

              const SizedBox(height: 4),

              Text(
                widget.employee.roleLabel,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),

              const SizedBox(height: 20),

              _buildAttendanceStatusCard(),

              const SizedBox(height: 16),

              _buildLocationCard(),

              const SizedBox(height: 24),

              if (_feedback != null) ...[
                _buildFeedbackBanner(),

                const SizedBox(height: 16),
              ],

              if (!_isCheckedIn) ...[
                ElevatedButton.icon(
                  onPressed:
                      _canAct
                          ? _scanAndCheckIn
                          : null,
                  icon: const Icon(
                    Icons.qr_code_scanner,
                  ),
                  label: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                        : Text(context.tr('scanCheckIn')),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed:
                      _canAct
                          ? _submitCheckOut
                          : null,
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        AppColors.navy,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                        : Text(context.tr('checkOut')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceStatusCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isCheckedIn
            ? AppColors.successBg
            : AppColors.surface,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: _isCheckedIn
              ? AppColors.success
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isCheckedIn || _checkOutTime != null
                ? Icons.check_circle
                : Icons.access_time_filled,
            color: _isCheckedIn || _checkOutTime != null
                ? AppColors.success
                : Colors.grey,
            size: 28,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _isCheckedIn
                        ? context.tr('inService')
                      : _checkOutTime != null
                            ? context.tr('checkedOut')
                            : context.tr('notChecked'),
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    color: _isCheckedIn || _checkOutTime != null
                        ? AppColors.success
                        : Colors.black87,
                  ),
                ),

                if (_checkInTime != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 2,
                    ),
                    child: Text(
                      '⏰ ${context.tr('checkInTime')}: $_checkInTime',
                      style:
                          const TextStyle(
                        fontSize: 13,
                        color: AppColors
                            .textSecondary,
                      ),
                    ),
                  ),

                if (_checkOutTime != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 2,
                    ),
                    child: Text(
                      '⏱️ ${context.tr('checkOutTime')}: $_checkOutTime',
                      style:
                          const TextStyle(
                        fontSize: 13,
                        color: AppColors
                            .textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackBanner() {
    final isSuccess =
        _feedback!.contains('✅') ||
        _feedback!.contains('👋');

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess
            ? AppColors.successBg
            : AppColors.dangerBg,
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Text(
        _feedback!,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isSuccess
              ? AppColors.success
              : AppColors.danger,
          fontWeight:
              FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    late final String text;
    late final Color color;
    late final Color bg;
    late final IconData icon;

    switch (_locationState) {
      case _LocationState.checking:
        text = context.tr('checkingLocation');
        color =
            AppColors.textSecondary;
        bg = AppColors.border
            .withOpacity(0.4);
        icon =
            Icons.my_location;
        break;

      case _LocationState.inRange:
        text = context.tr('insideRange');
        color =
            AppColors.success;
        bg =
            AppColors.successBg;
        icon =
            Icons.check_circle;
        break;

      case _LocationState.outOfRange:
        text = context.tr('outsideRange');
        color =
            AppColors.danger;
        bg =
            AppColors.dangerBg;
        icon =
            Icons.location_off;
        break;

      case _LocationState.error:
        text = context.tr('locationError');
        color =
            AppColors.warning;
        bg = AppColors.dangerBg
            .withOpacity(0.5);
        icon =
            Icons.error_outline;
        break;
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          if (_locationState !=
              _LocationState.checking)
            IconButton(
              onPressed:
                  _refreshLocation,
              icon: Icon(
                Icons.refresh,
                color: color,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}
