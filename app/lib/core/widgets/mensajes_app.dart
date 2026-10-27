import 'package:flutter/material.dart';

enum TipoMensaje { informacion, exito, advertencia, error }

/// Mensajes semánticos independientes del tema/rol/área y sin dependencia de datos.
class MensajesApp {
  static Color color(TipoMensaje tipo) => switch (tipo) {
    TipoMensaje.error => const Color(0xFFB3261E),
    TipoMensaje.advertencia => const Color(0xFF855300),
    TipoMensaje.exito => const Color(0xFF23713B),
    TipoMensaje.informacion => const Color(0xFF245B8F),
  };
  static Color fondo(TipoMensaje tipo) => switch (tipo) {
    TipoMensaje.error => const Color(0xFFFFEDEA),
    TipoMensaje.advertencia => const Color(0xFFFFF5DB),
    TipoMensaje.exito => const Color(0xFFECF7EF),
    TipoMensaje.informacion => const Color(0xFFEDF4FB),
  };
  static IconData icono(TipoMensaje tipo) => switch (tipo) {
    TipoMensaje.error => Icons.cancel_outlined,
    TipoMensaje.advertencia => Icons.warning_amber_rounded,
    TipoMensaje.exito => Icons.check_circle_outline_rounded,
    TipoMensaje.informacion => Icons.info_outline_rounded,
  };

  /// Aviso junto al contenido: icono, texto y color transmiten el mismo significado.
  static Widget nota(
    String texto, {
    TipoMensaje tipo = TipoMensaje.informacion,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: fondo(tipo),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color(tipo).withValues(alpha: .18)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono(tipo), color: color(tipo), size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF262630),
            ),
          ),
        ),
      ],
    ),
  );

  /// Resultado breve: no bloquea la pantalla con un modal por cada guardado.
  static void mostrar(
    BuildContext context,
    String texto, {
    TipoMensaje tipo = TipoMensaje.exito,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: fondo(tipo),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: tipo == TipoMensaje.error ? 7 : 4),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono(tipo), color: color(tipo), size: 23),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF262630),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  /// Modal para decisiones. Cancelar o cerrar nunca confirma la operación.
  static Future<bool> confirmar(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    required String accion,
    TipoMensaje tipo = TipoMensaje.advertencia,
    bool destructivo = false,
    String cancelar = 'Cancelar',
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: fondo(tipo),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icono(tipo), color: color(tipo), size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF262630),
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              mensaje,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF424242),
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF616161),
                  minimumSize: const Size(48, 48),
                ),
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(cancelar),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: destructivo
                      ? color(TipoMensaje.error)
                      : color(tipo),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(accion),
              ),
            ],
          ),
        ) ==
        true;
  }
}
