import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sitra_luz/features/almacen/domain/entities/stock_almacen_entity.dart';
import 'package:sitra_luz/features/almacen/domain/entities/lote_entity.dart';
import 'package:sitra_luz/features/almacen/domain/entities/medicamento_entity.dart';
import 'package:sitra_luz/features/almacen/data/models/pedido_abastecimiento_model.dart';
import 'package:sitra_luz/features/almacen/domain/entities/pedido_abastecimiento_entity.dart';
import 'package:sitra_luz/features/almacen/domain/repositories/almacen_repository.dart';
import 'package:sitra_luz/features/almacen/presentation/states/almacen_state.dart';
import 'package:sitra_luz/features/almacen/presentation/viewmodels/almacen_viewmodel.dart';
import 'package:sitra_luz/features/almacen/presentation/views/solicitudes_abastecimiento_view.dart';

class _Repository implements AlmacenRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ViewModel extends AlmacenViewModel {
  final PedidoAbastecimientoEntity pedido;
  _ViewModel(this.pedido) : super(repository: _Repository());
  String? accion;
  String? motivo;
  Map<String, int>? aceptadas;
  bool falla = false;
  String? modalidad;
  List<StockAlmacenEntity> inventario = [];

  @override
  AlmacenState get state => AlmacenLoaded(
    inventario: inventario,
    catalogo: const [],
    solicitudes: [pedido],
  );
  @override
  Future<bool> despacharPedidoAbastecimiento({
    required String pedidoId,
    required Map<String, int> cantidadesDespachadas,
    required String modalidadEntrega,
    String? notasDespacho,
  }) async {
    accion = 'DESPACHAR';
    aceptadas = cantidadesDespachadas;
    modalidad = modalidadEntrega;
    return !falla;
  }

  @override
  String? get errorMessage => 'El pedido ya fue tomado por Almacén.';
  @override
  Future<bool> cancelarPedidoAbastecimiento({
    required String pedidoId,
    required String motivo,
  }) async {
    accion = 'CANCELAR';
    this.motivo = motivo;
    return !falla;
  }

  @override
  Future<bool> rechazarPedidoAbastecimiento({
    required String pedidoId,
    required String motivo,
  }) async {
    accion = 'RECHAZAR';
    this.motivo = motivo;
    return !falla;
  }

  @override
  Future<bool> marcarConfirmacionFarmacia(String pedidoId) async {
    accion = 'CONFORME';
    return !falla;
  }

  @override
  Future<bool> confirmarRecepcionConAjuste({
    required String pedidoId,
    required Map<String, int> cantidadesAceptadas,
    required String motivoObservacion,
  }) async {
    accion = 'DEVOLVER';
    aceptadas = cantidadesAceptadas;
    motivo = motivoObservacion;
    return !falla;
  }
}

PedidoAbastecimientoEntity pedido(String estado) => PedidoAbastecimientoEntity(
  id: 'pedido',
  codigo: 'REQ-1791849000000',
  estado: estado,
  fechaSolicitud: DateTime(2026, 10, 12),
  confirmadoAlmacen: estado == 'LISTO',
  modalidadEntrega: estado == 'LISTO' ? 'ENTREGA' : null,
  items: const [
    PedidoAbastecimientoItemEntity(
      id: 'item',
      pedidoId: 'pedido',
      medicamentoId: 'med',
      nombreMedicamento: 'Ampollas para reposición de guardia',
      cantidadSolicitada: 50,
      cantidadDespachada: 50,
    ),
  ],
);

