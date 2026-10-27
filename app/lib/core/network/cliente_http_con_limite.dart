import 'dart:async';
import 'package:http/http.dart' as http;

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
    if (!request.url.path.startsWith('/auth/v1/') &&
        !request.url.path.startsWith('/rest/v1/')) {
      return _cliente.send(request);
    }
    final respuesta = await _cliente.send(request).timeout(limite);
    return http.StreamedResponse(
      respuesta.stream.timeout(limite),
      respuesta.statusCode,
      contentLength: respuesta.contentLength,
      request: respuesta.request,
      headers: respuesta.headers,
      isRedirect: respuesta.isRedirect,
      persistentConnection: respuesta.persistentConnection,
      reasonPhrase: respuesta.reasonPhrase,
    );
  }

  @override
  void close() => _cliente.close();
}
