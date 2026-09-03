import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import '../theme/app_theme.dart';

/// شاشة مسح باركود نقطة الحضور.
/// عند نجاح المسح يتم إرجاع محتوى الباركود للشاشة السابقة.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _handled = false;

  void _onScan(Code result) {
    if (_handled || !mounted) return;

    final value = result.text.trim();

    if (value.isEmpty) return;

    _handled = true;

    Navigator.of(context).pop(value);
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
          centerTitle: true,
          title: const Text(
            'مسح باركود الحضور',
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            ReaderWidget(
              codeFormat: Format.qrCode,
              onScan: _onScan,
              showGallery: false,
              showToggleCamera: true,
              showFlashlight: true,
            ),

            // إطار تحديد مكان الباركود
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

            // تعليمات المسح
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
                  color: Colors.black.withOpacity(0.65),
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
}
