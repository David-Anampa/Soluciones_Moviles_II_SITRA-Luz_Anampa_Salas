import 'package:flutter_test/flutter_test.dart';
import 'package:sitra_luz/features/fichas/domain/entities/ficha_catalogo_entities.dart';
import 'package:sitra_luz/features/fichas/domain/ficha_validadores.dart';

void main() {
  group('Sprint 7 · HU-006 y HU-007 (David Anampa) + Contrato HU-025', () {
    test('FiltrosListadoFichas detecta filtros activos y aplica copyWith', () {
      const base = FiltrosListadoFichas();
      expect(base.tieneFiltrosActivos, isFalse);

      final filtrado = base.copyWith(
        area: 'NEONATOLOGIA',
        estado: 'SOLICITADO',
        prioridad: 'URGENTE',
      );
      expect(filtrado.tieneFiltrosActivos, isTrue);
      expect(filtrado.area, 'NEONATOLOGIA');
      expect(filtrado.estado, 'SOLICITADO');
      expect(filtrado.prioridad, 'URGENTE');
    });

    test(
      'FichaRegistrada.fromMap reconstruye detalle completo, lotes FEFO e historial (HU-007)',
      () {
        final ficha = FichaRegistrada.fromMap({
          'id': 'ficha-001',
          'numero_ficha': 'FCH-2026-00042',
          'tipo': 'KIT',
          'tipo_ficha': 'NEONATOLOGIA',
          'kit_id': 'kit-neo-1',
          'kit_nombre': 'Kit Atención Inmediata RN',
          'area_origen': 'NEONATOLOGIA',
          'area_nombre': 'Neonatología',
          'area_tema_color': 'CELESTE',
          'turno': 'NOCHE',
          'prioridad': 'URGENTE',
          'estado': 'ENTREGADO',
          'tipo_atencion': 'SEGURO',
          'financiamiento_id': 'fin-pacifico',
          'financiamiento_nombre_aplicado': 'Pacífico Seguros',
          'doctor_nombre': 'Dra. Elena Vargas',
          'recibido_por': 'Lic. Sofía Ramos',
          'paciente_nombre': 'RN Paredes Gómez (Madre: Lucía Gómez)',
          'madre_nombre': 'Lucía Gómez',
          'habitacion': '304-B',
          'recien_nacido_apellidos': 'Paredes Gómez',
          'tipo_parto': 'CESAREA',
          'fecha_creacion': '2026-11-12T08:00:00Z',
          'fecha_preparacion': '2026-11-12T08:05:00Z',
          'fecha_listo_recojo': '2026-11-12T08:10:00Z',
          'fecha_entrega': '2026-11-12T08:15:00Z',
          'items': [
            {
              'id': 'item-1',
              'medicamento_id': 'med-1',
              'nombre_comercial': 'Fitomenadiona 10mg/mL',
              'presentacion': 'Ampolla 1mL',
              'laboratorio': 'Sanderson',
              'unidad': 'AMPOLLA',
              'categoria_item': 'MEDICAMENTO',
              'cantidad_solicitada': 2,
              'cantidad_entregada': 2,
              'origen_kit': true,
              'precio_kairos_aplicado': 12.0,
              'porcentaje_descuento_aplicado': 10.0,
              'precio_unitario_aplicado': 10.8,
              'farmacia_disponible': 18,
              'lotes_despachados': [
                {
                  'id': 'dil-1',
                  'lote_id': 'lote-a',
                  'numero_lote': 'LT-2026-A',
                  'fecha_vencimiento': '2027-03-15',
                  'cantidad': 2,
                  'cantidad_reingresada': 0,
                },
              ],
            },
            {
              'id': 'item-2',
              'medicamento_id': 'med-2',
              'nombre_comercial': 'Clamp Umbilical Estéril',
              'unidad': 'UNIDAD',
              'categoria_item': 'DISPOSITIVO_MEDICO',
              'cantidad_solicitada': 2,
              'cantidad_entregada': 1,
              'observacion_item': 'Stock parcial en Farmacia (1 de 2)',
              'origen_kit': true,
              'precio_unitario_aplicado': 4.5,
              'farmacia_disponible': 0,
            },
          ],
          'historial': [
            {
              'id': 'ev-1',
              'tipo_evento': 'FICHA_CREADA',
              'fecha_evento': '2026-11-12T08:00:00Z',
              'usuario_nombre': 'Lic. Sofía Ramos',
              'usuario_rol': 'ENFERMERIA',
              'descripcion': 'Registro de ficha FCH-2026-00042',
            },
            {
              'id': 'ev-2',
              'tipo_evento': 'CONSUMO_FICHA_AREA',
              'fecha_evento': '2026-11-12T08:15:00Z',
              'usuario_nombre': 'Q.F. Walter Salas',
              'usuario_rol': 'FARMACIA',
              'numero_lote': 'LT-2026-A',
              'cantidad': 2,
              'descripcion': 'Despacho FEFO de 2 und.',
            },
          ],
        });

        expect(ficha.esNeonatologia, isTrue);
        expect(ficha.esUrgente, isTrue);
        expect(ficha.medicamentos.length, 1);
        expect(ficha.dispositivosMedicos.length, 1);
        expect(ficha.totalUnidadesSolicitadas, 4);
        expect(ficha.totalUnidadesEntregadas, 3);
        expect(ficha.tieneDespachoParcial, isTrue);
        expect(ficha.medicamentos.first.lotesDespachados.length, 1);
        expect(
          ficha.medicamentos.first.lotesDespachados.first.numeroLote,
          'LT-2026-A',
        );
        expect(ficha.historial.length, 2);
        expect(ficha.historial.last.etiquetaEvento, 'Descuento por lote (FEFO)');
        expect(ficha.montoTotalSolicitado, closeTo(30.6, 0.001));
        expect(ficha.montoTotalEntregado, closeTo(26.1, 0.001));
      },
    );

    test(
      'Contrato HU-025 parsea movimientos de consumo FEFO y contra-asiento de reingreso',
      () {
        final salida = MovimientoKardexContratoHu025.fromMap({
          'id': 'k-1',
          'tipo_evento': 'CONSUMO_FICHA_AREA',
          'naturaleza_movimiento': 'SALIDA',
          'usuario_nombre': 'Q.F. Walter Salas',
          'area_origen': 'FARMACIA',
          'area_destino': 'EMERGENCIA',
          'numero_lote': 'LT-901',
          'cantidad': 3,
          'numero_ficha': 'FCH-2026-00045',
          'descripcion': 'Despacho FEFO en ficha FCH-2026-00045',
        });
        expect(salida.naturalezaMovimiento, 'SALIDA');
        expect(salida.numeroFicha, 'FCH-2026-00045');

        final reingreso = MovimientoKardexContratoHu025.fromMap({
          'id': 'k-2',
          'tipo_evento': 'REINGRESO_ANULACION_FICHA',
          'naturaleza_movimiento': 'ENTRADA',
          'usuario_nombre': 'Q.F. Walter Salas',
          'area_origen': 'EMERGENCIA',
          'area_destino': 'FARMACIA',
          'numero_lote': 'LT-901',
          'cantidad': 3,
          'numero_ficha': 'FCH-2026-00045',
          'descripcion': 'Contra-asiento de reingreso a Farmacia',
        });
        expect(reingreso.naturalezaMovimiento, 'ENTRADA');
        expect(reingreso.cantidad, 3);
      },
    );
  });

  group('Sprint 7 · HU-008 a HU-011 (Walter Salas): Estados, Despacho, FEFO y Anulación', () {
    FichaRegistrada crearFichaConEstado(String estado) {
      return FichaRegistrada(
        id: 'ficha-test',
        numeroFicha: 'FCH-2026-00100',
        tipo: 'INDIVIDUAL',
        tipoFicha: 'GENERAL',
        areaOrigen: 'EMERGENCIA',
        areaNombre: 'Emergencia',
        areaTemaColor: 'ROJO',
        turno: 'DIA',
        prioridad: 'NORMAL',
        estado: estado,
        tipoAtencion: 'PARTICULAR',
        pacienteNombre: 'Juan Pérez',
        fechaCreacion: DateTime(2026, 11, 12),
        items: const [],
      );
    }

    test('HU-009: exige observación cuando existe despacho parcial y valida stock vigente', () {
      const itemParcialSinObs = ItemDespachoEdicion(
        itemId: 'i-1',
        medicamentoId: 'm-1',
        nombreComercial: 'Ceftriaxona 1g',
        cantidadSolicitada: 4,
        cantidadEntregada: 2,
        farmaciaDisponible: 10,
        observacionItem: '',
      );

      final errSinObs = FichaValidadores.validarDespachoItems([itemParcialSinObs]);
      expect(errSinObs, isNotNull);
      expect(errSinObs, contains('despacho parcial'));

      final itemParcialConObs = itemParcialSinObs.copyWith(
        observacionItem: 'Stock parcial asignado por turno',
      );
      expect(
        FichaValidadores.validarDespachoItems([itemParcialConObs]),
        isNull,
      );

      final itemSuperaStock = itemParcialConObs.copyWith(
        cantidadEntregada: 4,
        farmaciaDisponible: 2,
      );
      final errStock = FichaValidadores.validarDespachoItems([itemSuperaStock]);
      expect(errStock, isNotNull);
      expect(errStock, contains('Stock insuficiente en Farmacia'));
    });

    test('HU-008 y HU-010: valida permisos por rol y bloquea doble entrega', () {
      final solicitada = crearFichaConEstado('SOLICITADO');
      expect(
        FichaValidadores.validarTransicionAtencion(
          ficha: solicitada,
          accion: 'INICIAR_PREPARACION',
          rol: 'ENFERMERIA',
          areasUsuario: const ['EMERGENCIA'],
        ),
        isNotNull,
      );
      expect(
        FichaValidadores.validarTransicionAtencion(
          ficha: solicitada,
          accion: 'INICIAR_PREPARACION',
          rol: 'FARMACIA',
        ),
        isNull,
      );

      final listaRecojo = crearFichaConEstado('LISTO_PARA_RECOJO');
      expect(
        FichaValidadores.validarTransicionAtencion(
          ficha: listaRecojo,
          accion: 'CONFIRMAR_ENTREGA',
          rol: 'ENFERMERIA',
          areasUsuario: const ['EMERGENCIA'],
        ),
        isNull,
      );
      expect(
        FichaValidadores.validarTransicionAtencion(
          ficha: listaRecojo,
          accion: 'CONFIRMAR_ENTREGA',
          rol: 'JEFATURA_FARMACIA',
        ),
        isNotNull,
      );

      final yaEntregada = crearFichaConEstado('ENTREGADO');
      final errDobleEntrega = FichaValidadores.validarTransicionAtencion(
        ficha: yaEntregada,
        accion: 'CONFIRMAR_ENTREGA',
        rol: 'FARMACIA',
      );
      expect(errDobleEntrega, isNotNull);
      expect(errDobleEntrega, contains('ya fue entregada'));
    });

    test('HU-011: valida motivo obligatorio y permisos de anulación según estado', () {
      expect(FichaValidadores.validarMotivoAnulacion('abc'), isNotNull);
      expect(
        FichaValidadores.validarMotivoAnulacion(
          'Cambio de indicación médica en sala de observación',
        ),
        isNull,
      );

      final solicitada = crearFichaConEstado('SOLICITADO');
      expect(
        FichaValidadores.validarTransicionAtencion(
          ficha: solicitada,
          accion: 'ANULAR_FICHA',
          rol: 'ENFERMERIA',
          areasUsuario: const ['EMERGENCIA'],
        ),
        isNull,
      );

      final enPreparacion = crearFichaConEstado('EN_PREPARACION');
      expect(
        FichaValidadores.validarTransicionAtencion(
          ficha: enPreparacion,
          accion: 'ANULAR_FICHA',
          rol: 'ENFERMERIA',
          areasUsuario: const ['EMERGENCIA'],
        ),
        isNotNull,
      );
      expect(
        FichaValidadores.validarTransicionAtencion(
          ficha: enPreparacion,
          accion: 'ANULAR_FICHA',
          rol: 'FARMACIA',
        ),
        isNull,
      );

      final entregada = crearFichaConEstado('ENTREGADO');
      expect(
        FichaValidadores.validarTransicionAtencion(
          ficha: entregada,
          accion: 'ANULAR_FICHA',
          rol: 'FARMACIA',
        ),
        isNull,
      );
    });
  });
}

