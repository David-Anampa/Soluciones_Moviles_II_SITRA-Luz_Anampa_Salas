import 'package:flutter/material.dart';

class CatalogoEstilo {
  static const rojo = Color(0xFFC62828);
  static const pastel = Color(0xFFFFF0F0);
  static const fondo = Color(0xFFF5F5F5);
  static const texto = Color(0xFF262630);

  /// Deriva el tema administrativo del tema existente para conservar la tipografía.
  /// Define rojo/pastel/gris, texto e iconos blancos en cabeceras y hover en botones.
  static ThemeData tema(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 14),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 13)),
      colorScheme: ColorScheme.fromSeed(seedColor: rojo).copyWith(
        primary: rojo, onPrimary: Colors.white, surface: Colors.white),
      scaffoldBackgroundColor: fondo,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: rojo, foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white)),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: const Color(0xFFF7F7F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: rojo, width: 1.5)),
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64646D)),
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF888890)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(44, 48)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled)
          ? const Color(0xFFE5C6C6) : s.contains(WidgetState.hovered) ? const Color(0xFFA61E1E) : rojo),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        overlayColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.hovered) || s.contains(WidgetState.focused) ? Colors.white.withOpacity(.12) : null),
      )),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        foregroundColor: rojo, minimumSize: const Size(44, 48),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        overlayColor: rojo.withOpacity(.08))),
    );
  }

  /// Construye un aviso reutilizable con icono y texto; no abre diálogos ni consulta datos.
  static Widget nota(String texto, {IconData icono = Icons.info_outline_rounded}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: pastel, borderRadius: BorderRadius.circular(12)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icono, color: rojo, size: 20), const SizedBox(width: 10),
      Expanded(child: Text(texto, style: const TextStyle(fontSize: 13, height: 1.5, color: CatalogoEstilo.texto))),
    ]));
}
