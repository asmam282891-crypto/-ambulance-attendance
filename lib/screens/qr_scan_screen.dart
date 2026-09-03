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
    MobileScannerController _controller = MobileScannerController();
    bool _handled = false;
    bool _retrying = false;

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

    Future<void> _retryCamera() async {
      if (_retrying || !mounted) return;

      setState(() {
        _retrying = true;
      });

      // إنشاء Controller جديد مهم خصوصًا بعد رفض الصلاحية؛ فالـ Controller
      // القديم يحتفظ بحالة الخطأ ولا يعيد طلب صلاحية الكاميرا مرة أخرى.
      final previousController = _controller;
      await previousController.dispose();

      if (!mounted) return;

      setState(() {
        _controller = MobileScannerController();
        _handled = false;
        _retrying = false;
      });
    }

    String _errorTitle(MobileScannerException exception) {
      switch (exception.errorCode) {
        case MobileScannerErrorCode.permissionDenied:
          return 'صلاحية الكاميرا مرفوضة';
        case MobileScannerErrorCode.unsupported:
          return 'الكاميرا غير مدعومة';
        case MobileScannerErrorCode.controllerAlreadyInitialized:
        case MobileScannerErrorCode.controllerDisposed:
        case MobileScannerErrorCode.controllerUninitialized:
        case MobileScannerErrorCode.genericError:
          return 'تعذّر تشغيل الكاميرا';
      }
    }

    String _errorMessage(MobileScannerException exception) {
      if (exception.errorCode == MobileScannerErrorCode.permissionDenied) {
        return 'اسمح لتطبيق الإسعاف المركزي باستخدام الكاميرا من إعدادات الهاتف، ثم اضغط إعادة المحاولة.';
      }

      if (exception.errorCode == MobileScannerErrorCode.unsupported) {
        return 'هذا الجهاز أو المحاكي لا يوفر كاميرا يمكن استخدامها لمسح الباركود.';
      }

      return 'تأكد من أن الكاميرا ليست مستخدمة في تطبيق آخر، ثم حاول مرة أخرى.';
    }

    Widget _buildScannerError(
      BuildContext context,
      MobileScannerException exception,
      Widget? child,
    ) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(29),
              ),
              child: const Icon(
                Icons.videocam_off_outlined,
                color: AppColors.danger,
                size: 29,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _errorTitle(exception),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage(exception),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _retrying ? null : _retryCamera,
              icon: _retrying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: Text(_retrying ? 'جاري المحاولة...' : 'إعادة المحاولة'),
            ),
          ],
        ),
      );
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
              // تغيير المفتاح يعيد بناء MobileScanner بالكامل بعد الخطأ،
              // ويمنع بقاء الحالة القديمة داخل الحزمة.
              KeyedSubtree(
                key: ObjectKey(_controller),
                child: MobileScanner(
                  controller: _controller,
                  fit: BoxFit.cover,
                  onDetect: _onDetect,
                  errorBuilder: _buildScannerError,
                  placeholderBuilder: (context, child) => const ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.ambulanceRed,
                      ),
                    ),
                  ),
                ),
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
    