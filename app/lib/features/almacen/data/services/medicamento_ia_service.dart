import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/medicamento_extraccion_ia.dart';

/// Excepción específica cuando no hay red disponible para ejecutar la validación cruzada por IA (RNF-011).
class SinConexionIaException implements Exception {
  final String message;
  final Gs1ParseResult gs1Local;
  final String? fotoPath;
  final List<String> fotosPaths;

  const SinConexionIaException({
    required this.message,
    required this.gs1Local,
    this.fotoPath,
    this.fotosPaths = const [],
  });

  @override
  String toString() => message;
}

/// Excepción de validación o extracción IA (HU-014 / HU-015).
class MedicamentoIaException implements Exception {
  final String message;
  const MedicamentoIaException(this.message);

  @override
  String toString() => message;
}

/// Servicio real de Reconocimiento y Validación Cruzada por IA (HU-014 y HU-015).
/// Soporta análisis multimodal de 1 a 4 fotografías del empaque (frente, lote/vencimiento,
/// registro sanitario/reverso y 4.ª foto opcional), guardado de capturas en la galería del
/// celular, nombre estandarizado con abreviaturas farmacéuticas y homologación de laboratorio
/// en siglas contra la base de datos.
class MedicamentoIaService {
  static const String _prefsGeminiKey = 'sitra_gemini_api_key_v1';
  static const String _envGeminiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static const MethodChannel _galeriaChannel = MethodChannel(
    'ap.sitra.luz.clinica/galeria',
  );

  final SupabaseClient? _customSupabase;
  final http.Client? _customHttp;

  MedicamentoIaService({
    SupabaseClient? supabaseClient,
    http.Client? httpClient,
  }) : _customSupabase = supabaseClient,
       _customHttp = httpClient;

  SupabaseClient get _supabase => _customSupabase ?? Supabase.instance.client;
  http.Client get _http => _customHttp ?? http.Client();

  /// Guarda una fotografía capturada en la galería del dispositivo Android (`Pictures/SITRA_Luz`).
  static Future<bool> guardarFotoEnGaleriaDispositivo(
    String filePath, {
    String? etiqueta,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final tag = (etiqueta ?? 'EMPAQUE')
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
          .toUpperCase();
      await _galeriaChannel.invokeMethod<String>('guardarImagenEnGaleria', {
        'filePath': filePath,
        'fileName': 'SITRA_LUZ_${tag}_$ts.jpg',
      });
      return true;
    } catch (e) {
      debugPrint('Aviso guardando foto en galería: $e');
      return false;
    }
  }

