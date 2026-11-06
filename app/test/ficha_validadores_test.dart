import 'package:flutter_test/flutter_test.dart';
import 'package:sitra_luz/features/fichas/domain/entities/ficha_catalogo_entities.dart';
import 'package:sitra_luz/features/fichas/domain/ficha_borrador.dart';
import 'package:sitra_luz/features/fichas/domain/ficha_validadores.dart';

void main() {
  group('HU-003 · Validación de Ficha General y Ficha Neonatología', () {
    const itemValido = FichaItemBorrador(
      medicamentoId: '11111111-1111-4111-8111-111111111111',
      nombreComercial: 'Paracetamol 500mg',
      categoriaItem: 'MEDICAMENTO',
      cantidad: 2,
      farmaciaDisponible: 20,
    );

    test('acepta una Ficha General completa con seguro y personal receptor', () {
      final borrador = FichaBorrador(
        tipoFicha: 'GENERAL',
        areaOrigen: 'SOP',
        turno: 'DIA',
        prioridad: 'NORMAL',
        tipoAtencion: 'SEGURO',
        financiamientoId: '22222222-2222-4222-8222-222222222222',
        doctorId: '33333333-3333-4333-8333-333333333333',
        doctorNombre: 'Dr. Carlos Mendoza',
        receptorId: '44444444-4444-4444-8444-444444444444',
        recibidoPor: 'Lic. Ana Torres',
        pacienteNombre: 'Juan Pérez Gómez',
        procedencia: 'EMERGENCIA',
        diagnosticoMotivo: 'Apendicitis aguda',
        items: const [itemValido],
      );

      expect(FichaValidadores.validarBorrador(borrador), isNull);
    });

    test('exige detalle de procedencia cuando se selecciona OTRO en Ficha General', () {
      final borrador = FichaBorrador(
        tipoFicha: 'GENERAL',
        areaOrigen: 'SOP',
        turno: 'DIA',
        prioridad: 'NORMAL',
        tipoAtencion: 'PARTICULAR',
        doctorNombre: 'Dr. Carlos Mendoza',
        recibidoPor: 'Lic. Ana Torres',
        pacienteNombre: 'Juan Pérez Gómez',
        procedencia: 'OTRO',
        procedenciaDetalle: '',
        diagnosticoMotivo: 'Observación clínica',
        items: const [itemValido],
      );

      expect(
        FichaValidadores.validarBorrador(borrador),
        contains('detalle de procedencia'),
      );
    });

    test('acepta una Ficha de Neonatología con madre, apellidos RN y tipo de parto', () {
      final borrador = FichaBorrador(
        tipoFicha: 'NEONATOLOGIA',
        areaOrigen: 'NEONATOLOGIA',
        turno: 'NOCHE',
        prioridad: 'URGENTE',
        tipoAtencion: 'PARTICULAR',
        doctorNombre: 'Dra. Elena Quispe',
        recibidoPor: 'Lic. María Vargas',
        madreNombre: 'Lucía Flores Mamani',
        habitacion: 'Cuna 04',
        recienNacidoApellidos: 'Rojas Flores',
        tipoParto: 'CESAREA',
        items: const [itemValido],
      );

      expect(FichaValidadores.validarBorrador(borrador), isNull);
      final mapa = borrador.toMap();
      expect(mapa['tipo_ficha'], equals('NEONATOLOGIA'));
      expect(mapa['madre_nombre'], equals('Lucía Flores Mamani'));
      expect(mapa['recien_nacido_apellidos'], equals('Rojas Flores'));
      expect(mapa['tipo_parto'], equals('CESAREA'));
    });

    test('separa medicamentos y dispositivos médicos en secciones diferenciadas', () {
      final borrador = FichaBorrador(
        items: const [
          FichaItemBorrador(
            medicamentoId: 'med-1',
            nombreComercial: 'Ceftriaxona 1g',
            categoriaItem: 'MEDICAMENTO',
            cantidad: 1,
            farmaciaDisponible: 10,
          ),
          FichaItemBorrador(
            medicamentoId: 'ins-1',
            nombreComercial: 'Jeringa Descartable 10mL',
            categoriaItem: 'DISPOSITIVO_MEDICO',
            cantidad: 3,
            farmaciaDisponible: 50,
          ),
        ],
      );

      expect(borrador.medicamentos.length, equals(1));
      expect(borrador.dispositivosMedicos.length, equals(1));
      expect(
        borrador.dispositivosMedicos.first.nombreComercial,
        equals('Jeringa Descartable 10mL'),
      );
    });
  });

  group('HU-004 · Selección de productos con stock disponible en Farmacia', () {
    test('deshabilita selección individual cuando stock en Farmacia es 0 aunque exista en Almacén', () {
      const productoSinStockFarmacia = MedicamentoStockFicha(
        id: 'med-sin-stock',
        nombre: 'Atropina 1mg/mL',
        unidad: 'AMPOLLA',
        categoria: 'MEDICAMENTO',
        activo: true,
        farmaciaDisponible: 0,
        almacenDisponible: 40,
        enTransito: 5,
      );

      expect(productoSinStockFarmacia.seleccionableIndividualmente, isFalse);
    });

    test('rechaza cantidad solicitada superior al stock disponible en Farmacia', () {
      const itemExcedido = FichaItemBorrador(
        medicamentoId: 'med-1',
        nombreComercial: 'Midazolam 5mg',
        cantidad: 8,
        farmaciaDisponible: 5,
        origenKit: false,
      );

      expect(
        FichaValidadores.validarItems(const [itemExcedido]),
        contains('supera el stock disponible en Farmacia'),
      );
    });
  });

  group('HU-005 · Aplicación de kit como copia independiente y editable', () {
    final kitOriginal = KitDisponibleFicha(
      id: 'kit-sop-1',
      nombre: 'Kit Cesárea SOP',
      areaDestino: 'SOP',
      areaNombre: 'Sala de Operaciones',
      items: const [
        KitItemFicha(
          medicamentoId: 'med-1',
          nombreComercial: 'Cefazolina 1g',
          unidad: 'FRASCO',
          categoria: 'MEDICAMENTO',
          cantidad: 2,
          activo: true,
          farmaciaDisponible: 15,
          almacenDisponible: 30,
          enTransito: 0,
        ),
        KitItemFicha(
          medicamentoId: 'ins-1',
          nombreComercial: 'Guantes Quirúrgicos N° 7.5',
          unidad: 'PAR',
          categoria: 'DISPOSITIVO_MEDICO',
          cantidad: 4,
          activo: true,
          farmaciaDisponible: 25,
          almacenDisponible: 100,
          enTransito: 0,
        ),
      ],
    );

    test('copia los ítems del kit al borrador y permite editarlos sin alterar la plantilla del kit', () {
      final borradorConKit = FichaBorrador(areaOrigen: 'SOP').aplicarKit(
        kitOriginal,
      );

      expect(borradorConKit.kitId, equals('kit-sop-1'));
      expect(borradorConKit.items.length, equals(2));
      expect(borradorConKit.items.every((i) => i.origenKit), isTrue);

      // Edita cantidad y quita un ítem en la ficha
      final borradorEditado = borradorConKit
          .cambiarCantidadItem('med-1', 5)
          .quitarItem('ins-1');

      expect(borradorEditado.items.length, equals(1));
      expect(borradorEditado.items.first.cantidad, equals(5));

      // La plantilla original del kit permanece intacta
      expect(kitOriginal.items.length, equals(2));
      expect(kitOriginal.items.first.cantidad, equals(2));
    });
  });
}
