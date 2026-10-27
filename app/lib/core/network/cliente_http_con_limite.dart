import 'dart:async';
import 'package:http/http.dart' as http;
import 'diagnostico_red.dart';

/// Limita Auth y consultas REST antes de que sus SDK procesen una respuesta tardía.
/// Cierra el transporte agotado. No reintenta escrituras ni asegura rollback remoto.
class ClienteHttpConLimite extends http.BaseClient {
  final http.Client? _cliente;
  final http.Client Function() _crearCliente;
  final _activos = <http.Client>{};
  bool _cerrado = false;
  final Duration limite;
  ClienteHttpConLimite({
    http.Client? cliente,
    http.Client Function()? crearCliente,
    this.limite = const Duration(seconds: 20),
  }) : _cliente = cliente,
       _crearCliente = crearCliente ?? http.Client.new;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_cerrado) throw http.ClientException('El cliente está cerrado.');
    // El transporte propio dura una petición: un socket bloqueado no se reutiliza.
    final transporte = _cliente ?? _crearCliente();
    final propio = _cliente == null;
    if (propio) _activos.add(transporte);
    final conLimite =
        request.url.path.startsWith('/auth/v1/') ||
        request.url.path.startsWith('/rest/v1/');
    // Solo método/ruta: omitir query, headers y cuerpo que contienen credenciales.
    final operacion = 'HTTP ${request.method} ${request.url.path}';
    final http.StreamedResponse respuesta;
    try {
      respuesta = await DiagnosticoRed.medir(
        operacion,
        () => conLimite
            ? transporte.send(request).timeout(limite)
            : transporte.send(request),
      );
    } catch (_) {
      if (propio) _liberar(transporte);
      rethrow;
    }
    DiagnosticoRed.evento(operacion, 'RESPUESTA HTTP ${respuesta.statusCode}');
    return http.StreamedResponse(
      _leerCuerpo(
        respuesta,
        operacion,
        conLimite,
        propio ? () => _liberar(transporte) : () {},
      ),
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
    void Function() liberar,
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
      liberar();
    }
  }

  /// Libera únicamente el transporte de esta petición, al fallar o terminar el cuerpo.
  void _liberar(http.Client cliente) {
    if (_activos.remove(cliente)) cliente.close();
  }

  @override
  void close() {
    if (_cerrado) return;
    _cerrado = true;
    _cliente?.close();
    for (final cliente in _activos.toList()) {
      _liberar(cliente);
    }
  }
}
