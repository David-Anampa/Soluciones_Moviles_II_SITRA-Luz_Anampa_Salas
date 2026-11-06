/// Resultado del análisis local (offline) de un código de barras GS1 / GTIN (RNF-011).
class Gs1ParseResult {
  /// Código bruto leído por el escáner.
  final String rawCode;

  /// GTIN extraído (8, 12, 13 o 14 dígitos), o el código limpio si es alfanumérico.
  final String gtin;

  /// Si proviene de un GTIN-14 con '0' inicial, contiene su equivalente EAN-13.
  final String? ean13Equivalente;

  /// Número de lote extraído del AI (10), si el código es GS1-128 / DataMatrix.
  final String? numeroLote;

  /// Fecha de vencimiento extraída del AI (17) en formato YYMMDD.
  final DateTime? fechaVencimiento;

  /// Fecha de fabricación extraída del AI (11) en formato YYMMDD.
  final DateTime? fechaFabricacion;

  /// Número de serie extraído del AI (21), si está presente.
  final String? numeroSerie;

  /// Indica si el código tenía estructura compuesta GS1 (AI 01, 17, 10, etc.).
  final bool esGs1Compuesto;

  /// Indica si el dígito verificador GS1 Modulo-10 es matemáticamente válido.
  final bool digitoControlValido;

  const Gs1ParseResult({
    required this.rawCode,
    required this.gtin,
    this.ean13Equivalente,
    this.numeroLote,
    this.fechaVencimiento,
    this.fechaFabricacion,
    this.numeroSerie,
    this.esGs1Compuesto = false,
    this.digitoControlValido = false,
  });
}

/// Parser puro y 100% offline para códigos de barras farmacéuticos EAN-13, GTIN-14,
/// GS1-128 y GS1 DataMatrix (cumple RNF-011 y RF-014).
class Gs1BarcodeParser {
  static const String _gs = '\x1d';

  /// Analiza cualquier cadena devuelta por ML Kit (`mobile_scanner`) y extrae
  /// los Application Identifiers (AI) GS1 si están presentes.
  static Gs1ParseResult parsear(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) {
      return const Gs1ParseResult(rawCode: '', gtin: '');
    }

    // Limpiar prefijos simbólicos AIM (ej. ]C1, ]d2, ]e0, ]Q3)
    var clean = trimmed;
    if (clean.length > 3 && clean.startsWith(']')) {
      clean = clean.substring(3).trim();
    }

    // Caso 1: Formato GS1 con paréntesis explícitos: (01)07750215001234(17)281231(10)L2026A
    if (clean.contains('(01)') ||
        clean.contains('(17)') ||
        clean.contains('(10)')) {
      return _parsearConParentesis(trimmed, clean);
    }

    // Caso 2: Formato GS1 sin paréntesis: empieza con 01 + 14 dígitos y tiene más AIs detrás (17, 10, 11, 21)
    final sinGsInicial = clean.startsWith(_gs) ? clean.substring(1) : clean;
    if (sinGsInicial.length > 16 &&
        RegExp(r'^01\d{14}').hasMatch(sinGsInicial)) {
      return _parsearSinParentesis(trimmed, sinGsInicial);
    }

    // Caso 3: Código lineal estándar (EAN-13, EAN-8, UPC-A, GTIN-14 o código interno)
    final soloDigitos = sinGsInicial.replaceAll(RegExp(r'\D'), '');
    final gtin = soloDigitos.isNotEmpty ? soloDigitos : sinGsInicial;
    final ean13 = (gtin.length == 14 && gtin.startsWith('0'))
        ? gtin.substring(1)
        : null;

