import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../data/services/medicamento_ia_service.dart';
import '../../domain/entities/medicamento_extraccion_ia.dart';
import '../widgets/configurar_gemini_dialog.dart';
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
  bool _tieneGeminiKey = false;
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
    _verificarEstadoGeminiKey();
  }

  Future<void> _verificarEstadoGeminiKey() async {
    final tiene = await MedicamentoIaService.tieneApiKeyConfigurada();
    if (!mounted) return;
    setState(() => _tieneGeminiKey = tiene);
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
    final parsed = Gs1BarcodeParser.parsear(rawCode);
    if (parsed.gtin.isEmpty) return;

    setState(() {
      _codigoBrutoEscaneado = rawCode;
      _gs1Local = parsed;
      _errorSinRedMensaje = null;
    });
    if (!_esPlataformaEscritorio) {
      _scannerController.stop();
    }
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
    setState(() {
      _isProcessingIA = true;
      _errorSinRedMensaje = null;
    });

    try {
      final resultadoIA = await _iaService.procesarEscaneoYFoto(
        gtinEscaneado: _codigoBrutoEscaneado!,
        fotoCajaPath: fotos.isNotEmpty ? fotos.first : null,
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

  /// Permite continuar al formulario conservando el GTIN/GS1 y las fotografías capturadas localmente (RNF-011).
  void _continuarConDatosLocales() {
    if (_codigoBrutoEscaneado == null) return;
    final fotos = _fotosCapturadasValidas;
    final borradorLocal = _iaService.construirBorradorLocal(
      codigoBruto: _codigoBrutoEscaneado!,
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
      _scannerController.start();
    }
  }

  /// Permite ingresar manualmente un código GTIN o cadena GS1-128.
  Future<void> _mostrarDialogoIngresoManualGtin() async {
    final controller = TextEditingController();
    final ingresado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Ingresar Código GTIN / GS1',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Escribe un código EAN-13 (13 dígitos), GTIN-14 o cadena GS1 como (01)07750215001234(17)281231(10)L2026A:',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Código GTIN / GS1 *',
                  hintText: 'Ej: 7750215001234',
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
                onSubmitted: (val) => Navigator.pop(ctx, val.trim()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.almacenColor,
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Confirmar código'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (ingresado != null && ingresado.isNotEmpty) {
      _seleccionarCodigoLocal(ingresado);
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
                                  style: const TextStyle(color: AppColors.error),
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
          IconButton(
            tooltip: _tieneGeminiKey
                ? 'Gemini Vision IA Configurado (Clic para editar)'
                : 'Configurar API Key de Gemini Vision IA',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.key_rounded,
                  color: _tieneGeminiKey ? Colors.greenAccent : Colors.white70,
                ),
                if (_tieneGeminiKey)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () async {
              await ConfigurarGeminiDialog.mostrar(context);
              await _verificarEstadoGeminiKey();
            },
          ),
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
                            icon: const Icon(
                              Icons.edit_note_rounded,
                              size: 16,
                            ),
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

              // Explicación de las 3 a 4 fotos y guardado en galería
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _isProcessingIA
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: AppColors.almacenColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Analizando $cantidadFotos fotografía(s) con Gemini Vision IA...',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Estandarizando nombre (ej. DEXAFAR 8M/2ML INY X 1), extrayendo Lote, Fecha de Caducidad, Registro Sanitario y homologando siglas de Laboratorio con la BD.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
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
                  onPressed: _ejecutarValidacionCruzadaIA,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text(
                    'Continuar solo con código GTIN / llenado manual',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
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

  Widget _buildTarjetaRanuraFoto(int index) {
    final path = _fotosCaras[index];
    final tieneFoto =
        path != null && !kIsWeb && File(path).existsSync();
    final esOpcional = index == 3;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tieneFoto
            ? AppColors.success.withValues(alpha: 0.06)
            : AppColors.surfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tieneFoto
              ? AppColors.success.withValues(alpha: 0.45)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          if (tieneFoto)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(path),
                width: 58,
                height: 58,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(
                esOpcional
                    ? Icons.add_photo_alternate_outlined
                    : Icons.camera_alt_outlined,
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
                    Flexible(
                      child: Text(
                        _titulosCaras[index],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (tieneFoto) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'LISTA',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitulosCaras[index],
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tomar con Cámara (Guarda en Galería)',
            onPressed: () => _capturarFotoEnRanura(index, ImageSource.camera),
            icon: const Icon(
              Icons.camera_alt_rounded,
              color: AppColors.almacenColor,
            ),
          ),
          IconButton(
            tooltip: 'Elegir de Galería',
            onPressed: () => _capturarFotoEnRanura(index, ImageSource.gallery),
            icon: const Icon(
              Icons.photo_library_outlined,
              color: AppColors.textSecondary,
            ),
          ),
          if (tieneFoto)
            IconButton(
              tooltip: 'Quitar foto',
              onPressed: () => setState(() => _fotosCaras[index] = null),
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.error,
              ),
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
                label: const Text(
                  'SELECCIONAR DEL CATÁLOGO REAL EN SUPABASE',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
