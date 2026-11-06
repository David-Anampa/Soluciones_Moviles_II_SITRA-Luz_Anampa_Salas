import 'package:flutter_test/flutter_test.dart';
import 'package:sitra_luz/features/almacen/data/services/medicamento_ia_service.dart';
import 'package:sitra_luz/features/almacen/domain/entities/medicamento_extraccion_ia.dart';

void main() {
  group('HU-014 / RNF-011: Gs1BarcodeParser (Lectura Local Offline)', () {
    test('Reconoce código EAN-13 estándar y valida dígito de control GS1', () {
      // 7750215001233 tiene dígito de control válido (3)
      final valido = Gs1BarcodeParser.validarDigitoControlGtin('7750215001233');
      expect(valido, isTrue);
      expect(
        Gs1BarcodeParser.validarDigitoControlGtin('7750215001231'),
        isFalse,
      );

      final res = Gs1BarcodeParser.parsear('7750215001233');
      expect(res.gtin, '7750215001233');
      expect(res.esGs1Compuesto, isFalse);
      expect(res.digitoControlValido, isTrue);
    });

    test(
      'Extrae GTIN (01), Vencimiento (17) y Lote (10) de GS1 con paréntesis',
      () {
        final res = Gs1BarcodeParser.parsear(
          '(01)07750215001231(17)281231(10)L2026-B04',
        );
        expect(res.esGs1Compuesto, isTrue);
        expect(res.gtin, '7750215001231');
        expect(res.ean13Equivalente, '7750215001231');
        expect(res.numeroLote, 'L2026-B04');
        expect(res.fechaVencimiento, DateTime(2028, 12, 31));
      },
    );

    test(
      'Extrae GTIN, Vencimiento con día 00 (fin de mes GS1) y Lote sin paréntesis',
      () {
        final res = Gs1BarcodeParser.parsear(
          '01077502150012311728020010LOT99A',
        );
        expect(res.esGs1Compuesto, isTrue);
        expect(res.gtin, '7750215001231');
        expect(res.numeroLote, 'LOT99A');
        // 2028 es bisiesto: febrero 00 en GS1 = 29 de febrero de 2028
        expect(res.fechaVencimiento, DateTime(2028, 2, 29));
      },
    );
  });

  group('HU-014 / HU-015: EstandarizadorNombreFarmaceutico y HomologadorLaboratorio', () {
    test('Estandariza el nombre con abreviatura oficial y X unidades de caja', () {
      expect(
        EstandarizadorNombreFarmaceutico.construirNombreEstandarizado(
          nombreBaseOActual: 'Dexafar',
          concentracion: '8M/2ML',
          presentacion: 'Solución Inyectable',
          unidadesCaja: 1,
        ),
        'DEXAFAR 8M/2ML INY X 1',
      );

      expect(
        EstandarizadorNombreFarmaceutico.construirNombreEstandarizado(
          nombreBaseOActual: 'Atorvastatina 20mg',
          presentacion: 'Tabletas Recubiertas',
          unidadesCaja: 100,
        ),
        'ATORVASTATINA 20MG TAB REC X 100',
      );

      expect(
        EstandarizadorNombreFarmaceutico.construirNombreEstandarizado(
          nombreBaseOActual: 'Salbutamol 100mcg',
          presentacion: 'Inhalador',
          unidadesCaja: 1,
        ),
        'SALBUTAMOL 100MCG INH X 1',
      );
    });

    test('Convierte laboratorio a siglas y homologa con uno parecido en BD', () {
      final res1 = HomologadorLaboratorio.homologar(
        detectadoPorIa: 'Laboratorios Portugal S.R.L.',
        laboratoriosEnBd: ['MEDIFARMA', 'PORTUGAL', 'IQFARMA'],
      );
      expect(res1.coincidioConBaseDatos, isTrue);
      expect(res1.laboratorioFinal, 'PORTUGAL');

      final res2 = HomologadorLaboratorio.homologar(
        detectadoPorIa: 'Vitalis S.A.C. Laboratorios',
        laboratoriosEnBd: ['MEDIFARMA', 'PORTUGAL'],
      );
      expect(res2.coincidioConBaseDatos, isFalse);
      expect(res2.laboratorioFinal, 'VITALIS');
    });
  });

  group('HU-015: MedicamentoExtraccionIA y Validación Cruzada Estructurada', () {
    test('Limpia bloques markdown, estandariza nombre y homologa laboratorio', () {
      const rawResponse = '''
```json
{
  "nombre_base": "DEXAFAR",
  "concentracion": "8M/2ML",
  "nombre_comercial": "DEXAFAR 8M/2ML INY X 1",
  "principio_activo": "Dexametasona Fosfato",
  "presentacion": "Solución Inyectable",
  "categoria": "MEDICAMENTO",
  "laboratorio": "Laboratorios Portugal S.R.L.",
  "registro_sanitario": "RS-EE-09411",
  "unidad_presentacion": "ampolla",
  "cantidad_por_presentacion": 1,
  "numero_lote": "M26091",
  "fecha_vencimiento": "2028-10-31",
  "requiere_cadena_frio": false,
  "confianza": "ALTA",
  "alertas_validacion": ["Empaque verificado correctamente."]
}
```
''';
      final map = MedicamentoIaService.extraerJsonDesdeRespuestaIa(rawResponse);
      final entidad = MedicamentoExtraccionIA.fromStructuredJson(
        map,
        gtinEscaneado: '7759900112233',
        laboratoriosEnBd: ['PORTUGAL', 'MEDIFARMA'],
      );

      expect(entidad.nombreComercial, 'DEXAFAR 8M/2ML INY X 1');
      expect(entidad.principioActivo, 'Dexametasona Fosfato');
      expect(entidad.presentacion, 'Solución Inyectable');
      expect(entidad.categoria, 'MEDICAMENTO');
      expect(entidad.laboratorio, 'PORTUGAL');
      expect(entidad.laboratorioHomologadoBd, isTrue);
      expect(entidad.registroSanitario, 'RS-EE-09411');
      expect(entidad.unidadPresentacion, 'ampolla');
      expect(entidad.cantidadPorPresentacion, 1);
      expect(entidad.numeroLote, 'M26091');
      expect(entidad.fechaVencimiento, DateTime(2028, 10, 31));
      expect(entidad.extraidoPorIaReal, isTrue);
      expect(entidad.tieneDatosCatalogoCompletos, isTrue);
    });

    test(
      'Detecta discrepancia en validación cruzada entre catálogo y foto del empaque',
      () {
        final mapIa = {
          'nombre_comercial': 'Cefazolina 1g Inyectable',
          'principio_activo': 'Cefazolina',
          'presentacion': 'Frasco Ampolla',
          'categoria': 'MEDICAMENTO',
          'numero_lote': 'CF-2027',
          'fecha_vencimiento': '2028-05-30',
        };
        final catalogoSupabase = {
          'id': '11111111-2222-3333-4444-555555555555',
          'gtin': '7750215006543',
          'nombre_comercial': 'Ceftriaxona 1g',
          'principio_activo': 'Ceftriaxona Sódica',
          'presentacion': 'Frasco Ampolla',
          'categoria': 'MEDICAMENTO',
        };

        final entidad = MedicamentoExtraccionIA.fromStructuredJson(
          mapIa,
          gtinEscaneado: '7750215006543',
          catalogoExistente: catalogoSupabase,
        );

        expect(entidad.existeEnCatalogo, isTrue);
        expect(
          entidad.medicamentoExistenteId,
          '11111111-2222-3333-4444-555555555555',
        );
        expect(
          entidad.alertasValidacion.any(
            (a) => a.contains('Aviso de validación cruzada'),
          ),
          isTrue,
        );
      },
    );
  });
}