    return Gs1ParseResult(
      rawCode: trimmed,
      gtin: ean13 ?? gtin,
      ean13Equivalente: ean13,
      esGs1Compuesto: false,
      digitoControlValido: validarDigitoControlGtin(ean13 ?? gtin),
    );
  }

  static Gs1ParseResult _parsearConParentesis(String raw, String clean) {
    String? gtin;
    String? lote;
    DateTime? vencimiento;
    DateTime? fabricacion;
    String? serie;

    final regex = RegExp(r'\((\d{2,4})\)([^\(\x1d]+)');
    for (final match in regex.allMatches(clean)) {
      final ai = match.group(1)!;
      final valor = match.group(2)!.trim();
      switch (ai) {
        case '01':
          final digitos = valor.replaceAll(RegExp(r'\D'), '');
          if (digitos.isNotEmpty) {
            gtin = digitos.length > 14 ? digitos.substring(0, 14) : digitos;
          }
          break;
        case '17':
          vencimiento = parsearFechaGs1(valor);
          break;
        case '11':
          fabricacion = parsearFechaGs1(valor);
          break;
        case '10':
          lote = valor;
          break;
        case '21':
          serie = valor;
          break;
      }
    }

    final gtinFinal = gtin ?? clean.replaceAll(RegExp(r'\D'), '');
    final ean13 = (gtinFinal.length == 14 && gtinFinal.startsWith('0'))
        ? gtinFinal.substring(1)
        : null;
    final gtinNormalizado = ean13 ?? gtinFinal;

    return Gs1ParseResult(
      rawCode: raw,
      gtin: gtinNormalizado,
      ean13Equivalente: ean13,
      numeroLote: lote,
      fechaVencimiento: vencimiento,
      fechaFabricacion: fabricacion,
      numeroSerie: serie,
      esGs1Compuesto: true,
      digitoControlValido: validarDigitoControlGtin(gtinNormalizado),
    );
  }

  static Gs1ParseResult _parsearSinParentesis(String raw, String data) {
    final gtin14 = data.substring(2, 16);
    var cursor = 16;
    String? lote;
    DateTime? vencimiento;
    DateTime? fabricacion;
    String? serie;

    while (cursor < data.length) {
      if (data[cursor] == _gs) {
        cursor++;
        continue;
      }
      if (cursor + 2 > data.length) break;
      final ai2 = data.substring(cursor, cursor + 2);

      if (ai2 == '17' && cursor + 8 <= data.length) {
        vencimiento = parsearFechaGs1(data.substring(cursor + 2, cursor + 8));
        cursor += 8;
      } else if (ai2 == '11' && cursor + 8 <= data.length) {
        fabricacion = parsearFechaGs1(data.substring(cursor + 2, cursor + 8));
        cursor += 8;
      } else if (ai2 == '10') {
        cursor += 2;
        final nextGs = data.indexOf(_gs, cursor);
        if (nextGs != -1) {
          lote = data.substring(cursor, nextGs).trim();
          cursor = nextGs + 1;
        } else {
          lote = data.substring(cursor).trim();
          cursor = data.length;
        }
      } else if (ai2 == '21') {
        cursor += 2;
        final nextGs = data.indexOf(_gs, cursor);
        if (nextGs != -1) {
          serie = data.substring(cursor, nextGs).trim();
          cursor = nextGs + 1;
        } else {
          serie = data.substring(cursor).trim();
          cursor = data.length;
        }
      } else {
        break;
      }
    }

    final ean13 = gtin14.startsWith('0') ? gtin14.substring(1) : null;
    final gtinNormalizado = ean13 ?? gtin14;

    return Gs1ParseResult(
      rawCode: raw,
      gtin: gtinNormalizado,
      ean13Equivalente: ean13,
      numeroLote: lote,
      fechaVencimiento: vencimiento,
      fechaFabricacion: fabricacion,
      numeroSerie: serie,
      esGs1Compuesto: true,
      digitoControlValido: validarDigitoControlGtin(gtinNormalizado),
    );
  }

  /// Convierte una fecha GS1 YYMMDD en DateTime.
  /// Según el estándar GS1, si DD == 00 se interpreta como el último día del mes.
  static DateTime? parsearFechaGs1(String rawYyMmDd) {
    final digitos = rawYyMmDd.replaceAll(RegExp(r'\D'), '');
    if (digitos.length < 6) return null;
    final yy = int.tryParse(digitos.substring(0, 2));
    final mm = int.tryParse(digitos.substring(2, 4));
    final dd = int.tryParse(digitos.substring(4, 6));
    if (yy == null || mm == null || dd == null) return null;
    if (mm < 1 || mm > 12 || dd > 31) return null;

    final year = 2000 + yy;
    if (dd == 0) {
      return DateTime(year, mm + 1, 0);
    }
    return DateTime(year, mm, dd);
  }

  /// Valida el dígito de control GS1 Modulo-10 para GTIN-8, GTIN-12, EAN-13 o GTIN-14.
  static bool validarDigitoControlGtin(String gtin) {
    final clean = gtin.trim();
    if (!RegExp(r'^\d+$').hasMatch(clean)) return false;
    if (clean.length != 8 &&
        clean.length != 12 &&
        clean.length != 13 &&
        clean.length != 14) {
      return false;
    }

    var sum = 0;
    final digits = clean.split('').map(int.parse).toList();
    final checkDigit = digits.last;
    final payload = digits.sublist(0, digits.length - 1);

    for (var i = 0; i < payload.length; i++) {
      final posFromRight = payload.length - i;
      final weight = posFromRight.isOdd ? 3 : 1;
      sum += payload[i] * weight;
    }
    final calculated = (10 - (sum % 10)) % 10;
    return calculated == checkDigit;
  }
}

/// Estandarizador clínico de nombres farmacéuticos de SITRA-Luz:
/// Formato: `MEDICAMENTO CANTIDADES (8M/2ML) PRESENTACION_ABREV X UNIDADES_DE_CAJA`
/// Ejemplo: `DEXAFAR 8M/2ML INY X 1`
/// Tabla oficial de abreviaturas:
/// - INYECTABLE = INY
/// - AMPOLLA = AMP
/// - JARABE = JAB
/// - TUBO / UNGÜENTO / CREMA = TBO
/// - TABLETAS = TAB
/// - TABLETAS RECUBIERTAS = TAB REC
/// - CAPSULAS = CAP
/// - INHALADOR = INH
/// - UNIDAD / DISPOSITIVO = UND
/// - SOBRES = SOB
class EstandarizadorNombreFarmaceutico {
  static const List<String> abreviaturasConocidas = [
    'TAB REC',
    'FCO AMP',
    'INY',
    'AMP',
    'JAB',
    'TBO',
    'TAB',
    'CAP',
    'INH',
    'UND',
    'SOB',
    'FCO',
  ];

