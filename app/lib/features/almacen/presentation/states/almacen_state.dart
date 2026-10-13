import '../../domain/entities/stock_almacen_entity.dart';
import '../../domain/entities/medicamento_entity.dart';
import '../../domain/entities/pedido_abastecimiento_entity.dart';

/// Estado sellado de la interfaz de Almacén
sealed class AlmacenState {
  const AlmacenState();
}

/// Estado inicial antes de cargar datos
class AlmacenInitial extends AlmacenState {
  const AlmacenInitial();
}

/// Estado de carga (consultando inventario en Supabase)
class AlmacenLoading extends AlmacenState {
  const AlmacenLoading();
}

/// Estado con datos de inventario y solicitudes cargados exitosamente
class AlmacenLoaded extends AlmacenState {
  final List<StockAlmacenEntity> inventario;
  final List<MedicamentoEntity> catalogo;
  final List<PedidoAbastecimientoEntity> solicitudes;

  const AlmacenLoaded({
    required this.inventario,
    required this.catalogo,
    this.solicitudes = const [],
  });

  /// Total de unidades físicas en stock
  int get totalUnidades => inventario.fold(0, (sum, item) => sum + item.cantidad);

  /// HU-030: Cantidad de solicitudes de abastecimiento pendientes por atender.
  int get solicitudesPendientes {
    try {
      return (solicitudes).where((s) => s.esPendiente).length;
    } catch (_) {
      return 0;
    }
  }

  /// Cantidad de lotes en estado crítico (< 30 días de vencimiento)
  int get lotesCriticos =>
      inventario.where((item) => item.lote.diasParaVencer <= 30 && item.lote.diasParaVencer > 0).length;

  /// Cantidad de lotes vencidos
  int get lotesVencidos =>
      inventario.where((item) => item.lote.diasParaVencer <= 0).length;

  /// Cantidad de medicamentos que requieren cadena de frío
  int get articulosCadenaFrio =>
      inventario.where((item) => item.medicamento.requiereCadenaFrio).length;
}

/// Estado de error
class AlmacenError extends AlmacenState {
  final String message;
  const AlmacenError(this.message);
}
