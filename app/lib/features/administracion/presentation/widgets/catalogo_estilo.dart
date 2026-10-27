import 'package:flutter/material.dart';
import '../../../../core/theme/tema_area.dart';
import '../../../../core/widgets/mensajes_app.dart';

class CatalogoEstilo {
  static const rojo = Color(0xFFC62828);
  static const pastel = Color(0xFFFFF0F0);
  static const fondo = Color(0xFFF5F5F5);
  static const texto = Color(0xFF262630);

  /// Deriva el tema administrativo del tema existente para conservar la tipografía.
  /// Define rojo/pastel/gris, texto e iconos blancos en cabeceras y hover en botones.
  static ThemeData tema(BuildContext context, {TemaArea? area}) {
    final base = Theme.of(context);
    final principal = area?.principal ?? rojo;
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 14),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 13),
      ),
      colorScheme: ColorScheme.fromSeed(seedColor: principal).copyWith(
        primary: principal,
        onPrimary: Colors.white,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: fondo,
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
        color: principal,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: principal,
          minimumSize: const Size(48, 48),
          hoverColor: principal.withValues(alpha: .08),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: principal,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: principal.withValues(alpha: .25)),
          overlayColor: principal.withValues(alpha: .08),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: area?.suave ?? pastel,
        checkmarkColor: principal,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: principal,
        foregroundColor: Colors.white,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: const Color(0xFFF7F7F7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: principal, width: 1.5),
        ),
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64646D)),
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF888890)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(44, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? principal.withValues(alpha: .35)
                : s.contains(WidgetState.hovered)
                ? Color.alphaBlend(
                    Colors.black.withValues(alpha: .15),
                    principal,
                  )
                : principal,
          ),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          overlayColor: WidgetStateProperty.resolveWith(
            (s) =>
                s.contains(WidgetState.hovered) ||
                    s.contains(WidgetState.focused)
                ? Colors.white.withOpacity(.12)
                : null,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: principal,
          minimumSize: const Size(44, 48),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          overlayColor: principal.withOpacity(.08),
        ),
      ),
    );
  }

  /// Construye un aviso reutilizable con icono y texto; no abre diálogos ni consulta datos.
  static Widget nota(
    String texto, {
    IconData icono = Icons.info_outline_rounded,
  }) => MensajesApp.nota(
    texto,
    tipo: icono == Icons.error_outline_rounded || icono == Icons.error_outline
        ? TipoMensaje.error
        : icono == Icons.warning_amber_rounded
        ? TipoMensaje.advertencia
        : TipoMensaje.informacion,
  );
}