  /// Devuelve la abreviatura clínica oficial según la presentación o forma farmacéutica.
  static String abreviarPresentacion(String presentacion) {
    final p = _quitarTildes(presentacion).toUpperCase().trim();
    if (p.isEmpty) return 'UND';

    if (p.contains('TAB') && p.contains('REC') ||
        p.contains('COMPRIMIDO RECUBIERTO')) {
      return 'TAB REC';
    }
    if (p == 'INY' || p.contains('INYECTABLE')) return 'INY';
    if (p == 'AMP' || p.contains('AMPOLLA') || p.contains('VIAL')) return 'AMP';
    if (p == 'JAB' || p.contains('JARABE')) return 'JAB';
    if (p == 'TBO' ||
        p.contains('TUBO') ||
        p.contains('UNGUENTO') ||
        p.contains('CREMA') ||
        p.contains('POMADA') ||
        p.contains('GEL')) {
      return 'TBO';
    }
    if (p == 'TAB' || p.contains('TABLETA') || p.contains('COMPRIMIDO')) {
      return 'TAB';
    }
    if (p == 'CAP' || p.contains('CAPSULA')) return 'CAP';
    if (p == 'INH' || p.contains('INHALADOR') || p.contains('AEROSOL')) {
      return 'INH';
    }
    if (p == 'SOB' || p.contains('SOBRE') || p.contains('SACHET')) {
      return 'SOB';
    }
    if (p == 'UND' ||
        p.contains('UNIDAD') ||
        p.contains('JERINGA') ||
        p.contains('DISPOSITIVO') ||
        p.contains('INSUMO') ||
        p.contains('PARCHE')) {
      return 'UND';
    }
    if (p == 'FCO' ||
        p.contains('FRASCO') ||
        p.contains('SOLUCION') ||
        p.contains('GOTAS')) {
      return 'FCO';
    }
    return 'UND';
  }

  /// Construye o actualiza el nombre estandarizado en mayúsculas:
  /// `[NOMBRE_BASE] [CONCENTRACION] [ABREV_PRESENTACION] X [UNIDADES_CAJA]`
  /// Ejemplo: `DEXAFAR 8M/2ML INY X 1`
  static String construirNombreEstandarizado({
    required String nombreBaseOActual,
    String? concentracion,
    required String presentacion,
    required int unidadesCaja,
  }) {
    var base = nombreBaseOActual.trim().toUpperCase();
    if (base.isEmpty) return '';

    final cant = unidadesCaja > 0 ? unidadesCaja : 1;
    final abrev = abreviarPresentacion(presentacion);

    // Remover sufijo previo tipo " INY X 1" o " TAB REC X 100" o " X 10" para no duplicarlo
    base = base.replaceAll(
      RegExp(
        r'\s+(?:TAB\s+REC|FCO\s+AMP|INY|AMP|JAB|TBO|TAB|CAP|INH|UND|SOB|FCO)?\s*X\s*\d+\s*$',
        caseSensitive: false,
      ),
      '',
    ).trim();

    // Si termina con alguna de las abreviaturas sueltas, limpiarla antes de re-agregarla
    for (final ab in abreviaturasConocidas) {
      if (base.endsWith(' $ab')) {
        base = base.substring(0, base.length - ab.length - 1).trim();
        break;
      }
    }

    final concClean = (concentracion ?? '').trim().toUpperCase();
    if (concClean.isNotEmpty &&
        !base.replaceAll(' ', '').contains(concClean.replaceAll(' ', ''))) {
      base = '$base $concClean'.trim();
    }

    base = base.replaceAll(RegExp(r'\s+'), ' ').trim();
    return '$base $abrev X $cant';
  }

  static String _quitarTildes(String input) {
    return input
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'U');
  }
}

/// Resultado de homologar el laboratorio detectado por IA contra la base de datos.
class ResultadoHomologacionLaboratorio {
  /// Siglas o código de laboratorio resultante (el de la BD si coincidió, o las siglas limpias).
  final String laboratorioFinal;

  /// True si coincidió con un laboratorio ya registrado en Supabase.
  final bool coincidioConBaseDatos;

  /// Texto original que detectó la IA antes de homologar.
  final String textoOriginalDetectado;

  const ResultadoHomologacionLaboratorio({
    required this.laboratorioFinal,
    required this.coincidioConBaseDatos,
    required this.textoOriginalDetectado,
  });
}

