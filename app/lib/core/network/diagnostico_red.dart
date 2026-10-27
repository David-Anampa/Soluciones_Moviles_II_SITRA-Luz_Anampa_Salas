import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Registra tiempos y códigos en desarrollo. Nunca recibe cuerpos, URLs con
/// parámetros, claves, correos, identificadores de personas ni mensajes del servidor.
class DiagnosticoRed {
  static int _secuencia = 0;

  static void evento(String operacion, String estado) {
    if (kDebugMode) debugPrint('[SITRA] $operacion | $estado');
  }

  /// Muestra la clase/código del fallo y solo ubicaciones del código de la app.
  static void error(String operacion, Object error, StackTrace stack, int ms) {
    if (!kDebugMode) return;
    final codigo = error is sb.PostgrestException
        ? error.code
        : error is sb.AuthApiException
        ? error.code
        : null;
    final seguro =
        codigo != null && RegExp(r'^[A-Za-z0-9_-]{1,60}$').hasMatch(codigo)
        ? ' codigo=$codigo'
        : '';
    final categoria = switch (codigo) {
      '42501' => 'permiso_denegado',
      'PGRST202' || '42883' => 'funcion_no_disponible',
      '42P01' => 'tabla_no_disponible',
      '23505' => 'registro_duplicado',
      '57014' => 'tiempo_agotado_en_postgresql',
      '40P01' => 'bloqueo_mutuo_en_postgresql',
      '55P03' => 'registro_bloqueado',
      _ =>
        error is TimeoutException
            ? 'tiempo_de_espera_agotado'
            : 'fallo_de_operacion',
    };
    debugPrint(
      '[SITRA] $operacion | ERROR ${error.runtimeType}$seguro $categoria | ${ms}ms',
    );
    for (final linea
        in stack
            .toString()
            .split('\n')
            .where((l) => l.contains('package:sitra_luz/'))
            .take(3)) {
      debugPrint('[SITRA] $linea');
    }
  }

  /// Señala qué operación sigue esperando a los 5 s y mide hasta terminar/fallar.
  static Future<T> medir<T>(
    String operacion,
    Future<T> Function() ejecutar,
  ) async {
    if (!kDebugMode) return ejecutar();
    final etiqueta = '#${++_secuencia} $operacion';
    final reloj = Stopwatch()..start();
    evento(etiqueta, 'INICIO');
    final aviso = Timer(
      const Duration(seconds: 5),
      () => evento(etiqueta, 'ESPERANDO | ${reloj.elapsedMilliseconds}ms'),
    );
    try {
      final resultado = await ejecutar();
      evento(etiqueta, 'FIN | ${reloj.elapsedMilliseconds}ms');
      return resultado;
    } catch (fallo, stack) {
      error(etiqueta, fallo, stack, reloj.elapsedMilliseconds);
      rethrow;
    } finally {
      aviso.cancel();
      reloj.stop();
    }
  }
}
