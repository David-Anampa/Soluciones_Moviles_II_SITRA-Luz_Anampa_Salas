import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../data/services/medicamento_ia_service.dart';
import '../../domain/entities/medicamento_entity.dart';
import '../../domain/entities/medicamento_extraccion_ia.dart';
import '../states/almacen_state.dart';
import '../viewmodels/almacen_viewmodel.dart';
import 'registro_medicamento_view.dart';

/// Vista de escaneo de código de barras GS1/GTIN y captura multi-ángulo (3 a 4 fotos)
/// del empaque con guardado en Galería y Validación Cruzada por IA (HU-014 / HU-015 / RNF-011).
class EscanerGtinView extends StatefulWidget {
  const EscanerGtinView({super.key});

  @override
  State<EscanerGtinView> createState() => _EscanerGtinViewState();
}

class _EscanerGtinViewState extends State<EscanerGtinView> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final MedicamentoIaService _iaService = MedicamentoIaService();
  final ImagePicker _imagePicker = ImagePicker();

  String? _codigoBrutoEscaneado;
  Gs1ParseResult? _gs1Local;

  /// Hasta 4 fotografías de las caras del empaque:
  /// [0] Cara Frontal (Nombre, concentración, presentación y X unidades)
  /// [1] Lateral / Solapa (Número de Lote y Fecha de Vencimiento)
  /// [2] Reverso Regulatorio (Registro Sanitario RS, Principio Activo y Laboratorio)
  /// [3] Opcional (Código de barras / Detalle adicional)
  final List<String?> _fotosCaras = [null, null, null, null];

  static const List<String> _titulosCaras = [
    '1. Cara Frontal (Nombre y Unid.)',
    '2. Lote y Fecha Vencimiento',
    '3. Reverso (R.S. y Laboratorio)',
    '4. Foto Adicional (Opcional)',
  ];

  static const List<String> _subtitulosCaras = [
    'Marca, concentración (ej. 8M/2ML), presentación y X unidades',
    'Solapa o lateral con Nº de Lote y Fecha de Caducidad',
    'Registro Sanitario (RS DIGEMID), principio activo y fabricante',
    'Opcional: otra cara del empaque o detalle adicional',
  ];

  bool _isProcessingIA = false;
  bool _torchOn = false;
  String? _errorSinRedMensaje;

  bool get _esPlataformaEscritorio =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  List<String> get _fotosCapturadasValidas => _fotosCaras
      .whereType<String>()
      .where((p) => p.trim().isNotEmpty && !kIsWeb && File(p).existsSync())
      .toList();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  /// Paso 1 (RNF-011): Cuando el lector detecta un código de barras localmente sin red.
  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_codigoBrutoEscaneado != null || _isProcessingIA) return;

    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final code = barcodes.first.rawValue!.trim();
      if (code.isNotEmpty) {
        _seleccionarCodigoLocal(code);
      }
    }
  }

  void _seleccionarCodigoLocal(String rawCode) {
    final limpio = rawCode.trim();
    if (limpio.isEmpty) return;

    final parsed = Gs1BarcodeParser.parsear(limpio);
    if (parsed.gtin.isEmpty) {
      if (mounted) {
        MensajesApp.mostrar(
          context,
          'El código ingresado no es válido. Ingresa dígitos numéricos o una cadena GS1.',
          tipo: TipoMensaje.advertencia,
        );
      }
      return;
    }

    if (!_esPlataformaEscritorio) {
      try {
        _scannerController.stop();
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _codigoBrutoEscaneado = limpio;
      _gs1Local = parsed;
      _errorSinRedMensaje = null;
    });
  }

  /// Busca coincidencias del GTIN en la lista ya cargada en memoria por AlmacenViewModel.
  MedicamentoEntity? _buscarEnCatalogoLocalMemoria(Gs1ParseResult gs1) {
    try {
      final vm = Provider.of<AlmacenViewModel>(context, listen: false);
      final st = vm.state;
      if (st is! AlmacenLoaded) return null;
      final candidatos = <String>{gs1.gtin.trim(), gs1.rawCode.trim()};
      if (gs1.gtin.length == 14 && gs1.gtin.startsWith('0')) {
        candidatos.add(gs1.gtin.substring(1));
      } else if (gs1.gtin.length == 13) {
        candidatos.add('0${gs1.gtin}');
      }
      for (final med in st.catalogo) {
        final g = med.gtin.trim();
        if (g.isNotEmpty && candidatos.contains(g)) {
          return med;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Captura una fotografía para una de las 4 ranuras y, si proviene de cámara,
  /// la guarda automáticamente en la Galería del celular (`Pictures/SITRA_Luz`).
  Future<void> _capturarFotoEnRanura(int index, ImageSource source) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (photo == null) return;

      if (source == ImageSource.camera) {
        final guardada =
            await MedicamentoIaService.guardarFotoEnGaleriaDispositivo(
              photo.path,
              etiqueta: 'CARA_${index + 1}',
            );
        if (mounted && guardada) {
          MensajesApp.mostrar(
            context,
            'Foto ${index + 1} guardada en la Galería del dispositivo (álbum SITRA_Luz).',
            tipo: TipoMensaje.exito,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _fotosCaras[index] = photo.path;
        _errorSinRedMensaje = null;
      });
    } catch (e) {
      if (!mounted) return;
      MensajesApp.mostrar(
        context,
        'No se pudo capturar la foto ${index + 1}: $e',
        tipo: TipoMensaje.error,
      );
    }
  }

  /// Toma la siguiente fotografía pendiente con la cámara de forma rápida.
  Future<void> _tomarSiguienteFotoPendiente() async {
    var slot = _fotosCaras.indexWhere((f) => f == null);
    if (slot == -1) slot = 3; // Si ya están las 4, reemplaza la 4.ª opcional
    await _capturarFotoEnRanura(slot, ImageSource.camera);
  }

  /// Procesa el código escaneado y todas las fotos capturadas (1 a 4) con Gemini Vision IA.
  Future<void> _ejecutarValidacionCruzadaIA() async {
    if (_codigoBrutoEscaneado == null) return;

    final fotos = _fotosCapturadasValidas;
    if (fotos.isEmpty) {
      await _continuarSoloConCodigoGtin();
      return;
    }

    setState(() {
      _isProcessingIA = true;
      _errorSinRedMensaje = null;
    });

    try {
      final resultadoIA = await _iaService.procesarEscaneoYFoto(
        gtinEscaneado: _codigoBrutoEscaneado!,
        fotoCajaPath: fotos.first,
        fotosCajaPaths: fotos,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RegistroMedicamentoView(
            datosIniciales: resultadoIA,
            mostrarAdvertenciaIaInicial: resultadoIA.extraidoPorIaReal,
          ),
        ),
      );
    } on SinConexionIaException catch (e) {
      // RNF-011: No perder el código ni las fotos si no hay red; notificar claramente.
      if (!mounted) return;
      setState(() {
        _isProcessingIA = false;
        _errorSinRedMensaje = e.message;
      });
      MensajesApp.mostrar(context, e.message, tipo: TipoMensaje.advertencia);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingIA = false;
      });
      MensajesApp.mostrar(
        context,
        'Error al procesar validación cruzada: $e',
        tipo: TipoMensaje.error,
      );
    }
  }

  /// Continúa únicamente con el código GTIN/GS1 manual o escaneado (sin requerir fotos),
  /// consultando el catálogo en memoria y en Supabase sin arrojar error si es un código nuevo.
  Future<void> _continuarSoloConCodigoGtin([String? codigoOpcional]) async {
    final codigo = (codigoOpcional ?? _codigoBrutoEscaneado ?? '').trim();
    if (codigo.isEmpty) return;

    final gs1 = Gs1BarcodeParser.parsear(codigo);
    final fotos = _fotosCapturadasValidas;

    setState(() {
      _isProcessingIA = true;
      _errorSinRedMensaje = null;
    });

    try {
      // 1. Intentar consultar Supabase o generar borrador desde el servicio
      var resultado = await _iaService.procesarEscaneoYFoto(
        gtinEscaneado: codigo,
        fotoCajaPath: fotos.isNotEmpty ? fotos.first : null,
        fotosCajaPaths: fotos,
      );

      // 2. Si no se encontró en Supabase pero existe en la memoria de AlmacenViewModel, autocompletar
      if (resultado.nombreComercial.isEmpty) {
        final localMed = _buscarEnCatalogoLocalMemoria(gs1);
        if (localMed != null) {
          resultado = MedicamentoExtraccionIA(
            medicamentoExistenteId: localMed.id,
            existeEnCatalogo: true,
            gtin: gs1.gtin.isNotEmpty ? gs1.gtin : localMed.gtin,
            nombreComercial: localMed.nombreComercial,
            principioActivo: localMed.principioActivo,
            presentacion: localMed.presentacion,
            categoria: localMed.categoria,
            unidadPresentacion: localMed.unidadPresentacion,
            cantidadPorPresentacion: localMed.cantidadPorPresentacion,
            laboratorio: localMed.laboratorio,
            codArt: localMed.codArt,
            precioKairos: localMed.precioKairos,
            numeroLote: gs1.numeroLote ?? '',
            fechaVencimiento: gs1.fechaVencimiento,
            registroSanitario: localMed.registroSanitario,
            requiereCadenaFrio: localMed.requiereCadenaFrio,
            temperaturaMin: localMed.temperaturaMin,
            temperaturaMax: localMed.temperaturaMax,
            fotoPath: fotos.isNotEmpty ? fotos.first : null,
            fotosPaths: fotos,
            extraidoPorIaReal: false,
            confianza: 'ALTA',
            origenDatos: 'Catálogo Almacén (${localMed.gtin})',
          );
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RegistroMedicamentoView(
            datosIniciales: resultado,
            mostrarAdvertenciaIaInicial: false,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _continuarConDatosLocales(codigo);
    }
  }

  /// Permite continuar al formulario conservando el GTIN/GS1 y las fotografías capturadas localmente (RNF-011).
  void _continuarConDatosLocales([String? codigoOpcional]) {
    final codigo = (codigoOpcional ?? _codigoBrutoEscaneado ?? '').trim();
    if (codigo.isEmpty) return;
    final fotos = _fotosCapturadasValidas;
    final borradorLocal = _iaService.construirBorradorLocal(
      codigoBruto: codigo,
      fotoCajaPath: fotos.isNotEmpty ? fotos.first : null,
      fotosCajaPaths: fotos,
      avisoAdicional: _errorSinRedMensaje != null
          ? 'Modo sin conexión durante la captura: complete o verifique los datos antes de guardar cuando recupere internet (RNF-011).'
          : null,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RegistroMedicamentoView(datosIniciales: borradorLocal),
      ),
    );
  }

  void _reiniciarEscaneo() {
    setState(() {
      _codigoBrutoEscaneado = null;
      _gs1Local = null;
      for (var i = 0; i < _fotosCaras.length; i++) {
        _fotosCaras[i] = null;
      }
      _isProcessingIA = false;
      _errorSinRedMensaje = null;
    });
    if (!_esPlataformaEscritorio) {
      try {
        _scannerController.start();
      } catch (_) {}
    }
  }

  /// Permite ingresar manualmente un código GTIN o cadena GS1-128 sin errores de ciclo de vida del controlador.
  Future<void> _mostrarDialogoIngresoManualGtin() async {
    final resultado = await showDialog<_ResultadoDialogoGtinManual>(
      context: context,
      builder: (ctx) => const _DialogoIngresoManualGtin(),
    );

    if (!mounted || resultado == null || resultado.codigo.trim().isEmpty) {
      return;
    }

    final codigoLimpio = resultado.codigo.trim();
    if (resultado.irDirectoAlFormulario) {
      _seleccionarCodigoLocal(codigoLimpio);
      await _continuarSoloConCodigoGtin(codigoLimpio);
    } else {
      _seleccionarCodigoLocal(codigoLimpio);
    }
  }

  /// Muestra un selector conectado en vivo a `public.medicamentos` en Supabase.
  Future<void> _mostrarSelectorCatalogoRealSupabase() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _iaService.listarCatalogoRealSupabase(),
              builder: (context, snapshot) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.almacenColor.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.inventory_2_rounded,
                              color: AppColors.almacenColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Catálogo Maestro en Supabase',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Selecciona un producto real de la BD para validar su GTIN',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: Builder(
                          builder: (_) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  '${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                  ),
                                ),
                              );
                            }
                            final items = snapshot.data ?? [];
                            if (items.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No hay medicamentos registrados aún en public.medicamentos.',
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            return ListView.separated(
                              controller: scrollController,
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, index) {
                                final med = items[index];
                                final gtin =
                                    med['gtin']?.toString().trim() ?? '';
                                final nombre =
                                    med['nombre_comercial']?.toString() ?? '';
                                final presentacion =
                                    med['presentacion']?.toString() ?? '';
                                final frio =
                                    med['requiere_cadena_frio'] as bool? ??
                                    false;
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  leading: Icon(
                                    frio
                                        ? Icons.ac_unit_rounded
                                        : Icons.qr_code_2_rounded,
                                    color: frio
                                        ? AppColors.info
                                        : AppColors.almacenColor,
                                  ),
                                  title: Text(
                                    nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'GTIN: ${gtin.isEmpty ? "Sin GTIN" : gtin} • $presentacion',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 15,
                                  ),
                                  onTap: gtin.isEmpty
                                      ? null
                                      : () {
                                          Navigator.pop(ctx);
                                          _seleccionarCodigoLocal(gtin);
                                        },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(
          _codigoBrutoEscaneado == null
              ? '1. Escanear Código GS1 / GTIN'
              : '2. Captura de 3 a 4 Fotos + IA',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_codigoBrutoEscaneado == null && !_esPlataformaEscritorio)
            IconButton(
              icon: Icon(
                _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: _torchOn ? Colors.amber : Colors.white,
              ),
              tooltip: 'Linterna',
              onPressed: () {
                _scannerController.toggleTorch();
                setState(() => _torchOn = !_torchOn);
              },
            ),
        ],
      ),
      body: _codigoBrutoEscaneado == null
          ? _buildVistaEscanerCamara()
          : _buildVistaCapturaFotosMultiplesIA(),
    );
  }

  /// Paso 1: Lector de código de barras ML Kit en vivo.
  Widget _buildVistaEscanerCamara() {
    if (_esPlataformaEscritorio) {
      return _buildFallbackEscritorio();
    }

    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _onBarcodeDetected,
        ),
        Center(
          child: Container(
            width: MediaQuery.sizeOf(context).width < 380 ? 250 : 280,
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.almacenColor, width: 3),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.almacenColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white54,
                  size: 48,
                ),
                SizedBox(height: 8),
                Text(
                  'Alinee el código GS1 / EAN-13 aquí',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.offline_bolt_rounded,
                      color: Colors.greenAccent,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Paso 1 (Offline ML Kit): Escanea el código GS1 o GTIN del empaque.',
                        style: TextStyle(color: Colors.white, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                      ),
                      onPressed: _mostrarDialogoIngresoManualGtin,
                      icon: const Icon(Icons.keyboard_rounded, size: 16),
                      label: const Text(
                        'Digitar GTIN',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amberAccent,
                        side: const BorderSide(color: Colors.amberAccent),
                      ),
                      onPressed: _mostrarSelectorCatalogoRealSupabase,
                      icon: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: const Text(
                        'Catálogo Supabase',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Paso 2: Captura de 3 a 4 fotografías de la caja (con guardado automático en Galería) y análisis IA.
  Widget _buildVistaCapturaFotosMultiplesIA() {
    final gs1 = _gs1Local;
    final fotosValidas = _fotosCapturadasValidas;
    final cantidadFotos = fotosValidas.length;

    return Container(
      width: double.infinity,
      color: AppColors.background,
      child: ContenidoAdaptable(
        anchoMaximo: 720,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tarjeta de confirmación del GTIN / GS1 leído localmente
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Código GS1 / GTIN Capturado',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                              Text(
                                gs1?.gtin ?? _codigoBrutoEscaneado ?? '',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isProcessingIA ? null : _reiniciarEscaneo,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Cambiar'),
                        ),
                      ],
                    ),
                    if (gs1 != null &&
                        (gs1.esGs1Compuesto ||
                            gs1.numeroLote != null ||
                            gs1.fechaVencimiento != null)) ...[
                      const Divider(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          if (gs1.numeroLote != null)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text('Lote GS1: ${gs1.numeroLote}'),
                            ),
                          if (gs1.fechaVencimiento != null)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                'Vence GS1: ${gs1.fechaVencimiento!.day.toString().padLeft(2, '0')}/${gs1.fechaVencimiento!.month.toString().padLeft(2, '0')}/${gs1.fechaVencimiento!.year}',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              if (_errorSinRedMensaje != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            color: AppColors.warning,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sin conexión activa para validación online (RNF-011)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _errorSinRedMensaje!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _isProcessingIA
                                ? null
                                : _ejecutarValidacionCruzadaIA,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Reintentar conexión'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isProcessingIA
                                ? null
                                : _continuarConDatosLocales,
                            icon: const Icon(Icons.edit_note_rounded, size: 16),
                            label: const Text(
                              'Continuar al formulario sin perder datos',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Explicación de las 3 a 4 fotos y guardado en galería / Estado de carga IA mejorado
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _isProcessingIA
                    ? _buildEstadoCargaIA(cantidadFotos, fotosValidas)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.almacenColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.collections_rounded,
                                  color: AppColors.almacenColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Captura las Caras de la Caja (3 + 1 Opcional)',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Cada foto tomada con cámara se guarda en tu Galería (álbum SITRA_Luz) • Capturadas: $cantidadFotos / 4',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Tarjetas de las 4 ranuras de fotografía
                          for (var i = 0; i < 4; i++) ...[
                            _buildTarjetaRanuraFoto(i),
                            if (i < 3) const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),

              const SizedBox(height: 16),

              if (!_isProcessingIA) ...[
                if (cantidadFotos < 4)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.almacenColor,
                      side: const BorderSide(color: AppColors.almacenColor),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _tomarSiguienteFotoPendiente,
                    icon: const Icon(Icons.add_a_photo_rounded),
                    label: Text(
                      'Tomar Foto ${(_fotosCaras.indexWhere((f) => f == null) + 1).clamp(1, 4)} con Cámara (Guarda en Galería)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.almacenColor,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: cantidadFotos > 0
                      ? _ejecutarValidacionCruzadaIA
                      : null,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    cantidadFotos == 0
                        ? 'CAPTURA AL MENOS 1 FOTO (RECOMENDADO 3) PARA IA'
                        : 'ANALIZAR $cantidadFotos FOTO(S) CON IA Y RELLENAR DATOS',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _continuarSoloConCodigoGtin(),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text(
                    'Continuar solo con código GTIN / llenado manual',
                    style: TextStyle(
                      color: AppColors.almacenColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Interfaz de carga compacta y moderna mientras Gemini Vision IA o el catálogo procesan la captura.
  Widget _buildEstadoCargaIA(int cantidadFotos, List<String> fotosValidas) {
    final analizandoFotos = cantidadFotos > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.almacenColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.2,
                    color: AppColors.almacenColor,
                  ),
                ),
                Icon(
                  analizandoFotos
                      ? Icons.auto_awesome_rounded
                      : Icons.qr_code_scanner_rounded,
                  color: AppColors.almacenColor,
                  size: 26,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            analizandoFotos
                ? 'Procesando $cantidadFotos foto(s) con Gemini IA'
                : 'Verificando código GTIN en catálogo',
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            analizandoFotos
                ? 'Extrayendo datos del empaque automáticamente...'
                : 'Buscando coincidencias del producto para autocompletar...',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (fotosValidas.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: fotosValidas
                  .map(
                    (f) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(f),
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: const [
              _PildoraPasoIA(
                icono: Icons.medication_outlined,
                texto: 'Nombre y Conc.',
              ),
              _PildoraPasoIA(
                icono: Icons.event_available_outlined,
                texto: 'Lote y Venc.',
              ),
              _PildoraPasoIA(
                icono: Icons.verified_outlined,
                texto: 'R.S. y Lab.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tarjeta de captura rediseñada en 2 niveles para que el título y subtítulo
  /// ocupen todo el ancho disponible y nunca se corten verticalmente letra por letra.
  Widget _buildTarjetaRanuraFoto(int index) {
    final path = _fotosCaras[index];
    final tieneFoto = path != null && !kIsWeb && File(path).existsSync();
    final esOpcional = index == 3;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tieneFoto
            ? AppColors.success.withValues(alpha: 0.06)
            : AppColors.surfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tieneFoto
              ? AppColors.success.withValues(alpha: 0.45)
              : Colors.grey.shade300,
          width: tieneFoto ? 1.3 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tieneFoto)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(path),
                        width: 62,
                        height: 62,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Icon(
                    esOpcional
                        ? Icons.add_photo_alternate_outlined
                        : Icons.camera_alt_outlined,
                    size: 26,
                    color: esOpcional
                        ? AppColors.textSecondary
                        : AppColors.almacenColor,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tieneFoto
                                ? AppColors.success.withValues(alpha: 0.16)
                                : (esOpcional
                                      ? Colors.grey.shade200
                                      : AppColors.almacenColor.withValues(
                                          alpha: 0.12,
                                        )),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tieneFoto
                                ? 'LISTA ✓'
                                : (esOpcional ? 'OPCIONAL' : 'RECOMENDADA'),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: tieneFoto
                                  ? AppColors.success
                                  : (esOpcional
                                        ? AppColors.textSecondary
                                        : AppColors.almacenColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _titulosCaras[index],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitulosCaras[index],
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.almacenColor.withValues(
                      alpha: 0.12,
                    ),
                    foregroundColor: AppColors.almacenColor,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () =>
                      _capturarFotoEnRanura(index, ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                  label: Text(
                    tieneFoto ? 'Repetir' : 'Cámara',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: Colors.grey.shade300),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () =>
                      _capturarFotoEnRanura(index, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text(
                    'Galería',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (tieneFoto) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Quitar foto',
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.error.withValues(alpha: 0.1),
                    foregroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => setState(() => _fotosCaras[index] = null),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Vista para pruebas en Windows/Linux/macOS cuando no hay cámara de escaneo móvil.
  Widget _buildFallbackEscritorio() {
    return Container(
      width: double.infinity,
      color: AppColors.background,
      child: ContenidoAdaptable(
        anchoMaximo: 560,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.almacenColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                size: 56,
                color: AppColors.almacenColor,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Captura de Código GS1 / GTIN',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'En dispositivos Android/iOS se activa el lector óptico ML Kit en tiempo real. También puedes digitar un código GTIN/GS1 o seleccionar un producto real del catálogo de Supabase.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.almacenColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _mostrarDialogoIngresoManualGtin,
                icon: const Icon(Icons.keyboard_rounded),
                label: const Text('INGRESAR CÓDIGO GTIN / GS1 MANUALMENTE'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.almacenColor,
                  side: const BorderSide(color: AppColors.almacenColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _mostrarSelectorCatalogoRealSupabase,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('SELECCIONAR DEL CATÁLOGO REAL EN SUPABASE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PildoraPasoIA extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _PildoraPasoIA({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: AppColors.almacenColor),
          const SizedBox(width: 5),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultadoDialogoGtinManual {
  final String codigo;
  final bool irDirectoAlFormulario;

  const _ResultadoDialogoGtinManual({
    required this.codigo,
    required this.irDirectoAlFormulario,
  });
}

/// Diálogo con estado propio para ingresar el código de barras manualmente,
/// mostrando vista previa del análisis GS1/GTIN en tiempo real y evitando errores
/// de dispose prematuro del TextEditingController al cerrar el teclado.
class _DialogoIngresoManualGtin extends StatefulWidget {
  const _DialogoIngresoManualGtin();

  @override
  State<_DialogoIngresoManualGtin> createState() =>
      _DialogoIngresoManualGtinState();
}

class _DialogoIngresoManualGtinState extends State<_DialogoIngresoManualGtin> {
  final TextEditingController _controller = TextEditingController();
  String? _mensajeError;
  Gs1ParseResult? _previewGs1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _actualizarPreview(String value) {
    final limpio = value.trim();
    setState(() {
      _mensajeError = null;
      _previewGs1 = limpio.isEmpty ? null : Gs1BarcodeParser.parsear(limpio);
    });
  }

  void _confirmar({required bool irDirectoAlFormulario}) {
    final texto = _controller.text.trim();
    if (texto.isEmpty) {
      setState(() {
        _mensajeError = 'Ingresa un código de barras GTIN o GS1.';
      });
      return;
    }
    final parsed = Gs1BarcodeParser.parsear(texto);
    if (parsed.gtin.isEmpty) {
      setState(() {
        _mensajeError = 'El código no contiene un GTIN válido.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _ResultadoDialogoGtinManual(
        codigo: texto,
        irDirectoAlFormulario: irDirectoAlFormulario,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _previewGs1;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.qr_code_rounded, color: AppColors.almacenColor),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ingresar Código GTIN / GS1',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Escribe un código EAN-13 (13 dígitos), GTIN-14 o cadena GS1 como (01)07750215001234(17)281231(10)L2026A:',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onChanged: _actualizarPreview,
                onSubmitted: (_) => _confirmar(irDirectoAlFormulario: false),
                decoration: InputDecoration(
                  labelText: 'Código GTIN / GS1 *',
                  hintText: 'Ej: 7750215001234',
                  prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                  errorText: _mensajeError,
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _controller.clear();
                            _actualizarPreview('');
                          },
                        )
                      : null,
                ),
              ),
              if (preview != null && preview.gtin.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.almacenColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.almacenColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GTIN detectado: ${preview.gtin}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.almacenColor,
                        ),
                      ),
                      if (preview.numeroLote != null)
                        Text(
                          'Lote GS1: ${preview.numeroLote}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      if (preview.fechaVencimiento != null)
                        Text(
                          'Vencimiento GS1: ${preview.fechaVencimiento!.day.toString().padLeft(2, '0')}/${preview.fechaVencimiento!.month.toString().padLeft(2, '0')}/${preview.fechaVencimiento!.year}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('Cancelar'),
        ),
        OutlinedButton.icon(
          onPressed: () => _confirmar(irDirectoAlFormulario: true),
          icon: const Icon(Icons.edit_note_rounded, size: 17),
          label: const Text('Ir al formulario'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.almacenColor,
          ),
          onPressed: () => _confirmar(irDirectoAlFormulario: false),
          icon: const Icon(Icons.camera_alt_outlined, size: 17),
          label: const Text('Siguiente (Fotos)'),
        ),
      ],
    );
  }
}