/// Homologador de laboratorios farmacéuticos:
/// 1. Convierte nombres largos de fabricantes a sus SIGLAS / código corto en mayúsculas.
/// 2. Compara contra los laboratorios ya registrados en la BD (`public.medicamentos` / `public.lotes`);
///    si existe uno parecido o equivalente, devuelve exactamente el que ya está en la BD.
class HomologadorLaboratorio {
  static const Set<String> _palabrasIgnoradas = {
    'LABORATORIO',
    'LABORATORIOS',
    'LAB',
    'LABS',
    'FARMACEUTICA',
    'FARMACEUTICOS',
    'FARMACEUTICO',
    'INDUSTRIALES',
    'INDUSTRIAL',
    'INDUSTRIA',
    'PERU',
    'PERUANA',
    'DEL',
    'DE',
    'LA',
    'EL',
    'LOS',
    'LAS',
    'Y',
    'SA',
    'SAC',
    'SRL',
    'EIRL',
    'SAA',
    'LTD',
    'LTDA',
    'INC',
    'CORP',
    'CORPORATION',
    'COMPANY',
    'CO',
    'PHARMA',
    'PHARMACEUTICAL',
    'PHARMACEUTICALS',
    'HEALTHCARE',
  };

  /// Convierte el nombre de un laboratorio a sus siglas o identificador corto en mayúsculas.
  static String aSiglasONombreCorto(String raw) {
    final limpio = EstandarizadorNombreFarmaceutico._quitarTildes(raw)
        .toUpperCase()
        .replaceAll('.', '')
        .replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (limpio.isEmpty) return '';

    final tokens = limpio
        .split(' ')
        .where((t) => t.isNotEmpty && !_palabrasIgnoradas.contains(t))
        .toList();

    if (tokens.isEmpty) {
      return limpio.split(' ').first;
    }

    // Si solo queda 1 palabra clave (ej. "PORTUGAL", "MEDIFARMA", "HERSIL", "GENFAR", "PFIZER", "ROCHE")
    if (tokens.length == 1) {
      final unico = tokens.first;
      return unico;
    }

    // Si tiene 2 palabras cortas o primera es inicial (ej. "AC FARMA", "B BRAUN", "IQ FARMA")
    if (tokens.length == 2 && (tokens[0].length <= 3 || tokens[1].length <= 5)) {
      return '${tokens[0]} ${tokens[1]}';
    }

    // Si son varias palabras largas, construir siglas de las iniciales o usar la marca principal
    if (tokens.length >= 3) {
      final iniciales = tokens.map((t) => t[0]).join();
      if (iniciales.length >= 3 && iniciales.length <= 6) {
        return iniciales;
      }
    }

    return tokens.first;
  }

  /// Compara el laboratorio detectado por IA con los registrados en la BD.
  /// Si hay uno igual o muy parecido en la BD, devuelve el de la BD.
  static ResultadoHomologacionLaboratorio homologar({
    required String? detectadoPorIa,
    required List<String> laboratoriosEnBd,
  }) {
    final original = (detectadoPorIa ?? '').trim();
    if (original.isEmpty) {
      return const ResultadoHomologacionLaboratorio(
        laboratorioFinal: '',
        coincidioConBaseDatos: false,
        textoOriginalDetectado: '',
      );
    }

    final siglasIa = aSiglasONombreCorto(original);
    final normOriginal = _normalizarParaComparacion(original);
    final normSiglas = _normalizarParaComparacion(siglasIa);

    String? mejorMatchBd;
    double mejorScore = 0.0;

    for (final labBd in laboratoriosEnBd) {
      final bdClean = labBd.trim();
      if (bdClean.isEmpty) continue;

      final normBd = _normalizarParaComparacion(bdClean);
      final siglasBd = _normalizarParaComparacion(aSiglasONombreCorto(bdClean));

      if (normBd.isEmpty) continue;

      // 1. Coincidencia exacta normalizada o de siglas
      if (normBd == normOriginal ||
          normBd == normSiglas ||
          (siglasBd.isNotEmpty &&
              (siglasBd == normSiglas || siglasBd == normOriginal))) {
        return ResultadoHomologacionLaboratorio(
          laboratorioFinal: bdClean,
          coincidioConBaseDatos: true,
          textoOriginalDetectado: original,
        );
      }

      // 2. Contención directa de marca principal (mínimo 4 letras)
      if (normSiglas.length >= 4 &&
          (normBd.contains(normSiglas) || normSiglas.contains(normBd))) {
        final score = 0.90;
        if (score > mejorScore) {
          mejorScore = score;
          mejorMatchBd = bdClean;
        }
      } else if (siglasBd.length >= 4 &&
          (normOriginal.contains(siglasBd) || siglasBd.contains(normSiglas))) {
        final score = 0.88;
        if (score > mejorScore) {
          mejorScore = score;
          mejorMatchBd = bdClean;
        }
      } else {
        // 3. Similitud de caracteres (Levenshtein normalizado)
        final sim1 = _similitud(normSiglas, normBd);
        final sim2 = _similitud(normSiglas, siglasBd);
        final maxSim = sim1 > sim2 ? sim1 : sim2;
        if (maxSim >= 0.75 && maxSim > mejorScore) {
          mejorScore = maxSim;
          mejorMatchBd = bdClean;
        }
      }
    }

    if (mejorMatchBd != null) {
      return ResultadoHomologacionLaboratorio(
        laboratorioFinal: mejorMatchBd,
        coincidioConBaseDatos: true,
        textoOriginalDetectado: original,
      );
    }

    return ResultadoHomologacionLaboratorio(
      laboratorioFinal: siglasIa.isNotEmpty ? siglasIa : original.toUpperCase(),
      coincidioConBaseDatos: false,
      textoOriginalDetectado: original,
    );
  }

