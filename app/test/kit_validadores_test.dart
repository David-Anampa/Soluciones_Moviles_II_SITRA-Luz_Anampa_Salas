import 'package:flutter_test/flutter_test.dart';
import 'package:sitra_luz/features/kits/domain/entities/kit_entity.dart';
import 'package:sitra_luz/features/kits/domain/entities/kit_item_entity.dart';
import 'package:sitra_luz/features/kits/domain/kit_borrador.dart';
import 'package:sitra_luz/features/kits/domain/kit_validadores.dart';

void main() {
  group('KitValidadores - Validaciones unitarias HU-018 / HU-019', () {
    test('validarNombre rechaza valores vacíos o menores a 3 caracteres', () {
      expect(KitValidadores.validarNombre(null), 'Escribe el nombre del kit.');
      expect(KitValidadores.validarNombre(''), 'Escribe el nombre del kit.');
      expect(KitValidadores.validarNombre('   '), 'Escribe el nombre del kit.');
      expect(KitValidadores.validarNombre('AB'), 'El nombre debe tener al menos 3 caracteres.');
      expect(KitValidadores.validarNombre('  x  '), 'El nombre debe tener al menos 3 caracteres.');
    });

    test('validarNombre rechaza nombres de más de 120 caracteres', () {
      final largo = 'A' * 121;
      expect(KitValidadores.validarNombre(largo), 'El nombre no puede exceder 120 caracteres.');
    });

    test('validarNombre acepta nombres clínicos válidos', () {
      expect(KitValidadores.validarNombre('Kit Cirugía General'), isNull);
      expect(KitValidadores.validarNombre('Kit RCP - Adulto'), isNull);
      expect(KitValidadores.validarNombre('   Kit Suturas Menores   '), isNull);
    });

    test('validarArea valida selección obligatoria de área', () {
      expect(KitValidadores.validarArea(null), 'Selecciona el área de destino del kit.');
      expect(KitValidadores.validarArea(''), 'Selecciona el área de destino del kit.');
      expect(KitValidadores.validarArea('   '), 'Selecciona el área de destino del kit.');
      expect(KitValidadores.validarArea('SOP'), isNull);
      expect(KitValidadores.validarArea('EMERGENCIA'), isNull);
    });

    test('validarDescripcion admite vacío pero rechaza textos excesivamente largos', () {
      expect(KitValidadores.validarDescripcion(null), isNull);
      expect(KitValidadores.validarDescripcion(''), isNull);
      expect(KitValidadores.validarDescripcion('Uso en sala de operaciones para cesáreas.'), isNull);

      final textoLargo = 'D' * 301;
      expect(KitValidadores.validarDescripcion(textoLargo), 'La descripción no puede exceder 300 caracteres.');
    });

    test('validarItems rechaza listas vacías o ítems con cantidades inválidas', () {
      expect(KitValidadores.validarItems([]), 'Agrega al menos un medicamento o insumo al kit.');

      final itemCero = [
        const KitItemEntity(
          id: '1',
          medicamentoId: 'med-001',
          medicamentoNombre: 'Paracetamol 500mg',
          cantidad: 0,
        ),
      ];
      expect(KitValidadores.validarItems(itemCero), contains('debe ser mayor a 0'));

      final itemNegativo = [
        const KitItemEntity(
          id: '1',
          medicamentoId: 'med-001',
          medicamentoNombre: 'Amoxicilina 500mg',
          cantidad: -2,
        ),
      ];
      expect(KitValidadores.validarItems(itemNegativo), contains('debe ser mayor a 0'));
    });

    test('validarItems rechaza medicamentos duplicados en el mismo kit', () {
      final duplicados = [
        const KitItemEntity(
          id: '1',
          medicamentoId: 'med-001',
          medicamentoNombre: 'Fentanilo 0.5mg',
          cantidad: 2,
        ),
        const KitItemEntity(
          id: '2',
          medicamentoId: 'med-001',
          medicamentoNombre: 'Fentanilo 0.5mg',
          cantidad: 5,
        ),
      ];
      expect(KitValidadores.validarItems(duplicados), contains('está duplicado'));
    });

    test('validarItems acepta listas con medicamentos únicos y cantidades positivas', () {
      final validos = [
        const KitItemEntity(
          id: '1',
          medicamentoId: 'med-001',
          medicamentoNombre: 'Fentanilo 0.5mg',
          cantidad: 2,
        ),
        const KitItemEntity(
          id: '2',
          medicamentoId: 'med-002',
          medicamentoNombre: 'Suero Fisiológico 1000ml',
          cantidad: 3,
        ),
      ];
      expect(KitValidadores.validarItems(validos), isNull);
    });

    test('validarBorradorCompleto valida integralmente el kit', () {
      const borradorInvalido = KitBorrador(
        nombre: 'K',
        areaDestino: '',
        items: [],
      );
      expect(KitValidadores.validarBorradorCompleto(borradorInvalido), isNotNull);

      const borradorValido = KitBorrador(
        nombre: 'Kit Neonatología Básico',
        areaDestino: 'SOP',
        items: [
          KitItemEntity(
            id: '1',
            medicamentoId: 'med-neo-01',
            medicamentoNombre: 'Ampicilina 500mg',
            cantidad: 2,
          ),
        ],
      );
      expect(KitValidadores.validarBorradorCompleto(borradorValido), isNull);
    });
  });

  group('KitBorrador - Operaciones inmutables', () {
    test('agregarOActualizarItem suma cantidad si ya existe o agrega nuevo', () {
      var borrador = const KitBorrador();
      const item1 = KitItemEntity(
        id: '1',
        medicamentoId: 'med-1',
        medicamentoNombre: 'Ibuprofeno',
        cantidad: 2,
      );
      borrador = borrador.agregarOActualizarItem(item1);
      expect(borrador.items.length, 1);
      expect(borrador.items.first.cantidad, 2);

      // Agregar el mismo medicamento con 3 unidades
      const item1Mas = KitItemEntity(
        id: 'x',
        medicamentoId: 'med-1',
        medicamentoNombre: 'Ibuprofeno',
        cantidad: 3,
      );
      borrador = borrador.agregarOActualizarItem(item1Mas);
      expect(borrador.items.length, 1);
      expect(borrador.items.first.cantidad, 5);

      // Agregar medicamento distinto
      const item2 = KitItemEntity(
        id: '2',
        medicamentoId: 'med-2',
        medicamentoNombre: 'Morfina 10mg',
        cantidad: 1,
      );
      borrador = borrador.agregarOActualizarItem(item2);
      expect(borrador.items.length, 2);
    });

    test('eliminarItem y cambiarCantidad funcionan correctamente', () {
      var borrador = const KitBorrador(
        items: [
          KitItemEntity(id: '1', medicamentoId: 'med-1', medicamentoNombre: 'A', cantidad: 3),
          KitItemEntity(id: '2', medicamentoId: 'med-2', medicamentoNombre: 'B', cantidad: 1),
        ],
      );

      borrador = borrador.cambiarCantidad('med-1', 10);
      expect(borrador.items.firstWhere((i) => i.medicamentoId == 'med-1').cantidad, 10);

      borrador = borrador.eliminarItem('med-2');
      expect(borrador.items.length, 1);
      expect(borrador.items.any((i) => i.medicamentoId == 'med-2'), isFalse);
    });

    test('toMap serializa correctamente para RPC', () {
      const borrador = KitBorrador(
        nombre: '  Kit Cirugía Menor  ',
        descripcion: '  Insumos de corte y sutura  ',
        areaDestino: 'SOP',
        items: [
          KitItemEntity(id: '1', medicamentoId: 'med-99', medicamentoNombre: 'X', cantidad: 4),
        ],
      );

      final map = borrador.toMap();
      expect(map['nombre'], 'Kit Cirugía Menor');
      expect(map['descripcion'], 'Insumos de corte y sutura');
      expect(map['area_destino'], 'SOP');
      expect((map['items'] as List).length, 1);
      expect((map['items'] as List).first['medicamento_id'], 'med-99');
      expect((map['items'] as List).first['cantidad'], 4);
    });
  });

  group('KitEntity y KitItemEntity - Mapeo de datos', () {
    test('KitItemEntity.fromMap mapea campos correctamente', () {
      final map = {
        'id': 'ki-01',
        'medicamento_id': 'med-10',
        'nombre_comercial': 'Diazepam 10mg/2ml',
        'principio_activo': 'Diazepam',
        'presentacion': 'Ampolla',
        'laboratorio': 'Bago',
        'cantidad': 5,
      };

      final entity = KitItemEntity.fromMap(map);
      expect(entity.id, 'ki-01');
      expect(entity.medicamentoId, 'med-10');
      expect(entity.medicamentoNombre, 'Diazepam 10mg/2ml');
      expect(entity.presentacion, 'Ampolla');
      expect(entity.cantidad, 5);
    });

    test('KitEntity.fromMap mapea kit completo con sus ítems anidados', () {
      final map = {
        'id': 'kit-uuid-1',
        'nombre': 'Kit Paro Cardiorrespiratorio',
        'descripcion': 'Coche de paros para shock trauma',
        'area_destino': 'COCHE_PAROS',
        'area_nombre': 'Coche de Paros',
        'area_codigo_interno': 'AREA-003',
        'activo': true,
        'created_at': '2026-10-22T10:00:00Z',
        'updated_at': '2026-10-22T11:00:00Z',
        'total_items': 2,
        'items': [
          {
            'id': 'ki-1',
            'medicamento_id': 'med-1',
            'nombre_comercial': 'Adrenalina 1mg/ml',
            'cantidad': 10,
          },
          {
            'id': 'ki-2',
            'medicamento_id': 'med-2',
            'nombre_comercial': 'Atropina 1mg/ml',
            'cantidad': 5,
          },
        ],
      };

      final kit = KitEntity.fromMap(map);
      expect(kit.id, 'kit-uuid-1');
      expect(kit.nombre, 'Kit Paro Cardiorrespiratorio');
      expect(kit.areaDestino, 'COCHE_PAROS');
      expect(kit.areaNombre, 'Coche de Paros');
      expect(kit.totalItems, 2);
      expect(kit.items.length, 2);
      expect(kit.items.first.medicamentoNombre, 'Adrenalina 1mg/ml');
      expect(kit.activo, isTrue);
    });
  });
}