Future<_ViewModel> _abrir(
  WidgetTester tester,
  String estado, {
  bool farmacia = true,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final vm = _ViewModel(pedido(estado));
  await tester.pumpWidget(
    ChangeNotifierProvider<AlmacenViewModel>.value(
      value: vm,
      child: MaterialApp(
        home: SolicitudesAbastecimientoView(esModoFarmacia: farmacia),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (estado != 'PENDIENTE') {
    await tester.tap(find.text('En curso'));
    await tester.pumpAndSettle();
  }
  expect(tester.takeException(), isNull);
  return vm;
}

/// Las tarjetas y los motivos pueden superar la altura del teléfono de prueba.
/// Desplaza el control a la vista antes de pulsar y espera su animación/reconstrucción.
Future<void> _tocarVisible(WidgetTester tester, Finder control) async {
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'La recepción conserva el despacho original y calcula el contra-asiento',
    () {
      final item = PedidoAbastecimientoItemModel.fromMap({
        'cantidad_solicitada': 50,
        'cantidad_despachada': 50,
        'cantidad_recibida': 10,
      });
      expect(item.cantidadDespachada, 50);
      expect(item.cantidadRecibida, 10);
      expect(item.cantidadDevuelta, 40);
      expect(
        PedidoAbastecimientoItemModel.fromMap({
          'cantidad_despachada': 50,
        }).cantidadRecibida,
        isNull,
      );
    },
  );

  testWidgets(
    'Pendiente se cancela con motivo y permite crear una nueva solicitud',
    (tester) async {
      final vm = await _abrir(tester, 'PENDIENTE');
      await _tocarVisible(tester, find.text('Cancelar Solicitud'));
      await _tocarVisible(tester, find.text('Duplicado de turno'));
      await _tocarVisible(tester, find.text('Cancelar pedido'));
      expect(vm.accion, 'CANCELAR');
      expect(vm.motivo, 'Duplicado de turno');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Crear nueva'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Si Almacén tomó el pedido, se muestra el error y el diálogo permanece abierto',
    (tester) async {
      final vm = await _abrir(tester, 'PENDIENTE');
      vm.falla = true;
      await _tocarVisible(tester, find.text('Cancelar Solicitud'));
      await _tocarVisible(tester, find.text('Cancelar pedido'));
      expect(vm.accion, 'CANCELAR');
      expect(find.text(vm.errorMessage!), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Crear nueva'), findsNothing);
    },
  );

  testWidgets(
    'Farmacia en preparación debe coordinar físicamente y no puede cancelar',
    (tester) async {
      await _abrir(tester, 'EN_PREPARACION');
      expect(find.text('Cancelar Solicitud'), findsNothing);
      expect(
        find.textContaining('comuníquese físicamente con Almacén'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Almacén puede rechazar en preparación por coordinación con Farmacia',
    (tester) async {
      final vm = await _abrir(tester, 'EN_PREPARACION', farmacia: false);
      await tester.tap(find.text('Rechazar solicitud'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelación coordinada con Farmacia'));
      await tester.tap(find.text('Rechazar pedido'));
      await tester.pumpAndSettle();
      expect(vm.accion, 'RECHAZAR');
      expect(vm.motivo, 'Cancelación coordinada con Farmacia');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Solo Farmacia completa un pedido listo y puede recibir conforme', (
    tester,
  ) async {
    final vm = await _abrir(tester, 'LISTO');
    await tester.tap(find.text('Confirmar recepción física'));
    await tester.pumpAndSettle();
    // FilledButton.icon utiliza una subclase: byType(FilledButton) no la encuentra.
    // Se distingue el botón de confirmación del ChoiceChip con la misma etiqueta.
    final aceptar = find.ancestor(
      of: find.text('Aceptar conforme'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(aceptar, findsOneWidget);
    await _tocarVisible(tester, aceptar);
    expect(vm.accion, 'CONFORME');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Devuelve 40 de 50 y exige un motivo sin permitir aceptar más de lo despachado',
    (tester) async {
      final vm = await _abrir(tester, 'LISTO');
      await tester.tap(find.text('Confirmar recepción física'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Devolver exceso'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '51');
      final confirmar = find.text('Confirmar devolución');
      await tester.ensureVisible(confirmar);
      await tester.tap(confirmar);
      await tester.pumpAndSettle();
      expect(vm.accion, isNull);
      await tester.enterText(find.byType(TextFormField).first, '10');
      await tester.ensureVisible(confirmar);
      await tester.tap(confirmar);
      await tester.pumpAndSettle();
      expect(vm.accion, isNull);
      await tester.enterText(
        find.byType(TextFormField).last,
        'Exceso solicitado por error de guardia',
      );
      await tester.ensureVisible(confirmar);
      await tester.tap(confirmar);
      await tester.pumpAndSettle();
      expect(vm.accion, 'DEVOLVER');
      expect(vm.aceptadas, {'item': 10});
      expect(vm.pedido.items.first.cantidadDespachada, 50);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Almacén después de despachar espera a Farmacia y no puede rechazar',
    (tester) async {
      await _abrir(tester, 'LISTO', farmacia: false);
      expect(find.text('Rechazar solicitud'), findsNothing);
      expect(find.text('Confirmar recepción física'), findsNothing);
      expect(find.textContaining('Esperando la confirmación'), findsOneWidget);
    },
  );
  testWidgets(
    'Despacho exige tomar el pedido y no permite transferir cero unidades',
    (tester) async {
      await _abrir(tester, 'PENDIENTE', farmacia: false);
      expect(find.text('Atender y despachar'), findsNothing);
      final vm = await _abrir(tester, 'EN_PREPARACION', farmacia: false);
      await tester.tap(find.text('Atender y despachar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar despacho'));
      await tester.pumpAndSettle();
      expect(vm.accion, isNull);
      expect(
        find.textContaining('No hay unidades a despachar'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Almacén elige entrega y conserva el diálogo ante un fallo de despacho',
    (tester) async {
      final vm = await _abrir(tester, 'EN_PREPARACION', farmacia: false);
      vm.inventario = [
        StockAlmacenEntity(
          id: 'stock',
          loteId: 'lote',
          cantidad: 50,
          updatedAt: DateTime.now(),
          medicamento: const MedicamentoEntity(
            id: 'med',
            gtin: 'prueba',
            nombreComercial: 'Ampollas',
            principioActivo: 'Prueba',
            presentacion: 'Ampolla',
          ),
          lote: LoteEntity(
            id: 'lote',
            medicamentoId: 'med',
            numeroLote: 'L1',
            fechaVencimiento: DateTime.now().add(const Duration(days: 90)),
          ),
        ),
      ];
      vm.falla = true;
      vm.notifyListeners();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Atender y despachar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Almacén entrega'));
      await tester.tap(find.text('Almacén entrega'));
      await tester.tap(find.text('Confirmar despacho'));
      await tester.pumpAndSettle();
      expect(vm.accion, 'DESPACHAR');
      expect(vm.modalidad, 'ENTREGA');
      expect(vm.aceptadas, {'item': 50});
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(vm.errorMessage!), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
