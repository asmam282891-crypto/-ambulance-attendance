import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import '../theme/app_theme.dart';

/// شاشة مسح الباركود الخاص بنقطة الحضور.
/// عند نجاح المسح، تُعيد محتوى الكود إلى الشاشة السابقة.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _handled = false;
  bool _cameraError = false;
  String _errorMessage = '';

  void _onScan(Code result) {
    if (_handled || !mounted) return;

    if (!result.isValid) {
      return;
    }

    final value = result.text.trim();

    if (value.isEmpty) {
      return;
    }

    _handled = true;

    Navigator.of(context).pop(value);
  }

  void _onScanFailure(Code result) {
    if (!mounted || _handled) return;

    // لا نعرض خطأ لكل إطار لم يتمكن من قراءة QR.
    // نترك الكاميرا تعمل حتى يظهر الكود الصحيح.
  }

  void _onControllerCreated(
    CameraController? controller,
    Exception? error,
  ) {
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _cameraError = true;
        _errorMessage = error.toString();
      });
    }
  }

  void _retryCamera() {
    setState(() {
      _cameraError = false;
      _errorMessage = '';
      _handled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('مسح باركود الحضور'),
          centerTitle: true,
        ),
        body: _cameraError
            ? _buildCameraError()
            : Stack(
                fit: StackFit.expand,
                children: [
                  ReaderWidget(
                    key: ValueKey(_cameraError),
                    codeFormat: Format.qrCode,
                    lensDirection: CameraLensDirection.back,
                    resolution: ResolutionPreset.high,
                    tryHarder: true,
                    tryRotate: true,
                    showScannerOverlay: true,
                    showFlashlight: true,
                    showToggleCamera: false,
                    showGallery: false,
                    scanDelay: const Duration(milliseconds: 500),
                    scanDelaySuccess: const Duration(milliseconds: 1000),
                    cropPercent: 0.7,
                    onScan: _onScan,
                    onScanFailure: _onScanFailure,
                    onControllerCreated: _onControllerCreated,
                  ),

                  // إطار المسح الخاص بالتطبيق
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.ambulanceRed,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 35,
                    left: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'وجّه الكاميرا نحو باركود نقطة الحضور',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCameraError() {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.dangerBg,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(
              Icons.videocam_off_outlined,
              color: AppColors.danger,
              size: 32,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'تعذّر تشغيل الكاميرا',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'تأكد من السماح للتطبيق باستخدام الكاميرا من إعدادات الهاتف، ثم حاول مرة أخرى.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _retryCamera,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
