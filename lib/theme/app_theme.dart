import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// نظام الألوان والخطوط الموحّد لتطبيق حضور الإسعاف المركزي.
/// الفكرة: أحمر الإسعاف كلون تعريفي، مع كنفاس محايد هادئ
/// حتى تبقى القراءة مريحة في المناوبات الليلية الطويلة.
class AppColors {
  AppColors._();

  static const Color ambulanceRed = Color(0xFFD32F2F);
  static const Color ambulanceRedDark = Color(0xFFB71C1C);
  static const Color navy = Color(0xFF102A43);
  static const Color navySoft = Color(0xFF1E3A5F);

  static const Color background = Color(0xFFF6F7F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE3E6EA);

  static const Color textPrimary = Color(0xFF1B222B);
  static const Color textSecondary = Color(0xFF64748B);

  static const Color success = Color(0xFF1E8E5A);
  static const Color successBg = Color(0xFFE7F6EE);
  static const Color danger = Color(0xFFD64545);
  static const Color dangerBg = Color(0xFFFCEAEA);
  static const Color warning = Color(0xFFC98A1F);
}

class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.ambulanceRed,
        primary: AppColors.ambulanceRed,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    final textTheme = GoogleFonts.tajawalTextTheme(base.textTheme).copyWith(
      headlineMedium: GoogleFonts.tajawal(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.tajawal(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.tajawal(
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
      bodySmall: GoogleFonts.tajawal(
        fontSize: 12,
        color: AppColors.textSecondary,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.ambulanceRed, width: 1.6),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ambulanceRed,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.tajawal(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
