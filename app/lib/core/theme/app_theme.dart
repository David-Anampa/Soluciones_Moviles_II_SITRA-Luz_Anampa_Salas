import 'paleta_administracion.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta de colores corporativa de SITRA-Luz
class AppColors {
  AppColors._();

  // Primarios — azul médico profundo
  static const Color primary = Color(0xFF1A3A6B);
  static const Color primaryLight = Color(0xFF2E5BA8);
  static const Color primaryDark = Color(0xFF0D2040);

  // Secundarios — verde salud
  static const Color secondary = Color(0xFF00796B);
  static const Color secondaryLight = Color(0xFF26A69A);

  // Fondo y superficie
  static const Color background = Color(0xFFF4F6FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEEF2FA);

  // Estados / roles
  static const Color adminColor = PaletaAdministracion.principal; // Rojo oscuro — Administración
  static const Color jefaturaColor = Color(0xFF1A3A6B);   // Azul — Jefatura
  static const Color farmaciaColor = Color(0xFF00796B);   // Verde — Farmacia
  static const Color almacenColor = Color(0xFFE65100);    // Naranja — Almacén
  static const Color enfermeriaColor = Color(0xFF0277BD); // Celeste — Enfermería
  static const Color enfermeriaSuave = Color(0xFFE8F5FC);
  static const Color enfermeriaOscuro = Color(0xFF015A8F);

  // Semánticos
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57F17);
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF01579B);

  // Texto
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF5A6480);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Gradientes
  static const LinearGradient loginGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D2040), Color(0xFF1A3A6B), Color(0xFF2E5BA8)],
  );
}

/// Tema global de la aplicación
class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE3F0), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 15),
        labelStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
        errorStyle: GoogleFonts.inter(color: AppColors.error, fontSize: 12),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5EAF5), width: 1),
        ),
        color: AppColors.surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
    );
  }
}