  static String _normalizarParaComparacion(String input) {
    return EstandarizadorNombreFarmaceutico._quitarTildes(input)
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static double _similitud(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;
    final dist = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    return 1.0 - (dist / maxLen);
  }

  static int _levenshtein(String s, String t) {
    final m = s.length;
    final n = t.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        final del = dp[i - 1][j] + 1;
        final ins = dp[i][j - 1] + 1;
        final sub = dp[i - 1][j - 1] + cost;
        var minVal = del < ins ? del : ins;
        if (sub < minVal) minVal = sub;
        dp[i][j] = minVal;
      }
    }
    return dp[m][n];
  }
}

/// Entidad que almacena los datos extraídos y validados de forma cruzada (HU-014 / HU-015)
/// combinando el escaneo GS1/GTIN, el catálogo real de Supabase y la extracción multimodal
/// de 1 a 4 fotografías del empaque por IA (Gemini Vision).
class MedicamentoExtraccionIA {
  final String gtin;
  final String nombreComercial;
  final String? nombreBase;
  final String? concentracion;
  final String principioActivo;
  final String presentacion;
  final String categoria; // 'MEDICAMENTO' | 'DISPOSITIVO_MEDICO'
  final String? laboratorio;
  final bool laboratorioHomologadoBd;
  final String? codArt;
  final double? precioKairos;
  final String? registroSanitario;
  final String unidadPresentacion;
  final int cantidadPorPresentacion;
  final String numeroLote;
  final DateTime? fechaVencimiento;
  final DateTime? fechaFabricacion;
  final bool requiereCadenaFrio;
  final double temperaturaMin;
  final double temperaturaMax;
  final String? fotoPath;
  final List<String> fotosPaths;

  /// Metadatos de trazabilidad y sincronización entre HU-014 y HU-015
  final bool existeEnCatalogo;
  final String? medicamentoExistenteId;
  final bool extraidoPorIaReal;
  final String confianza; // 'ALTA' | 'MEDIA' | 'BAJA' | 'SOLO_CODIGO'
  final String origenDatos;
  final List<String> alertasValidacion;

  const MedicamentoExtraccionIA({
    required this.gtin,
    required this.nombreComercial,
    this.nombreBase,
    this.concentracion,
    required this.principioActivo,
    required this.presentacion,
    this.categoria = 'MEDICAMENTO',
    this.laboratorio,
    this.laboratorioHomologadoBd = false,
    this.codArt,
    this.precioKairos,
    this.registroSanitario,
    this.unidadPresentacion = 'tableta',
    this.cantidadPorPresentacion = 1,
    this.numeroLote = '',
    this.fechaVencimiento,
    this.fechaFabricacion,
    this.requiereCadenaFrio = false,
    this.temperaturaMin = 2.0,
    this.temperaturaMax = 8.0,
    this.fotoPath,
    this.fotosPaths = const [],
    this.existeEnCatalogo = false,
    this.medicamentoExistenteId,
    this.extraidoPorIaReal = false,
    this.confianza = 'ALTA',
    this.origenDatos = 'Catálogo Supabase + Validación IA',
    this.alertasValidacion = const [],
  });

  /// Devuelve todas las rutas de fotografías disponibles (1 a 4 fotos).
  List<String> get todasLasFotos {
    if (fotosPaths.isNotEmpty) return fotosPaths;
    if (fotoPath != null && fotoPath!.trim().isNotEmpty) return [fotoPath!];
    return const [];
  }

  /// Indica si los datos maestros obligatorios del producto están presentes.
  bool get tieneDatosCatalogoCompletos =>
      gtin.trim().isNotEmpty &&
      nombreComercial.trim().isNotEmpty &&
      principioActivo.trim().isNotEmpty &&
      presentacion.trim().isNotEmpty;

  /// Formatea la fecha de vencimiento a DD/MM/AAAA para rellenar el TextFormField.
  String get fechaVencimientoFormateada {
    final fv = fechaVencimiento;
    if (fv == null) return '';
    final d = fv.day.toString().padLeft(2, '0');
    final m = fv.month.toString().padLeft(2, '0');
    return '$d/$m/${fv.year}';
  }

  /// Formatea la fecha de fabricación a DD/MM/AAAA para rellenar el TextFormField.
  String get fechaFabricacionFormateada {
    final ff = fechaFabricacion;
    if (ff == null) return '';
    final d = ff.day.toString().padLeft(2, '0');
    final m = ff.month.toString().padLeft(2, '0');
    return '$d/$m/${ff.year}';
  }