  /// Obtiene la API Key de Gemini desde `--dart-define=GEMINI_API_KEY` o `SharedPreferences`,
  /// eliminando espacios o saltos de línea invisibles al copiar/pegar en el celular.
  static Future<String> obtenerApiKeyConfigurada() async {
    if (_envGeminiKey.trim().isNotEmpty) {
      return _envGeminiKey.replaceAll(RegExp(r'\s+'), '');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getString(_prefsGeminiKey) ?? '')
          .replaceAll(RegExp(r'\s+'), '');
    } catch (_) {
      return '';
    }
  }

  /// Guarda o actualiza la API Key de Gemini en el almacenamiento seguro del dispositivo.
  static Future<void> guardarApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    final clean = apiKey.replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) {
      await prefs.remove(_prefsGeminiKey);
    } else {
      await prefs.setString(_prefsGeminiKey, clean);
    }
  }

  /// Consulta directamente a Google AI Studio (`GET /v1beta/models`) qué modelos
  /// con soporte `generateContent` están habilitados para esta API Key.
  /// Evita errores HTTP 404 por modelos retirados (como gemini-1.5-flash).
  Future<List<String>> descubrirModelosDisponibles(String apiKey) async {
    final cleanKey = apiKey.replaceAll(RegExp(r'\s+'), '');
    if (cleanKey.isEmpty) return const [];

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models?key=$cleanKey',
    );
    final response = await _http.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      String detalle = 'HTTP ${response.statusCode}';
      try {
        final bodyMap = jsonDecode(response.body);
        detalle = bodyMap['error']?['message']?.toString() ?? detalle;
      } catch (_) {}
      throw MedicamentoIaException('Clave API rechazada por Google: $detalle');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rawModels = decoded['models'] as List? ?? const [];
    final disponibles = <String>[];

    for (final item in rawModels) {
      if (item is! Map) continue;
      final name = item['name']?.toString() ?? '';
      final methods =
          (item['supportedGenerationMethods'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [];
      if (!methods.contains('generateContent')) continue;

      final shortName = name.startsWith('models/')
          ? name.substring('models/'.length)
          : name;
      final lower = shortName.toLowerCase();

      // Filtrar solo modelos Gemini multimodales de texto/visión (excluir TTS, generación de imagen/video/audio, embeddings o gemma)
      if (!lower.startsWith('gemini-')) continue;
      if (lower.contains('tts') ||
          lower.contains('image') ||
          lower.contains('imagen') ||
          lower.contains('embedding') ||
          lower.contains('veo') ||
          lower.contains('audio') ||
          lower.contains('native-audio') ||
          lower.contains('robotics') ||
          lower.contains('computer-use') ||
          lower.contains('aqa') ||
          lower.contains('bisheng')) {
        continue;
      }
      disponibles.add(shortName);
    }

    // Ordenar dando prioridad a los modelos multimodales rápidos y vigentes
    const prioridadPreferida = [
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-flash-latest',
      'gemini-flash-lite-latest',
      'gemini-3-flash-preview',
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
      'gemini-2.5-pro',
      'gemini-pro-latest',
    ];

    final ordenados = <String>[];
    for (final pref in prioridadPreferida) {
      if (disponibles.contains(pref)) {
        ordenados.add(pref);
      }
    }
    for (final m in disponibles) {
      if (!ordenados.contains(m)) {
        ordenados.add(m);
      }
    }

    return ordenados;
  }

  /// Verifica si existe una API Key de Gemini configurada en el dispositivo o entorno.
  static Future<bool> tieneApiKeyConfigurada() async {
    final key = await obtenerApiKeyConfigurada();
    return key.isNotEmpty;
  }

  /// Verifica conectividad activa antes de iniciar la validación cruzada online (RNF-011).
  Future<bool> verificarConectividadActiva() async {
    if (kIsWeb) return true;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Construye un borrador limpio solo con la lectura local GS1/GTIN cuando no hay red
  /// o cuando el usuario decide continuar manualmente sin perder el código ni las fotos (RNF-011).
  MedicamentoExtraccionIA construirBorradorLocal({
    required String codigoBruto,
    String? fotoCajaPath,
    List<String> fotosCajaPaths = const [],
    String? avisoAdicional,
  }) {
    final gs1 = Gs1BarcodeParser.parsear(codigoBruto);
    final alertas = <String>[];
    if (!gs1.digitoControlValido && gs1.gtin.isNotEmpty) {
      alertas.add(
        'El código escaneado (${gs1.gtin}) no tiene un dígito verificador EAN/GTIN estándar; verifique que sea el código correcto.',
      );
    }
    if (gs1.esGs1Compuesto) {
      alertas.add(
        'Se extrajo localmente estructura GS1 del código de barras (GTIN${gs1.numeroLote != null ? ", Lote ${gs1.numeroLote}" : ""}${gs1.fechaVencimiento != null ? ", Vencimiento" : ""}).',
      );
    }
    if (avisoAdicional != null && avisoAdicional.trim().isNotEmpty) {
      alertas.add(avisoAdicional.trim());
    }

    final listaFotos = fotosCajaPaths.isNotEmpty
        ? fotosCajaPaths
        : (fotoCajaPath != null && fotoCajaPath.trim().isNotEmpty
              ? <String>[fotoCajaPath]
              : const <String>[]);

    return MedicamentoExtraccionIA(
      gtin: gs1.gtin,
      nombreComercial: '',
      principioActivo: '',
      presentacion: '',
      categoria: 'MEDICAMENTO',
      unidadPresentacion: 'tableta',
      cantidadPorPresentacion: 1,
      numeroLote: gs1.numeroLote ?? '',
      fechaVencimiento: gs1.fechaVencimiento,
      fechaFabricacion: gs1.fechaFabricacion,
      fotoPath: listaFotos.isNotEmpty ? listaFotos.first : fotoCajaPath,
      fotosPaths: listaFotos,
      existeEnCatalogo: false,
      extraidoPorIaReal: false,
      confianza: 'SOLO_CODIGO',
      origenDatos: 'Lectura Local GS1/GTIN (ML Kit Offline)',
      alertasValidacion: alertas,
    );
  }

  /// Consulta la lista de laboratorios ya registrados en `public.medicamentos` y `public.lotes`
  /// para que la IA y el homologador seleccionen el mismo laboratorio si ya existe uno parecido.
  Future<List<String>> listarLaboratoriosRegistradosEnBd() async {
    final labs = <String>{};
    try {
      final rowsMed = await _supabase
          .from('medicamentos')
          .select('laboratorio')
          .not('laboratorio', 'is', null)
          .limit(300);
      for (final r in (rowsMed as List)) {
        final l = (r as Map)['laboratorio']?.toString().trim() ?? '';
        if (l.isNotEmpty) labs.add(l);
      }
    } catch (_) {}

    try {
      final rowsLotes = await _supabase
          .from('lotes')
          .select('laboratorio')
          .not('laboratorio', 'is', null)
          .limit(300);
      for (final r in (rowsLotes as List)) {
        final l = (r as Map)['laboratorio']?.toString().trim() ?? '';
        if (l.isNotEmpty) labs.add(l);
      }
    } catch (_) {}

    final sorted = labs.toList()..sort();
    return sorted;
  }

  /// Consulta el catálogo maestro real en Supabase (`public.medicamentos`).
  Future<List<Map<String, dynamic>>> listarCatalogoRealSupabase() async {
    final hayRed = await verificarConectividadActiva();
    if (!hayRed) {
      throw const MedicamentoIaException(
        'Sin conexión a internet. Conéctate a la red para consultar el catálogo de Supabase.',
      );
    }
    try {
      final rows = await _supabase
          .from('medicamentos')
          .select()
          .eq('activo', true)
          .order('nombre_comercial', ascending: true)
          .limit(100);
      return (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      throw MedicamentoIaException(
        'No se pudo consultar el catálogo en Supabase: $e',
      );
    }
  }

  /// Busca un medicamento en `public.medicamentos` por su GTIN exacto o su equivalente EAN-13/GTIN-14.
  Future<Map<String, dynamic>?> buscarPorGtinEnSupabase(
    Gs1ParseResult gs1,
  ) async {
    final candidatos = <String>{
      gs1.gtin.trim(),
      if (gs1.ean13Equivalente != null) gs1.ean13Equivalente!.trim(),
      if (gs1.gtin.length == 13) '0${gs1.gtin}',
    }..removeWhere((e) => e.isEmpty);

    if (candidatos.isEmpty) return null;

    final response = await _supabase
        .from('medicamentos')
        .select()
        .inFilter('gtin', candidatos.toList())
        .limit(1);

    final lista = response as List;
    if (lista.isEmpty) return null;
    return Map<String, dynamic>.from(lista.first as Map);
  }

  /// Ejecuta el flujo completo de HU-014 y HU-015 combinando el código GS1/GTIN
  /// y de 1 a 4 fotografías del empaque (frente, lote/vencimiento, reverso/RS y 4.ª opcional).
  Future<MedicamentoExtraccionIA> procesarEscaneoYFoto({
    required String gtinEscaneado,
    String? fotoCajaPath,
    List<String> fotosCajaPaths = const [],
  }) async {
    final gs1 = Gs1BarcodeParser.parsear(gtinEscaneado);

    final fotosValidas = <String>[
      ...fotosCajaPaths,
      if (fotoCajaPath != null &&
          fotoCajaPath.trim().isNotEmpty &&
          !fotosCajaPaths.contains(fotoCajaPath))
        fotoCajaPath,
    ].where((p) => p.trim().isNotEmpty && !kIsWeb && File(p).existsSync()).toList();

    if (gs1.gtin.isEmpty && fotosValidas.isEmpty) {
      throw const MedicamentoIaException(
        'Escanea el código de barras o captura las fotografías del empaque para continuar.',
      );
    }

    // RNF-011: Detectar ausencia de conectividad antes de iniciar validación cruzada online.
    final conectado = await verificarConectividadActiva();
    if (!conectado) {
      throw SinConexionIaException(
        message:
            'No hay conexión a internet en este momento (RNF-011). Tu lectura de código (${gs1.gtin}) y fotografías (${fotosValidas.length}) están seguras; puedes reintentar al recuperar señal o continuar al formulario manualmente.',
        gs1Local: gs1,
        fotoPath: fotosValidas.isNotEmpty ? fotosValidas.first : fotoCajaPath,
        fotosPaths: fotosValidas,
      );
    }

    Map<String, dynamic>? catalogoExistente;
    if (gs1.gtin.isNotEmpty) {
      try {
        catalogoExistente = await buscarPorGtinEnSupabase(gs1);
      } catch (e) {
        debugPrint('Aviso consultando GTIN en Supabase: $e');
      }
    }

    List<String> laboratoriosEnBd = const [];
    try {
      laboratoriosEnBd = await listarLaboratoriosRegistradosEnBd();
    } catch (_) {}

    String? avisoIaNoEjecutada;
    if (fotosValidas.isNotEmpty) {
      final apiKey = await obtenerApiKeyConfigurada();
      if (apiKey.isNotEmpty) {
        try {
          final jsonIa = await _extraerConGeminiRestApi(
            apiKey: apiKey,
            fotosPaths: fotosValidas,
            gs1: gs1,
            catalogoExistente: catalogoExistente,
            laboratoriosEnBd: laboratoriosEnBd,
          );

          // Si el GTIN no se había escaneado antes pero la IA lo leyó en una de las fotos, buscamos en catálogo
          final gtinDetectadoIa =
              jsonIa['gtin_detectado']?.toString().trim() ?? '';
          if (catalogoExistente == null &&
              gs1.gtin.isEmpty &&
              gtinDetectadoIa.isNotEmpty) {
            try {
              catalogoExistente = await buscarPorGtinEnSupabase(
                Gs1BarcodeParser.parsear(gtinDetectadoIa),
              );
            } catch (_) {}
          }

          return MedicamentoExtraccionIA.fromStructuredJson(
            jsonIa,
            gtinEscaneado:
                catalogoExistente?['gtin']?.toString() ??
                (gs1.gtin.isNotEmpty ? gs1.gtin : gtinDetectadoIa),
            fotoPath: fotosValidas.first,
            fotosPaths: fotosValidas,
            gs1: gs1,
            catalogoExistente: catalogoExistente,
            laboratoriosEnBd: laboratoriosEnBd,
          );
        } catch (e) {
          debugPrint('Aviso en extracción Gemini Vision: $e');
          avisoIaNoEjecutada =
              'No se pudo completar el análisis visual con Gemini ($e). Se conservaron los datos verificados del código y catálogo.';
        }
      } else {
        // Intentar Supabase Edge Function `extraer-medicamento-ia` si está desplegada
        try {
          final jsonEdge = await _extraerConSupabaseEdgeFunction(
            fotosPaths: fotosValidas,
            gs1: gs1,
            catalogoExistente: catalogoExistente,
            laboratoriosEnBd: laboratoriosEnBd,
          );
          if (jsonEdge != null) {
            return MedicamentoExtraccionIA.fromStructuredJson(
              jsonEdge,
              gtinEscaneado:
                  catalogoExistente?['gtin']?.toString() ?? gs1.gtin,
              fotoPath: fotosValidas.first,
              fotosPaths: fotosValidas,
              gs1: gs1,
              catalogoExistente: catalogoExistente,
              laboratoriosEnBd: laboratoriosEnBd,
            );
          }
        } catch (_) {}
        avisoIaNoEjecutada =
            'Para extraer texto de las fotografías con Gemini Vision, configura tu clave de API Gemini en el ícono de llave (🔑) superior.';
      }
    }

    // Si el producto YA existe en el catálogo de Supabase, precargamos todos sus datos reales
    if (catalogoExistente != null) {
      final alertas = <String>[
        'Producto identificado en el catálogo maestro de Supabase (${catalogoExistente['nombre_comercial']}).',
      ];
      if (gs1.esGs1Compuesto) {
        alertas.add(
          'Datos de lote/vencimiento leídos del código GS1 del empaque.',
        );
      } else if (fotosValidas.isEmpty) {
        alertas.add(
          'Código lineal EAN/GTIN verificado. Ingrese el número de lote y fecha de vencimiento impresos en la caja.',
        );
      }
      if (avisoIaNoEjecutada != null) {
        alertas.add(avisoIaNoEjecutada);
      }

      final labHomologado = HomologadorLaboratorio.homologar(
        detectadoPorIa: catalogoExistente['laboratorio']?.toString(),
        laboratoriosEnBd: laboratoriosEnBd,
      );

      return MedicamentoExtraccionIA(
        gtin: catalogoExistente['gtin']?.toString() ?? gs1.gtin,
        nombreComercial:
            catalogoExistente['nombre_comercial']?.toString() ?? '',
        principioActivo:
            catalogoExistente['principio_activo']?.toString() ?? '',
        presentacion: catalogoExistente['presentacion']?.toString() ?? '',
        categoria: (catalogoExistente['categoria']
                    ?.toString()
                    .toUpperCase() ==
                'DISPOSITIVO_MEDICO')
            ? 'DISPOSITIVO_MEDICO'
            : 'MEDICAMENTO',
        laboratorio: labHomologado.laboratorioFinal.isEmpty
            ? catalogoExistente['laboratorio']?.toString()
            : labHomologado.laboratorioFinal,
        laboratorioHomologadoBd: true,
        codArt: catalogoExistente['cod_art']?.toString(),
        precioKairos: catalogoExistente['precio_kairos'] != null
            ? double.tryParse(catalogoExistente['precio_kairos'].toString())
            : null,
        registroSanitario:
            catalogoExistente['registro_sanitario']?.toString(),
        unidadPresentacion: _normalizarUnidadCatalogo(
          catalogoExistente['unidad_presentacion']?.toString() ?? 'unidad',
        ),
        cantidadPorPresentacion:
            (catalogoExistente['cantidad_por_presentacion'] as num?)?.toInt() ??
            1,
        numeroLote: gs1.numeroLote ?? '',
        fechaVencimiento: gs1.fechaVencimiento,
        fechaFabricacion: gs1.fechaFabricacion,
        requiereCadenaFrio:
            catalogoExistente['requiere_cadena_frio'] as bool? ?? false,
        temperaturaMin:
            (catalogoExistente['temperatura_min'] as num?)?.toDouble() ?? 2.0,
        temperaturaMax:
            (catalogoExistente['temperatura_max'] as num?)?.toDouble() ?? 8.0,
        fotoPath: fotosValidas.isNotEmpty ? fotosValidas.first : fotoCajaPath,
        fotosPaths: fotosValidas,
        existeEnCatalogo: true,
        medicamentoExistenteId: catalogoExistente['id']?.toString(),
        extraidoPorIaReal: false,
        confianza: 'ALTA',
        origenDatos: 'Catálogo Maestro Supabase',
        alertasValidacion: alertas,
      );
    }

    return construirBorradorLocal(
      codigoBruto: gtinEscaneado,
      fotoCajaPath: fotosValidas.isNotEmpty ? fotosValidas.first : fotoCajaPath,
      fotosCajaPaths: fotosValidas,
      avisoAdicional:
          avisoIaNoEjecutada ??
          'El código GTIN ${gs1.gtin} es nuevo en el catálogo de Supabase. Captura las 3 o 4 caras del empaque con Gemini IA configurado o completa los campos técnicos en el formulario.',
    );
  }

  /// Invoca la API REST oficial de Google Gemini (`gemini-2.5-flash` / `gemini-2.0-flash`)
  /// enviando simultáneamente las 1 a 4 fotografías de la caja y exigiendo salida JSON estructurada
  /// con el formato estandarizado de nombre y siglas de laboratorio.
  Future<Map<String, dynamic>> _extraerConGeminiRestApi({
    required String apiKey,
    required List<String> fotosPaths,
    required Gs1ParseResult gs1,
    Map<String, dynamic>? catalogoExistente,
    List<String> laboratoriosEnBd = const [],
  }) async {
    final imageParts = <Map<String, dynamic>>[];
    for (final path in fotosPaths.take(4)) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final bytes = await file.readAsBytes();
      imageParts.add({
        'inline_data': {
          'mime_type': _detectarMimeType(path),
          'data': base64Encode(bytes),
        },
      });
    }

    if (imageParts.isEmpty) {
      throw const MedicamentoIaException(
        'No se encontraron imágenes válidas para enviar a Gemini Vision.',
      );
    }

    final contextoCatalogo = catalogoExistente != null
        ? 'El código GTIN ${gs1.gtin} ya existe en nuestro catálogo con nombre_comercial="${catalogoExistente['nombre_comercial']}", principio_activo="${catalogoExistente['principio_activo']}", presentacion="${catalogoExistente['presentacion']}". Verifica si las fotos corresponden a este producto y extrae de cualquiera de las caras fotografiadas el número de lote, fecha de vencimiento, registro sanitario y laboratorio.'
        : 'El código GTIN escaneado es "${gs1.gtin}". Analiza de forma conjunta TODAS las fotografías enviadas (${imageParts.length} caras del mismo empaque: cara frontal, solapa de lote/vencimiento, reverso con registro sanitario y código de barras) para completar TODOS los datos.';

    final listaLabsTexto = laboratoriosEnBd.isNotEmpty
        ? 'Laboratorios ya registrados en nuestra Base de Datos: [${laboratoriosEnBd.take(80).join(", ")}]. Si el fabricante del empaque corresponde o es similar a alguno de esta lista, devuelve EXACTAMENTE ese mismo nombre/sigla.'
        : 'Devuelve únicamente las SIGLAS o nombre corto en mayúsculas del laboratorio (ej. MEDIFARMA, PORTUGAL, HERSIL, IQFARMA, FARMINDUSTRIA, GENFAR, BAYER, PFIZER, ROCHE), nunca la razón social larga.';

    final prompt = '''
Eres un químico farmacéutico experto en recepción hospitalaria (DIGEMID - Perú) para el sistema clínico SITRA-Luz.
Se te adjuntan ${imageParts.length} fotografía(s) de distintas caras del mismo empaque de medicamento o dispositivo médico.
Combina la información visible en TODAS las fotografías para no dejar ningún campo vacío si aparece en alguna de las fotos.
$contextoCatalogo

REGLA OBLIGATORIA 1 — NOMBRE ESTANDARIZADO CON ABREVIATURAS:
El campo "nombre_comercial" DEBE formarse en MAYÚSCULAS siguiendo este estándar exacto:
MEDICAMENTO + CONCENTRACIÓN/VOLUMEN + ABREVIATURA_PRESENTACIÓN + "X" + UNIDADES_QUE_TRAE_LA_CAJA
Usa estrictamente estas abreviaturas oficiales para la presentación:
- INYECTABLE = INY
- AMPOLLA = AMP
- JARABE = JAB
- TUBO / CREMA / UNGÜENTO = TBO
- TABLETAS = TAB
- TABLETAS RECUBIERTAS = TAB REC
- CAPSULAS = CAP
- INHALADOR = INH
- UNIDAD / DISPOSITIVO = UND
- SOBRES = SOB
Ejemplo exacto: si es Dexafar de 8mg/2ml Inyectable caja por 1 unidad -> "DEXAFAR 8M/2ML INY X 1" (o "DEXAFAR 8MG/2ML INY X 1").
Si es Paracetamol 500mg Tabletas caja por 100 -> "PARACETAMOL 500MG TAB X 100".

REGLA OBLIGATORIA 2 — LABORATORIO EN SIGLAS Y HOMOLOGADO CON BD:
En "laboratorio", escribe las SIGLAS o marca corta en MAYÚSCULAS, NO la razón social completa (sin "S.A.", "S.R.L.", "Laboratorios", etc.).
$listaLabsTexto

REGLA OBLIGATORIA 3 — LOTE, FECHA DE VENCIMIENTO, GTIN Y REGISTRO SANITARIO (RS):
Busca con máxima atención en todas las fotos:
- "numero_lote": junto a "Lote", "L.", "Lot", "Batch", "B/" o grabado en la solapa.
- "fecha_vencimiento": junto a "Vence", "Vto", "Exp", "Cad", "F.V." en formato YYYY-MM-DD (si solo dice MM/YYYY o MES/AAAA, usa el último día de ese mes, ej. 11/2027 -> "2027-11-30").
- "registro_sanitario": código DIGEMID junto a "R.S.", "Reg. San.", "RS" (ej. "EN-01234", "EE-04812", "DM-1023").
- "gtin_detectado": dígitos bajo el código de barras si se observa en alguna foto.

Devuelve ÚNICAMENTE un objeto JSON válido con esta estructura exacta (usa "" o null solo si el dato no aparece en ninguna de las fotos):
{
  "nombre_base": "Marca o nombre principal sin presentación (ej. DEXAFAR)",
  "concentracion": "Concentración o fuerza (ej. 8M/2ML, 500MG, 1G/100ML)",
  "nombre_comercial": "Nombre estandarizado completo (ej. DEXAFAR 8M/2ML INY X 1)",
  "principio_activo": "Denominación Común Internacional / principio activo (ej. Dexametasona Fosfato, Amoxicilina)",
  "presentacion": "Una de: Solución Inyectable, Ampolla, Jarabe, Ungüento, Tableta, Tableta Recubierta, Cápsula, Inhalador, Sobre, Dispositivo Médico / Insumo",
  "categoria": "MEDICAMENTO o DISPOSITIVO_MEDICO",
  "laboratorio": "Siglas del laboratorio o coincidencia exacta de la BD",
  "registro_sanitario": "Código de Registro Sanitario DIGEMID (ej. EE-04812, EN-01294)",
  "unidad_presentacion": "Una de: tableta, capsula, ampolla, vial, frasco, sobre, parche, unidad",
  "cantidad_por_presentacion": 1,
  "numero_lote": "Código de lote impreso o grabado en la caja",
  "fecha_vencimiento": "YYYY-MM-DD",
  "fecha_fabricacion": "YYYY-MM-DD o null",
  "gtin_detectado": "Código de barras numérico si es visible en alguna foto",
  "requiere_cadena_frio": false,
  "temperatura_min": 2.0,
  "temperatura_max": 8.0,
  "confianza": "ALTA, MEDIA o BAJA",
  "alertas_validacion": [
    "Observaciones de lectura óptica, cadena de frío o discrepancias detectadas"
  ]
}
''';

    final cleanKey = apiKey.replaceAll(RegExp(r'\s+'), '');
    List<String> modelos = const [];
    try {
      modelos = await descubrirModelosDisponibles(cleanKey);
    } on MedicamentoIaException {
      rethrow;
    } catch (_) {}

    if (modelos.isEmpty) {
      modelos = const [
        'gemini-2.5-flash',
        'gemini-2.5-flash-lite',
        'gemini-flash-latest',
        'gemini-2.0-flash',
      ];
    }

    String? primerErrorSignificativo;
    Object? ultimoError;

    for (final modelo in modelos.take(5)) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelo:generateContent?key=$cleanKey',
      );
      try {
        final response = await _http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt},
                      ...imageParts,
                    ],
                  },
                ],
                'generationConfig': {
                  'temperature': 0.1,
                  'responseMimeType': 'application/json',
                },
              }),
            )
            .timeout(const Duration(seconds: 45));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = decoded['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content =
                (candidates.first as Map)['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              // Recorrer de atrás hacia adelante ignorando bloques de pensamiento ('thought': true)
              for (final part in parts.reversed) {
                if (part is! Map) continue;
                if (part['thought'] == true) continue;
                final rawText = part['text']?.toString() ?? '';
                if (rawText.trim().isEmpty) continue;
                try {
                  final parsed = extraerJsonDesdeRespuestaIa(rawText);
                  if (parsed.isNotEmpty) {
                    return parsed;
                  }
                } catch (_) {
                  // Seguir probando con otra parte si hubiese más de una
                }
              }
            }
          }
        } else {
          String msgError = 'HTTP ${response.statusCode}';
          try {
            final bodyMap = jsonDecode(response.body);
            msgError =
                bodyMap['error']?['message']?.toString() ?? msgError;
          } catch (_) {}

          if (response.statusCode == 401 || response.statusCode == 403) {
            throw MedicamentoIaException(msgError);
          }
          if (response.statusCode != 404 && primerErrorSignificativo == null) {
            primerErrorSignificativo = '$modelo: $msgError';
          }
          ultimoError = '$modelo: $msgError';
        }
      } on MedicamentoIaException {
        rethrow;
      } catch (e) {
        primerErrorSignificativo ??= '$modelo: $e';
        ultimoError = '$modelo: $e';
      }
    }

    throw MedicamentoIaException(
      'No se obtuvo respuesta válida de Gemini Vision (${primerErrorSignificativo ?? ultimoError ?? "tiempo agotado"}).',
    );
  }

  Future<Map<String, dynamic>?> _extraerConSupabaseEdgeFunction({
    required List<String> fotosPaths,
    required Gs1ParseResult gs1,
    Map<String, dynamic>? catalogoExistente,
    List<String> laboratoriosEnBd = const [],
  }) async {
    final primera = File(fotosPaths.first);
    final bytes = await primera.readAsBytes();
    final imagenesBase64 = <Map<String, String>>[];
    for (final p in fotosPaths.take(4)) {
      final f = File(p);
      if (f.existsSync()) {
        imagenesBase64.add({
          'mime_type': _detectarMimeType(p),
          'data': base64Encode(await f.readAsBytes()),
        });
      }
    }

    final response = await _supabase.functions.invoke(
      'extraer-medicamento-ia',
      body: {
        'gtin': gs1.gtin,
        'imagen_base64': base64Encode(bytes),
        'mime_type': _detectarMimeType(fotosPaths.first),
        'imagenes': imagenesBase64,
        'catalogo_existente': catalogoExistente,
        'laboratorios_bd': laboratoriosEnBd,
      },
    );
    if (response.status == 200 && response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return null;
  }

  /// Limpia bloques markdown ```json ... ``` si el modelo los incluye y decodifica el mapa JSON.
  static Map<String, dynamic> extraerJsonDesdeRespuestaIa(String rawText) {
    var clean = rawText.trim();
    if (clean.startsWith('```')) {
      clean = clean
          .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }
    final startIdx = clean.indexOf('{');
    final endIdx = clean.lastIndexOf('}');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      clean = clean.substring(startIdx, endIdx + 1);
    }
    final decoded = jsonDecode(clean);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }

  static String _detectarMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  static String _normalizarUnidadCatalogo(String raw) {
    final u = raw.toLowerCase().trim();
    if (u.contains('tableta') || u.contains('comprimido')) return 'tableta';
    if (u.contains('capsula') || u.contains('cápsula')) return 'capsula';
    if (u.contains('ampolla')) return 'ampolla';
    if (u.contains('vial')) return 'vial';
    if (u.contains('frasco')) return 'frasco';
    if (u.contains('sobre')) return 'sobre';
    if (u.contains('parche')) return 'parche';
    const permitidas = {
      'tableta',
      'capsula',
      'ampolla',
      'vial',
      'frasco',
      'sobre',
      'parche',
      'unidad',
    };
    return permitidas.contains(u) ? u : 'unidad';
  }
}
