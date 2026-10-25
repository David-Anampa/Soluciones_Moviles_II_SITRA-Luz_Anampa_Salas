import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sitra_luz/features/almacen/data/datasources/almacen_remote_datasource.dart';

/// Servidor HTTP exclusivamente local: ninguna prueba usa credenciales ni datos
/// de Supabase remoto. Comprueba el contrato de transporte, no ejecuta SQL.
void main() {
  const usuarioId = '11111111-1111-4111-8111-111111111111';
  const pedidoId = '22222222-2222-4222-8222-222222222222';
  const medicamentoId = '33333333-3333-4333-8333-333333333333';
  const itemId = '44444444-4444-4444-8444-444444444444';
  late HttpServer servidor;
  late SupabaseClient cliente;
  late AlmacenRemoteDataSource fuente;
  late List<({String ruta, String metodo, dynamic cuerpo})> peticiones;
  String? falloEn;
  var estadoFallo = HttpStatus.badRequest;
  var codigoFallo = 'P0001';
  var mensajeFallo = 'Operación rechazada por el servidor.';

  setUp(() async {
    peticiones = [];
    falloEn = null;
    estadoFallo = HttpStatus.badRequest;
    codigoFallo = 'P0001';
    mensajeFallo = 'Operación rechazada por el servidor.';
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    servidor.listen((request) async {
      final texto = await utf8.decoder.bind(request).join();
      final cuerpo = texto.isEmpty ? null : jsonDecode(texto);
      final ruta = request.uri.path;
      peticiones.add((ruta: ruta, metodo: request.method, cuerpo: cuerpo));
      request.response.headers.contentType = ContentType.json;
      if (ruta == falloEn) {
        request.response.statusCode = estadoFallo;
        request.response.write(
          jsonEncode({
            'code': codigoFallo,
            'message': mensajeFallo,
            'details': null,
            'hint': null,
          }),
        );
      } else if (ruta == '/rest/v1/pedidos_abastecimiento') {
        request.response.statusCode = HttpStatus.created;
        request.response.write(
          jsonEncode({
            ...(cuerpo as Map<String, dynamic>),
            'id': pedidoId,
            'fecha_solicitud': '2026-10-25T12:00:00Z',
          }),
        );
      } else if (ruta == '/rest/v1/pedidos_abastecimiento_items' ||
          ruta == '/rest/v1/auditoria_trazabilidad' ||
          ruta == '/rest/v1/rpc/procesar_pedido_abastecimiento') {
        request.response.statusCode = HttpStatus.noContent;
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(
          jsonEncode({'message': 'Ruta de prueba inesperada.'}),
        );
      }
      await request.response.close();
    });
    cliente = SupabaseClient(
      'http://127.0.0.1:${servidor.port}',
      'clave-local-de-prueba',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    fuente = AlmacenRemoteDataSource(client: cliente);
  });

  tearDown(() async {
    await cliente.dispose();
    await servidor.close(force: true);
  });

  Future<void> iniciarSesionLocal() async {
    // Solo restaura una sesión ficticia en memoria; no inicia sesión en un servicio.
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'sub': usuarioId,
              'role': 'authenticated',
              'exp': 4102444800,
            }),
          ),
        )
        .replaceAll('=', '');
    await cliente.auth.setInitialSession(
      jsonEncode({
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.firma-local',
        'token_type': 'bearer',
        'user': {
          'id': usuarioId,
          'aud': 'authenticated',
          'created_at': '2026-10-25T00:00:00Z',
        },
      }),
    );
  }

  Future<void> crear() async {
    await fuente.crearPedidoAbastecimiento(
      areaDestino: 'ALMACEN',
      turno: 'NOCHE',
      justificacion: 'Faltantes de guardia',
      notas: 'Priorizar reposición',
      items: {medicamentoId: 50},
    );
  }

  group('HU-029: creación y auditoría del cliente', () {
    test(
      'sin sesión rechaza la solicitud antes de enviar peticiones',
      () async {
        await expectLater(crear(), throwsA(isA<AlmacenException>()));
        expect(peticiones, isEmpty);
      },
    );

    test(
      'utiliza el solicitante autenticado y registra CREACION_PEDIDO',
      () async {
        await iniciarSesionLocal();
        await crear();
        expect(peticiones.length, 3);
        final cabecera = peticiones.first.cuerpo as Map<String, dynamic>;
        expect(cabecera['solicitante_id'], usuarioId);
        expect(cabecera['estado'], 'PENDIENTE');
        expect(cabecera['turno'], 'NOCHE');
        expect(cabecera['justificacion'], 'Faltantes de guardia');
        expect(peticiones[1].cuerpo, [
          {
            'pedido_id': pedidoId,
            'medicamento_id': medicamentoId,
            'cantidad_solicitada': 50,
          },
        ]);
        final auditoria = peticiones.last.cuerpo as Map<String, dynamic>;
        expect(peticiones.last.ruta, '/rest/v1/auditoria_trazabilidad');
        expect(auditoria['tipo_evento'], 'CREACION_PEDIDO');
        expect(auditoria['usuario_id'], usuarioId);
        expect(auditoria['entidad_referencia_id'], pedidoId);
        expect(auditoria['area_origen'], 'FARMACIA');
        expect(auditoria['area_destino'], 'ALMACEN');
      },
    );

    for (final tabla in [
      'pedidos_abastecimiento',
      'pedidos_abastecimiento_items',
      'auditoria_trazabilidad',
    ]) {
      test('el fallo en $tabla se comunica sin devolver éxito', () async {
        await iniciarSesionLocal();
        falloEn = '/rest/v1/$tabla';
        await expectLater(crear(), throwsA(isA<AlmacenException>()));
        expect(peticiones.last.ruta, falloEn);
      });
    }
  });

  group('HU-030: contrato de acciones transaccionales', () {
    final acciones = <String, Future<void> Function()>{
      'TOMAR': () => fuente.tomarPedidoAbastecimiento(pedidoId),
      'CANCELAR': () => fuente.cancelarPedidoAbastecimiento(
        pedidoId: pedidoId,
        motivo: 'Duplicado de turno',
      ),
      'RECHAZAR': () => fuente.rechazarPedidoAbastecimiento(
        pedidoId: pedidoId,
        motivo: 'Sin stock',
      ),
      'DESPACHAR': () => fuente.despacharPedidoAbastecimiento(
        pedidoId: pedidoId,
        cantidadesDespachadas: {itemId: 50},
        modalidadEntrega: 'ENTREGA',
        notasDespacho: 'Despacho completo',
      ),
      'RECIBIR': () => fuente.marcarConfirmacionFarmacia(pedidoId),
    };
    for (final entrada in acciones.entries) {
      test(
        '${entrada.key} usa una sola RPC, sin escritura directa de tablas',
        () async {
          await iniciarSesionLocal();
          await entrada.value();
          expect(peticiones.length, 1);
          final peticion = peticiones.single;
          expect(peticion.ruta, '/rest/v1/rpc/procesar_pedido_abastecimiento');
          expect(peticion.metodo, 'POST');
          expect(peticion.cuerpo['p_pedido_id'], pedidoId);
          expect(peticion.cuerpo['p_accion'], entrada.key);
          if (entrada.key == 'DESPACHAR') {
            expect(peticion.cuerpo['p_cantidades'], {itemId: 50});
            expect(peticion.cuerpo['p_modalidad'], 'ENTREGA');
            expect(peticion.cuerpo['p_notas'], 'Despacho completo');
          }
          if (entrada.key == 'CANCELAR') {
            expect(peticion.cuerpo['p_motivo'], 'Duplicado de turno');
          }
          if (entrada.key == 'RECIBIR') {
            expect(peticion.cuerpo['p_cantidades'], isEmpty);
          }
        },
      );
    }

    test(
      'la devolución envía aceptadas y motivo sin reescribir el despacho',
      () async {
        await iniciarSesionLocal();
        await fuente.confirmarRecepcionConAjuste(
          pedidoId: pedidoId,
          cantidadesAceptadas: {itemId: 10},
          motivoObservacion: 'Exceso de 40',
        );
        expect(peticiones.length, 1);
        expect(peticiones.single.cuerpo['p_accion'], 'RECIBIR');
        expect(peticiones.single.cuerpo['p_cantidades'], {itemId: 10});
        expect(peticiones.single.cuerpo['p_motivo'], 'Exceso de 40');
      },
    );

    for (final faltaRpc in [false, true]) {
      test(
        '${faltaRpc ? 'RPC ausente' : 'rechazo por permisos'} se propaga sin alternativa de escritura',
        () async {
          await iniciarSesionLocal();
          falloEn = '/rest/v1/rpc/procesar_pedido_abastecimiento';
          estadoFallo = faltaRpc ? HttpStatus.notFound : HttpStatus.forbidden;
          codigoFallo = faltaRpc ? 'PGRST202' : '42501';
          mensajeFallo = faltaRpc
              ? 'Función no encontrada.'
              : 'Su rol no puede realizar esta acción.';
          await expectLater(
            fuente.tomarPedidoAbastecimiento(pedidoId),
            throwsA(
              isA<AlmacenException>().having(
                (e) => e.message,
                'mensaje',
                mensajeFallo,
              ),
            ),
          );
          expect(peticiones.length, 1);
        },
      );
    }

    test(
      'las rutas antiguas no permiten marcar listo sin despacho real',
      () async {
        await expectLater(
          fuente.marcarPedidoListo(pedidoId, 'RECOJO'),
          throwsA(isA<AlmacenException>()),
        );
        await expectLater(
          fuente.marcarConfirmacionAlmacen(pedidoId),
          throwsA(isA<AlmacenException>()),
        );
        await expectLater(
          fuente.atenderSolicitudAbastecimiento(pedidoId: pedidoId),
          throwsA(isA<AlmacenException>()),
        );
        expect(peticiones, isEmpty);
      },
    );
  });
}