  MedicamentoExtraccionIA copyWith({
    String? gtin,
    String? nombreComercial,
    String? nombreBase,
    String? concentracion,
    String? principioActivo,
    String? presentacion,
    String? categoria,
    String? laboratorio,
    bool? laboratorioHomologadoBd,
    String? codArt,
    double? precioKairos,
    String? registroSanitario,
    String? unidadPresentacion,
    int? cantidadPorPresentacion,
    String? numeroLote,
    DateTime? fechaVencimiento,
    DateTime? fechaFabricacion,
    bool? requiereCadenaFrio,
    double? temperaturaMin,
    double? temperaturaMax,
    String? fotoPath,
    List<String>? fotosPaths,
    bool? existeEnCatalogo,
    String? medicamentoExistenteId,
    bool? extraidoPorIaReal,
    String? confianza,
    String? origenDatos,
    List<String>? alertasValidacion,
  }) {
    return MedicamentoExtraccionIA(
      gtin: gtin ?? this.gtin,
      nombreComercial: nombreComercial ?? this.nombreComercial,
      nombreBase: nombreBase ?? this.nombreBase,
      concentracion: concentracion ?? this.concentracion,
      principioActivo: principioActivo ?? this.principioActivo,
      presentacion: presentacion ?? this.presentacion,
      categoria: categoria ?? this.categoria,
      laboratorio: laboratorio ?? this.laboratorio,
      laboratorioHomologadoBd:
          laboratorioHomologadoBd ?? this.laboratorioHomologadoBd,
      codArt: codArt ?? this.codArt,
      precioKairos: precioKairos ?? this.precioKairos,
      registroSanitario: registroSanitario ?? this.registroSanitario,
      unidadPresentacion: unidadPresentacion ?? this.unidadPresentacion,
      cantidadPorPresentacion:
          cantidadPorPresentacion ?? this.cantidadPorPresentacion,
      numeroLote: numeroLote ?? this.numeroLote,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      fechaFabricacion: fechaFabricacion ?? this.fechaFabricacion,
      requiereCadenaFrio: requiereCadenaFrio ?? this.requiereCadenaFrio,
      temperaturaMin: temperaturaMin ?? this.temperaturaMin,
      temperaturaMax: temperaturaMax ?? this.temperaturaMax,
      fotoPath: fotoPath ?? this.fotoPath,
      fotosPaths: fotosPaths ?? this.fotosPaths,
      existeEnCatalogo: existeEnCatalogo ?? this.existeEnCatalogo,
      medicamentoExistenteId:
          medicamentoExistenteId ?? this.medicamentoExistenteId,
      extraidoPorIaReal: extraidoPorIaReal ?? this.extraidoPorIaReal,
      confianza: confianza ?? this.confianza,
      origenDatos: origenDatos ?? this.origenDatos,
      alertasValidacion: alertasValidacion ?? this.alertasValidacion,
    );
  }

