import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';

/// شاشة مسح الباركود الخاص بنقطة الحضور.
/// عند نجاح المسح، تُعيد محتوى الكود إلى الشاشة السابقة عبر Navigator.pop.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) return;

    // لا نعتمد على أول عنصر فقط؛ قد تُرجع الكاميرا أكثر من نتيجة
    // ويكون أول عنصر بلا rawValue بينما تكون النتيجة الصحيحة بعده.
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .firstWhere(
          (rawValue) => rawValue != null && rawValue.isNotEmpty,
          orElse: () => null,
        );

    if (value == null || value.isEmpty) return;

    _handled = true;
    // إيقاف الكاميرا قبل إغلاق الشاشة يمنع تكرار القراءة أو بقاء الكاميرا
    // مشغلة عند العودة إلى شاشة الحضور.
    unawaited(_controller.stop());
    Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              fit: BoxFit.cover,
              onDetect: _onDetect,
            ),
            Center(
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
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Text(
                'وجّه الكاميرا نحو باركود نقطة الحضور',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
