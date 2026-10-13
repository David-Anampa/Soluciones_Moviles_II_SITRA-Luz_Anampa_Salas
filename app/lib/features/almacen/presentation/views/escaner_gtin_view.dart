import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/services/medicamento_ia_service.dart';
import '../../domain/entities/medicamento_extraccion_ia.dart';
import 'registro_medicamento_view.dart';

/// Pantalla de Escaneo de Código GTIN/GS1 mediante Cámara con ML Kit
/// y captura opcional de imagen de la caja para extracción asistida con IA (HU-014).
class EscanerGtinView extends StatefulWidget {
  const EscanerGtinView({super.key});

  @override
  State<EscanerGtinView> createState() => _EscanerGtinViewState();
}

class _EscanerGtinViewState extends State<EscanerGtinView>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _scannerController;
  final ImagePicker _imagePicker = ImagePicker();

  late AnimationController _animController;
  late Animation<double> _scanAnimation;

  String? _codigoDetectado;
  String? _fotoCajaPath;
  bool _procesandoIa = false;
  bool _scannerActivo = true;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (!_scannerActivo || _codigoDetectado != null) return;

    for (final barcode in capture.barcodes) {
      final valor = barcode.rawValue;
      if (valor != null && valor.trim().isNotEmpty) {
        setState(() {
          _codigoDetectado = valor.trim();
          _scannerActivo = false;
        });
        _scannerController.stop();
        break;
      }
    }
  }

  Future<void> _capturarFotoCaja(ImageSource source) async {
    try {
      final XFile? imagen = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (imagen != null) {
        setState(() {
          _fotoCajaPath = imagen.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo acceder a la cámara: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _reiniciarEscaneo() {
    setState(() {
      _codigoDetectado = null;
      _scannerActivo = true;
    });
    _scannerController.start();
  }

  void _seleccionarCodigoDemo(MedicamentoExtraccionIA demo) {
    setState(() {
      _codigoDetectado = demo.gtin;
      _scannerActivo = false;
    });
    _scannerController.stop();
  }

  Future<void> _continuarConExtraccionIa() async {
    if (_codigoDetectado == null) return;

    setState(() => _procesandoIa = true);

    try {
      final resultado = await MedicamentoIaService.procesarGtinYFoto(
        gtin: _codigoDetectado!,
        fotoCajaPath: _fotoCajaPath,
      );

      if (!mounted) return;

      // HU-015: Navegar a la pantalla de revisión.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RegistroMedicamentoView(datosIniciales: resultado),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar datos: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _procesandoIa = false);
    }
  }

  void _mostrarDialogoSimulador() {
    final ejemplos = MedicamentoIaService.ejemplosDemo;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_2_rounded, color: AppColors.almacenColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Simulador de Códigos GTIN / GS1',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Seleccione un medicamento del catálogo para probar el flujo sin escáner físico:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: ejemplos.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final item = ejemplos[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: item.requiereCadenaFrio
                            ? Colors.cyan.shade100
                            : AppColors.surfaceVariant,
                        child: Icon(
                          item.requiereCadenaFrio
                              ? Icons.ac_unit_rounded
                              : Icons.medication_rounded,
                          color: item.requiereCadenaFrio
                              ? Colors.cyan.shade800
                              : AppColors.almacenColor,
                          size: 20,
                        ),
                      ),
                      title: Text(item.nombreComercial ?? 'Medicamento'),
                      subtitle: Text('GTIN: ${item.gtin} • ${item.presentacion}'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _seleccionarCodigoDemo(item);
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
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Visor de Cámara en vivo (o vista alternativa si no hay soporte de cámara)
          if (!isDesktop)
            MobileScanner(
              controller: _scannerController,
              onDetect: _onBarcodeDetected,
            )
          else
            Container(
              color: const Color(0xFF121820),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    const Text(
                      'Visor de Cámara activo en dispositivo móvil',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.almacenColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _mostrarDialogoSimulador,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Usar Códigos de Prueba'),
                    ),
                  ],
                ),
              ),
            ),

          // 2. HUD y Marco de Escaneo
          SafeArea(
            child: Column(
              children: [
                // Barra superior de controles de cámara
                _buildTopBar(),

                // Área de encuadre con animación láser
                Expanded(
                  child: Center(
                    child: _buildScannerOverlay(),
                  ),
                ),

                // Panel inferior de estado y captura de foto
                _buildBottomPanel(),
              ],
            ),
          ),

          // 3. Indicador de carga al procesar IA
          if (_procesandoIa)
            Container(
              color: Colors.black87,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.almacenColor),
                      const SizedBox(height: 16),
                      const Text(
                        'Extrayendo datos con IA...',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Validación cruzada GTIN + Gemini OCR',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Escaneo GTIN / GS1',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Google ML Kit • Reconocimiento Offline',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          // Botón Linterna / Torch
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          // Botón Cambiar Cámara
          IconButton(
            tooltip: 'Cambiar Cámara',
            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
            onPressed: () => _scannerController.switchCamera(),
          ),
          // Botón Simulador de Códigos
          IconButton(
            tooltip: 'Probar Códigos Demo',
            icon: const Icon(Icons.bug_report_outlined, color: Colors.amberAccent),
            onPressed: _mostrarDialogoSimulador,
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    const boxSize = 250.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Cuadro delimitador con esquinas destacadas
        Container(
          width: boxSize,
          height: boxSize,
          decoration: BoxDecoration(
            border: Border.all(
              color: _codigoDetectado != null ? AppColors.success : AppColors.almacenColor.withOpacity(0.6),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Línea de escaneo animada (láser)
              if (_codigoDetectado == null)
                AnimatedBuilder(
                  animation: _scanAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: _scanAnimation.value * (boxSize - 4),
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.almacenColor,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.almacenColor.withOpacity(0.8),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),

        // Indicador de éxito centrado si se detectó
        if (_codigoDetectado != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  '¡CÓDIGO CAPTURADO!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_codigoDetectado == null) ...[
            const Row(
              children: [
                Icon(Icons.center_focus_strong_rounded, color: AppColors.almacenColor),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Apunte la cámara al código de barras del medicamento',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Lee códigos GTIN, GS1, EAN-13 y DataBar de forma instantánea y offline.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.almacenColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _mostrarDialogoSimulador,
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Usar código de prueba'),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Código detectado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: AppColors.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Código GTIN / Barcode:',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      Text(
                        _codigoDetectado!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _reiniciarEscaneo,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Re-escanear'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // HU-014: Foto opcional de la caja.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceVariant),
              ),
              child: Row(
                children: [
                  if (_fotoCajaPath != null && !kIsWeb)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_fotoCajaPath!),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Foto de la caja (opcional)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          _fotoCajaPath != null
                              ? 'Foto lista para validación IA'
                              : 'Ayuda a la IA a cotejar lote y vencimiento',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<ImageSource>(
                    tooltip: 'Tomar o elegir foto',
                    icon: Icon(
                      _fotoCajaPath != null ? Icons.edit_rounded : Icons.camera_alt_rounded,
                      color: AppColors.almacenColor,
                    ),
                    onSelected: _capturarFotoCaja,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: ImageSource.camera,
                        child: Row(
                          children: [
                            Icon(Icons.camera_alt_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('Tomar con Cámara'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: ImageSource.gallery,
                        child: Row(
                          children: [
                            Icon(Icons.photo_library_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('Elegir de Galería'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // HU-015: Continuar a la pantalla de revisión.
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.almacenColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _continuarConExtraccionIa,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text(
                  'EXTRAER DATOS CON IA Y REVISAR',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
