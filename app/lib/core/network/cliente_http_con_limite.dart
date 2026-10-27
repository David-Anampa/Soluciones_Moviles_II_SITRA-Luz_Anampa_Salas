import 'dart:async';
import 'package:http/http.dart' as http;
import 'diagnostico_red.dart';

/// Limita Auth y consultas REST antes de que sus SDK procesen una respuesta tardía.
/// No cancela ni reintenta escrituras: un timeout no significa rollback del servidor.
class ClienteHttpConLimite extends http.BaseClient {
  final http.Client _cliente;
  final Duration limite;
  ClienteHttpConLimite({
    http.Client? cliente,
    this.limite = const Duration(seconds: 20),
  }) : _cliente = cliente ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final conLimite =
        request.url.path.startsWith('/auth/v1/') ||
        request.url.path.startsWith('/rest/v1/');
    // Solo método/ruta: omitir query, headers y cuerpo que contienen credenciales.
    final operacion = 'HTTP ${request.method} ${request.url.path}';
    final respuesta = await DiagnosticoRed.medir(
      operacion,
      () => conLimite
          ? _cliente.send(request).timeout(limite)
          : _cliente.send(request),
    );
    DiagnosticoRed.evento(operacion, 'RESPUESTA HTTP ${respuesta.statusCode}');
    return http.StreamedResponse(
      _leerCuerpo(respuesta, operacion, conLimite),
      respuesta.statusCode,
      contentLength: respuesta.contentLength,
      request: respuesta.request,
      headers: respuesta.headers,
      isRedirect: respuesta.isRedirect,
      persistentConnection: respuesta.persistentConnection,
      reasonPhrase: respuesta.reasonPhrase,
    );
  }

  /// Registra también un cuerpo detenido: recibir cabeceras no termina la lectura.
  Stream<List<int>> _leerCuerpo(
    http.StreamedResponse respuesta,
    String operacion,
    bool conLimite,
  ) async* {
    final reloj = Stopwatch()..start();
    try {
      final cuerpo = conLimite
          ? respuesta.stream.timeout(limite)
          : respuesta.stream;
      await for (final bytes in cuerpo) {
        yield bytes;
      }
      DiagnosticoRed.evento(
        operacion,
        'CUERPO RECIBIDO | ${reloj.elapsedMilliseconds}ms',
      );
    } catch (error, stack) {
      DiagnosticoRed.error(operacion, error, stack, reloj.elapsedMilliseconds);
      rethrow;
    } finally {
      reloj.stop();
    }
  }

  @override
  void close() => _cliente.close();
}