  /// Construye la entidad a partir de la respuesta JSON estructurada de Gemini Vision / Edge Function,
  /// fusionando de forma segura con datos previos del catálogo Supabase, código GS1 y laboratorios registrados.
  factory MedicamentoExtraccionIA.fromStructuredJson(
    Map<String, dynamic> json, {
    required String gtinEscaneado,
    String? fotoPath,
    List<String> fotosPaths = const [],
    Gs1ParseResult? gs1,
    Map<String, dynamic>? catalogoExistente,
    List<String> laboratoriosEnBd = const [],
  }) {
    String limparTexto(dynamic val) {
      if (val == null) return '';
      final s = val.toString().trim();
      if (s.toLowerCase() == 'null' ||
          s.toLowerCase() == 'n/a' ||
          s.toLowerCase() == 'no visible' ||
          s.toLowerCase() == 'no legible') {
        return '';
      }
      return s;
    }

    DateTime? parsearFechaFlexible(dynamic val) {
      final s = limparTexto(val);
      if (s.isEmpty) return null;
      // Intentar YYYY-MM-DD o YYYY-MM
      final isoMatch = RegExp(r'^(\d{4})[-/](\d{1,2})(?:[-/](\d{1,2}))?$')
          .firstMatch(s);
      if (isoMatch != null) {
        final y = int.parse(isoMatch.group(1)!);
        final m = int.parse(isoMatch.group(2)!);
        final d = isoMatch.group(3) != null ? int.parse(isoMatch.group(3)!) : 0;
        if (m >= 1 && m <= 12) {
          return d == 0 ? DateTime(y, m + 1, 0) : DateTime(y, m, d);
        }
      }
      // Intentar DD/MM/YYYY o MM/YYYY
      final latamMatch =
          RegExp(r'^(?:(\d{1,2})[-/])?(\d{1,2})[-/](\d{4})$').firstMatch(s);
      if (latamMatch != null) {
        final d =
            latamMatch.group(1) != null ? int.parse(latamMatch.group(1)!) : 0;
        final m = int.parse(latamMatch.group(2)!);
        final y = int.parse(latamMatch.group(3)!);
        if (m >= 1 && m <= 12) {
          return d == 0 ? DateTime(y, m + 1, 0) : DateTime(y, m, d);
        }
      }
      return DateTime.tryParse(s);
    }

    String normalizarUnidad(String raw) {
      final u = raw.toLowerCase().trim();
      if (u.contains('tableta') || u.contains('comprimido') || u == 'tab') {
        return 'tableta';
      }
      if (u.contains('capsula') || u.contains('cápsula') || u == 'cap') {
        return 'capsula';
      }
      if (u.contains('ampolla') || u.contains('inyectable') || u == 'amp' || u == 'iny') {
        return 'ampolla';
      }
      if (u.contains('vial') || u.contains('frasco ampolla')) return 'vial';
      if (u.contains('frasco') ||
          u.contains('jarabe') ||
          u.contains('gotas') ||
          u == 'jab' ||
          u == 'fco') {
        return 'frasco';
      }
      if (u.contains('sobre') || u.contains('sachet') || u == 'sob') {
        return 'sobre';
      }
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

    final catRaw = limparTexto(
      json['categoria'] ?? catalogoExistente?['categoria'],
    ).toUpperCase();
    final categoria = catRaw == 'DISPOSITIVO_MEDICO'
        ? 'DISPOSITIVO_MEDICO'
        : 'MEDICAMENTO';

    final nombreBaseIa = limparTexto(json['nombre_base']);
    final concentracionIa = limparTexto(json['concentracion']);
    final nombreIaRaw = limparTexto(json['nombre_comercial']);
    final nombreCat = limparTexto(catalogoExistente?['nombre_comercial']);
    final principioIa = limparTexto(json['principio_activo']);
    final principioCat = limparTexto(catalogoExistente?['principio_activo']);
    final presentacionIa = limparTexto(json['presentacion']);
    final presentacionCat = limparTexto(catalogoExistente?['presentacion']);
    final labIa = limparTexto(json['laboratorio']);
    final labCat = limparTexto(catalogoExistente?['laboratorio']);
    final regIa = limparTexto(json['registro_sanitario']);
    final regCat = limparTexto(catalogoExistente?['registro_sanitario']);
    final gtinIa = limparTexto(
      json['gtin_detectado'] ?? json['gtin'] ?? json['codigo_barras'],
    );

    final presentacionFinal = presentacionCat.isNotEmpty
        ? presentacionCat
        : (presentacionIa.isNotEmpty ? presentacionIa : 'Tableta');

    final unidadRaw = limparTexto(
      json['unidad_presentacion'] ??
          catalogoExistente?['unidad_presentacion'] ??
          presentacionFinal,
    );
    final unidad = unidadRaw.isNotEmpty
        ? normalizarUnidad(unidadRaw)
        : (categoria == 'DISPOSITIVO_MEDICO' ? 'unidad' : 'tableta');

    final cantIa = int.tryParse(
      limparTexto(json['cantidad_por_presentacion']),
    );
    final cantCat = (catalogoExistente?['cantidad_por_presentacion'] as num?)
        ?.toInt();
    final cantidadPorPresentacion = (cantIa != null && cantIa > 0)
        ? cantIa
        : ((cantCat != null && cantCat > 0) ? cantCat : 1);

    // Estandarización del nombre comercial:
    // MEDICAMENTO CANTIDADES (8M/2ML) PRESENTACION_ABREV X UNIDADES_CAJA
    String nombreEstandarizado;
    if (nombreCat.isNotEmpty) {
      nombreEstandarizado = nombreCat;
    } else {
      final baseParaEstandarizar = nombreBaseIa.isNotEmpty
          ? nombreBaseIa
          : nombreIaRaw;
      if (baseParaEstandarizar.isNotEmpty) {
        nombreEstandarizado =
            EstandarizadorNombreFarmaceutico.construirNombreEstandarizado(
              nombreBaseOActual: baseParaEstandarizar,
              concentracion: concentracionIa,
              presentacion: presentacionFinal,
              unidadesCaja: cantidadPorPresentacion,
            );
      } else {
        nombreEstandarizado = '';
      }
    }

    // Homologación del laboratorio en SIGLAS y comparación contra la BD
    final homologacionLab = HomologadorLaboratorio.homologar(
      detectadoPorIa: labCat.isNotEmpty ? labCat : labIa,
      laboratoriosEnBd: laboratoriosEnBd,
    );

    final frioIa = json['requiere_cadena_frio'];
    final frioCat = catalogoExistente?['requiere_cadena_frio'];
    final requiereFrio = frioIa is bool
        ? frioIa
        : (frioCat is bool ? frioCat : false);

    final tempMinIa = double.tryParse(limparTexto(json['temperatura_min']));
    final tempMaxIa = double.tryParse(limparTexto(json['temperatura_max']));
    final tempMinCat =
        (catalogoExistente?['temperatura_min'] as num?)?.toDouble();
    final tempMaxCat =
        (catalogoExistente?['temperatura_max'] as num?)?.toDouble();

    final loteIa = limparTexto(json['numero_lote']);
    final loteFinal = (gs1?.numeroLote?.isNotEmpty == true)
        ? gs1!.numeroLote!
        : loteIa;

    final vencIa = parsearFechaFlexible(json['fecha_vencimiento']);
    final vencFinal = gs1?.fechaVencimiento ?? vencIa;

    final fabIa = parsearFechaFlexible(json['fecha_fabricacion']);
    final fabFinal = gs1?.fechaFabricacion ?? fabIa;

    final alertas = <String>[];
    if (json['alertas_validacion'] is List) {
      for (final item in (json['alertas_validacion'] as List)) {
        final texto = limparTexto(item);
        if (texto.isNotEmpty) alertas.add(texto);
      }
    }

    if (homologacionLab.coincidioConBaseDatos &&
        homologacionLab.textoOriginalDetectado.toUpperCase() !=
            homologacionLab.laboratorioFinal.toUpperCase()) {
      alertas.add(
        'Laboratorio homologado con BD: "${homologacionLab.textoOriginalDetectado}" → "${homologacionLab.laboratorioFinal}".',
      );
    }

    // Validación cruzada entre catálogo existente e IA
    if (catalogoExistente != null &&
        nombreIaRaw.isNotEmpty &&
        nombreCat.isNotEmpty &&
        !nombreCat.toLowerCase().contains(
              nombreIaRaw.split(' ').first.toLowerCase(),
            ) &&
        !nombreIaRaw.toLowerCase().contains(
              nombreCat.split(' ').first.toLowerCase(),
            )) {
      alertas.add(
        'Aviso de validación cruzada: El empaque fotográfico indica "$nombreIaRaw", mientras que el GTIN en catálogo figura como "$nombreCat". Verifique antes de guardar.',
      );
    }

    if (vencFinal != null && !vencFinal.isAfter(DateTime.now())) {
      alertas.add(
        'Alerta FEFO: La fecha de vencimiento detectada (${vencFinal.day.toString().padLeft(2, '0')}/${vencFinal.month.toString().padLeft(2, '0')}/${vencFinal.year}) está vencida o vence hoy.',
      );
    }

    final confianzaRaw = limparTexto(json['confianza']).toUpperCase();
    final confianza = const {'ALTA', 'MEDIA', 'BAJA'}.contains(confianzaRaw)
        ? confianzaRaw
        : 'ALTA';

    final gtinFinal = gtinEscaneado.trim().isNotEmpty
        ? gtinEscaneado.trim()
        : gtinIa;

    final listaFotos = fotosPaths.isNotEmpty
        ? fotosPaths
        : (fotoPath != null && fotoPath.trim().isNotEmpty
              ? <String>[fotoPath]
              : const <String>[]);

    return MedicamentoExtraccionIA(
      gtin: gtinFinal,
      nombreComercial: nombreEstandarizado,
      nombreBase: nombreBaseIa.isNotEmpty ? nombreBaseIa : null,
      concentracion: concentracionIa.isNotEmpty ? concentracionIa : null,
      principioActivo: principioCat.isNotEmpty ? principioCat : principioIa,
      presentacion: presentacionFinal,
      categoria: categoria,
      laboratorio: homologacionLab.laboratorioFinal.isEmpty
          ? null
          : homologacionLab.laboratorioFinal,
      laboratorioHomologadoBd: homologacionLab.coincidioConBaseDatos,
      codArt: limparTexto(catalogoExistente?['cod_art']).isEmpty
          ? null
          : limparTexto(catalogoExistente?['cod_art']),
      precioKairos: catalogoExistente?['precio_kairos'] != null
          ? double.tryParse(catalogoExistente!['precio_kairos'].toString())
          : null,
      registroSanitario: (regCat.isNotEmpty ? regCat : regIa).isEmpty
          ? null
          : (regCat.isNotEmpty ? regCat : regIa),
      unidadPresentacion: unidad,
      cantidadPorPresentacion: cantidadPorPresentacion,
      numeroLote: loteFinal,
      fechaVencimiento: vencFinal,
      fechaFabricacion: fabFinal,
      requiereCadenaFrio: requiereFrio,
      temperaturaMin: tempMinIa ?? tempMinCat ?? 2.0,
      temperaturaMax: tempMaxIa ?? tempMaxCat ?? 8.0,
      fotoPath: listaFotos.isNotEmpty ? listaFotos.first : fotoPath,
      fotosPaths: listaFotos,
      existeEnCatalogo: catalogoExistente != null,
      medicamentoExistenteId: catalogoExistente?['id']?.toString(),
      extraidoPorIaReal: true,
      confianza: confianza,
      origenDatos: catalogoExistente != null
          ? 'Catálogo Supabase + Validación Cruzada Gemini IA (${listaFotos.length} foto${listaFotos.length == 1 ? "" : "s"})'
          : 'Extracción Estructurada Gemini Vision IA (${listaFotos.length} foto${listaFotos.length == 1 ? "" : "s"})',
      alertasValidacion: alertas,
    );
  }
}
