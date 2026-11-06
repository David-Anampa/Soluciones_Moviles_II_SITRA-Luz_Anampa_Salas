import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../data/services/medicamento_ia_service.dart';
import '../../domain/entities/medicamento_extraccion_ia.dart';
import '../states/almacen_state.dart';
import '../viewmodels/almacen_viewmodel.dart';
import '../widgets/configurar_gemini_dialog.dart';
import 'escaner_gtin_view.dart';

/// Formulario de revisión editable y persistencia atómica para registrar un medicamento
/// y dar entrada a su lote en Almacén (HU-014 / HU-015 / HU-024).
class RegistroMedicamentoView extends StatefulWidget {
  final MedicamentoExtraccionIA? datosIniciales;
  final MedicamentoExtraccionIA? datosIA;
  final bool mostrarAdvertenciaIaInicial;

  const RegistroMedicamentoView({
    super.key,
    this.datosIniciales,
    this.datosIA,
    this.mostrarAdvertenciaIaInicial = false,
  });

  @override
  State<RegistroMedicamentoView> createState() =>
      _RegistroMedicamentoViewState();
}

class _RegistroMedicamentoViewState extends State<RegistroMedicamentoView> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  final MedicamentoIaService _iaService = MedicamentoIaService();

  MedicamentoExtraccionIA? _extraccionActiva;
  String? _medicamentoExistenteId;
  bool _existeEnCatalogo = false;
  bool _analizandoFotoIa = false;
  bool _actualizandoPreciosInternamente = false;

  // Controladores de Medicamento
  final _gtinController = TextEditingController();
  final _nombreController = TextEditingController();
  final _principioActivoController = TextEditingController();
  final _codArtController = TextEditingController();
  final _precioKairosController = TextEditingController();
  final _registroSanitarioController = TextEditingController();
  final _laboratorioController = TextEditingController();
  final _laboratorioFocusNode = FocusNode();
  final _cantidadPresentacionController = TextEditingController(text: '1');

  String _categoria = 'MEDICAMENTO';
  String _presentacion = 'Tableta';
  String _unidadPresentacion = 'tableta';
  bool _requiereCadenaFrio = false;
  double _tempMin = 2.0;
  double _tempMax = 8.0;

  /// Hasta 4 fotografías del empaque (3 caras + 4.ª opcional)
  final List<String?> _fotosCaras = [null, null, null, null];
  static const List<String> _etiquetasCortasFotos = [
    '1. Frente',
    '2. Lote/Vto',
    '3. R.S./Lab',
    '4. Opcional',
  ];

  // Controladores de Precios y Lote
  final _costoTotalCajaController = TextEditingController();
  final _precioCompraController = TextEditingController();
  final _precioVentaController = TextEditingController();
  final _loteController = TextEditingController();
  final _proveedorController = TextEditingController();
  final _numBoletaController = TextEditingController();
  String _justificacion = 'Compra';
  final _cantidadController = TextEditingController(text: '50');
  final _tempRecepcionController = TextEditingController(text: '4.0');
  DateTime _fechaVencimiento = DateTime.now().add(const Duration(days: 365));
  late final TextEditingController _fechaVencimientoController;
  final _dateMaskFormatter = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  List<String> _laboratoriosBd = const [];

  final List<String> _formasDisponibles = [
    'Tableta',
    'Tableta Recubierta',
    'Cápsula',
    'Ampolla',
    'Frasco Ampolla',
    'Frasco / Solución',
    'Solución Inyectable',
    'Jarabe',
    'Ungüento',
    'Inhalador',
    'Sobre',
    'Jeringa Descartable',
    'Dispositivo Médico / Insumo',
  ];

  final List<String> _unidadesDisponibles = const [
    'tableta',
    'capsula',
    'ampolla',
    'vial',
    'frasco',
    'sobre',
    'parche',
    'unidad',
  ];

  List<String> get _fotosValidas => _fotosCaras
      .whereType<String>()
      .where((p) => p.trim().isNotEmpty && !kIsWeb && File(p).existsSync())
      .toList();

  @override
  void initState() {
    super.initState();
    _fechaVencimientoController = TextEditingController(
      text: _formatearFecha(_fechaVencimiento),
    );

    final inicial = widget.datosIniciales ?? widget.datosIA;
    if (inicial != null) {
      _aplicarExtraccionIA(inicial, notificar: false);
      if (widget.mostrarAdvertenciaIaInicial || inicial.extraidoPorIaReal) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mostrarModalAdvertenciaExtraccionIA(inicial);
          }
        });
      }
    }

    _cargarLaboratoriosDeBaseDatos();
  }

  Future<void> _cargarLaboratoriosDeBaseDatos() async {
    try {
      final labs = await _iaService.listarLaboratoriosRegistradosEnBd();
      if (!mounted || labs.isEmpty) return;
      setState(() => _laboratoriosBd = labs);
    } catch (_) {}
  }

  String _formatearFecha(DateTime d) {
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    return '$dia/$mes/${d.year}';
  }

  DateTime? _parsearFechaDdMmYyyy(String texto) {
    final partes = texto.trim().split('/');
    if (partes.length != 3) return null;
    final d = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    final y = int.tryParse(partes[2]);
    if (d == null || m == null || y == null) return null;
    if (y < 2000 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) {
      return null;
    }
    final candidato = DateTime(y, m, d);
    if (candidato.year != y || candidato.month != m || candidato.day != d) {
      return null;
    }
    return candidato;
  }

  /// Cálculo automático de precios según la regla del equipo:
  /// - Si ingresa Costo Total de Caja (ej. S/ 150) y la caja trae 100 unidades:
  ///   Precio de Costo Unitario = 150 / 100 = S/ 1.50
  /// - Precio de Venta Unitario (+6%) = Costo Unitario * 1.06 (ej. 1.50 * 1.06 = S/ 1.59)
  void _recalcularDesdeCostoTotalCaja() {
    if (_actualizandoPreciosInternamente) return;
    final costoCaja = double.tryParse(
      _costoTotalCajaController.text.trim().replaceAll(',', '.'),
    );
    final unidadesCaja =
        int.tryParse(_cantidadPresentacionController.text.trim()) ?? 1;
    if (costoCaja == null || costoCaja < 0) return;

    final divisor = unidadesCaja > 0 ? unidadesCaja : 1;
    final costoUnitario = costoCaja / divisor;
    final ventaUnitaria = costoUnitario * 1.06;

    _actualizandoPreciosInternamente = true;
    _precioCompraController.text = costoUnitario.toStringAsFixed(2);
    _precioVentaController.text = ventaUnitaria.toStringAsFixed(2);
    if (_precioKairosController.text.trim().isEmpty) {
      _precioKairosController.text = ventaUnitaria.toStringAsFixed(2);
    }
    _actualizandoPreciosInternamente = false;
    setState(() {});
  }

  /// Cuando el usuario digita directamente el Precio de Costo Unitario,
  /// calcula automáticamente el Precio de Venta multiplicándolo por 1.06 (+6%).
  void _recalcularVentaDesdeCostoUnitario() {
    if (_actualizandoPreciosInternamente) return;
    final costoUnitario = double.tryParse(
      _precioCompraController.text.trim().replaceAll(',', '.'),
    );
    if (costoUnitario == null || costoUnitario < 0) return;

    final ventaUnitaria = costoUnitario * 1.06;
    _actualizandoPreciosInternamente = true;
    _precioVentaController.text = ventaUnitaria.toStringAsFixed(2);
    if (_precioKairosController.text.trim().isEmpty) {
      _precioKairosController.text = ventaUnitaria.toStringAsFixed(2);
    }
    _actualizandoPreciosInternamente = false;
    setState(() {});
  }

  /// Estandariza el nombre comercial actual con la tabla de abreviaturas y X unidades:
  /// Ej: `DEXAFAR 8M/2ML INY X 1`
  void _estandarizarNombreActual() {
    final textoActual = _nombreController.text.trim();
    if (textoActual.isEmpty) return;
    final unidades =
        int.tryParse(_cantidadPresentacionController.text.trim()) ?? 1;
    final estandarizado =
        EstandarizadorNombreFarmaceutico.construirNombreEstandarizado(
          nombreBaseOActual: textoActual,
          concentracion: _extraccionActiva?.concentracion,
          presentacion: _presentacion,
          unidadesCaja: unidades > 0 ? unidades : 1,
        );
    setState(() {
      _nombreController.text = estandarizado;
    });
  }

  /// Convierte el laboratorio actual a sus siglas y lo compara contra los laboratorios de la BD.
  void _homologarLaboratorioActual(List<String> sugeridos) {
    final actual = _laboratorioController.text.trim();
    if (actual.isEmpty) return;
    final todosLabs = <String>{..._laboratoriosBd, ...sugeridos}.toList();
    final res = HomologadorLaboratorio.homologar(
      detectadoPorIa: actual,
      laboratoriosEnBd: todosLabs,
    );
    if (res.laboratorioFinal.isNotEmpty) {
      setState(() {
        _laboratorioController.text = res.laboratorioFinal;
      });
      MensajesApp.mostrar(
        context,
        res.coincidioConBaseDatos
            ? 'Laboratorio homologado con registro existente en BD: ${res.laboratorioFinal}'
            : 'Laboratorio abreviado en siglas: ${res.laboratorioFinal}',
        tipo: TipoMensaje.exito,
      );
    }
  }

  /// Sincroniza todos los campos extraídos por HU-014 en el formulario editable de HU-015.
  void _aplicarExtraccionIA(
    MedicamentoExtraccionIA d, {
    bool notificar = true,
  }) {
    void updateFields() {
      _extraccionActiva = d;
      _medicamentoExistenteId = d.medicamentoExistenteId;
      _existeEnCatalogo = d.existeEnCatalogo;

      if (d.gtin.trim().isNotEmpty) {
        _gtinController.text = d.gtin.trim();
      }
      if (d.nombreComercial.trim().isNotEmpty) {
        _nombreController.text = d.nombreComercial.trim();
      }
      if (d.principioActivo.trim().isNotEmpty) {
        _principioActivoController.text = d.principioActivo.trim();
      }
      if (d.codArt != null && d.codArt!.trim().isNotEmpty) {
        _codArtController.text = d.codArt!.trim();
      }
      if (d.precioKairos != null && d.precioKairos! > 0) {
        _precioKairosController.text = d.precioKairos!.toStringAsFixed(2);
      }
      if (d.registroSanitario != null &&
          d.registroSanitario!.trim().isNotEmpty) {
        _registroSanitarioController.text = d.registroSanitario!.trim();
      }
      if (d.laboratorio != null && d.laboratorio!.trim().isNotEmpty) {
        _laboratorioController.text = d.laboratorio!.trim();
      }
      if (d.numeroLote.trim().isNotEmpty) {
        _loteController.text = d.numeroLote.trim();
      }
      if (d.fechaVencimiento != null) {
        _fechaVencimiento = d.fechaVencimiento!;
        _fechaVencimientoController.text = _formatearFecha(_fechaVencimiento);
      }

      _categoria = d.categoria == 'DISPOSITIVO_MEDICO'
          ? 'DISPOSITIVO_MEDICO'
          : 'MEDICAMENTO';

      final pres = d.presentacion.trim();
      if (pres.isNotEmpty) {
        if (!_formasDisponibles.contains(pres)) {
          _formasDisponibles.insert(0, pres);
        }
        _presentacion = pres;
      }

      final uni = d.unidadPresentacion.trim().toLowerCase();
      if (_unidadesDisponibles.contains(uni)) {
        _unidadPresentacion = uni;
      }

      if (d.cantidadPorPresentacion > 0) {
        _cantidadPresentacionController.text =
            d.cantidadPorPresentacion.toString();
      }

      _requiereCadenaFrio = d.requiereCadenaFrio;
      _tempMin = d.temperaturaMin;
      _tempMax = d.temperaturaMax;

      final fotos = d.todasLasFotos;
      for (var i = 0; i < 4; i++) {
        _fotosCaras[i] = i < fotos.length ? fotos[i] : _fotosCaras[i];
      }
    }

    if (notificar && mounted) {
      setState(updateFields);
    } else {
      updateFields();
    }
  }

  /// Modal obligatorio de advertencia cuando la IA rellena automáticamente los campos.
  Future<void> _mostrarModalAdvertenciaExtraccionIA(
    MedicamentoExtraccionIA d,
  ) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Verifique los Datos Extraídos por IA',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    '⚠️ La Inteligencia Artificial también puede cometer errores al leer el empaque. Revise cuidadosamente que cada campo coincida con la caja física antes de guardar.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildFilaResumenModal(
                  'Nombre Estandarizado:',
                  _nombreController.text.isEmpty
                      ? '(Pendiente de completar)'
                      : _nombreController.text,
                  destacar: true,
                ),
                _buildFilaResumenModal(
                  'Código GTIN / Barras:',
                  _gtinController.text.isEmpty
                      ? '(No detectado)'
                      : _gtinController.text,
                ),
                _buildFilaResumenModal(
                  'Número de Lote:',
                  _loteController.text.isEmpty
                      ? '(No visible en foto - ingresar manual)'
                      : _loteController.text,
                ),
                _buildFilaResumenModal(
                  'Fecha de Caducidad:',
                  _fechaVencimientoController.text,
                ),
                _buildFilaResumenModal(
                  'Registro Sanitario (RS):',
                  _registroSanitarioController.text.isEmpty
                      ? '(No detectado)'
                      : _registroSanitarioController.text,
                ),
                _buildFilaResumenModal(
                  'Laboratorio (Siglas):',
                  _laboratorioController.text.isEmpty
                      ? '(No detectado)'
                      : '${_laboratorioController.text}${d.laboratorioHomologadoBd ? " (Homologado con BD)" : ""}',
                ),
                _buildFilaResumenModal(
                  'Presentación / Unid. Caja:',
                  '$_presentacion (${EstandarizadorNombreFarmaceutico.abreviarPresentacion(_presentacion)}) X ${_cantidadPresentacionController.text}',
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.almacenColor,
            ),
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: const Text('Entendido, revisaré los campos'),
          ),
        ],
      ),
    );
  }

  /// Modal general obligatorio de verificación antes de guardar en la Base de Datos
  /// (tanto si se llenó por IA, por código de barras o manualmente).
  Future<bool> _mostrarModalConfirmacionAntesDeGuardar() async {
    final abrev = EstandarizadorNombreFarmaceutico.abreviarPresentacion(
      _presentacion,
    );
    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.almacenColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.assignment_turned_in_rounded,
                color: AppColors.almacenColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Revisión Final Antes de Guardar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Confirma que todos los datos del medicamento y su lote estén correctamente ingresados antes de registrarlos en la base de datos:',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      _buildFilaResumenModal(
                        'Nombre Estandarizado:',
                        _nombreController.text.trim(),
                        destacar: true,
                      ),
                      _buildFilaResumenModal(
                        'Principio Activo:',
                        _principioActivoController.text.trim(),
                      ),
                      _buildFilaResumenModal(
                        'Presentación:',
                        '$_presentacion ($abrev) • X ${_cantidadPresentacionController.text.trim()} unid.',
                      ),
                      _buildFilaResumenModal(
                        'Código GTIN:',
                        _gtinController.text.trim(),
                      ),
                      _buildFilaResumenModal(
                        'Número de Lote:',
                        _loteController.text.trim(),
                        destacar: true,
                      ),
                      _buildFilaResumenModal(
                        'Fecha de Vencimiento:',
                        _fechaVencimientoController.text.trim(),
                        destacar: true,
                      ),
                      _buildFilaResumenModal(
                        'Registro Sanitario (RS):',
                        _registroSanitarioController.text.trim().isEmpty
                            ? 'No especificado'
                            : _registroSanitarioController.text.trim(),
                      ),
                      _buildFilaResumenModal(
                        'Laboratorio (Siglas):',
                        _laboratorioController.text.trim().isEmpty
                            ? 'No especificado'
                            : _laboratorioController.text.trim(),
                      ),
                      const Divider(height: 16),
                      _buildFilaResumenModal(
                        'Costo Unitario (Compra):',
                        'S/ ${_precioCompraController.text.trim()}',
                      ),
                      _buildFilaResumenModal(
                        'Precio Venta (+6%):',
                        'S/ ${_precioVentaController.text.trim()}',
                        destacar: true,
                      ),
                      _buildFilaResumenModal(
                        'Cantidad a Ingresar:',
                        '${_cantidadController.text.trim()} (${_unidadPresentacion.toUpperCase()})',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, false),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Corregir datos'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.almacenColor,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.cloud_upload_rounded, size: 18),
            label: const Text('Confirmar y Guardar'),
          ),
        ],
      ),
    );
    return resultado == true;
  }

  Widget _buildFilaResumenModal(
    String etiqueta,
    String valor, {
    bool destacar = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 148,
            child: Text(
              etiqueta,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: destacar ? FontWeight.bold : FontWeight.w500,
                color: destacar
                    ? AppColors.almacenColor
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _gtinController.dispose();
    _nombreController.dispose();
    _principioActivoController.dispose();
    _codArtController.dispose();
    _precioKairosController.dispose();
    _registroSanitarioController.dispose();
    _laboratorioController.dispose();
    _laboratorioFocusNode.dispose();
    _cantidadPresentacionController.dispose();
    _costoTotalCajaController.dispose();
    _loteController.dispose();
    _proveedorController.dispose();
    _numBoletaController.dispose();
    _precioCompraController.dispose();
    _precioVentaController.dispose();
    _cantidadController.dispose();
    _tempRecepcionController.dispose();
    _fechaVencimientoController.dispose();
    super.dispose();
  }

  Future<void> _abrirEscanerCamara() async {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const EscanerGtinView()),
    );
  }

  Future<void> _capturarFotoEnRanura(int index, ImageSource source) async {
    try {
      final XFile? imagen = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (imagen != null) {
        if (source == ImageSource.camera) {
          final guardada =
              await MedicamentoIaService.guardarFotoEnGaleriaDispositivo(
                imagen.path,
                etiqueta: 'CARA_${index + 1}',
              );
          if (mounted && guardada) {
            MensajesApp.mostrar(
              context,
              'Foto ${index + 1} guardada en la Galería (álbum SITRA_Luz).',
              tipo: TipoMensaje.exito,
            );
          }
        }
        if (mounted) {
          setState(() {
            _fotosCaras[index] = imagen.path;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        MensajesApp.mostrar(
          context,
          'No se pudo acceder a la cámara: $e',
          tipo: TipoMensaje.error,
        );
      }
    }
  }

  /// Ejecuta la extracción con Gemini Vision usando todas las fotos adjuntadas (1 a 4)
  /// y muestra el modal obligatorio de advertencia al terminar.
  Future<void> _ejecutarExtraccionIaEnFormulario() async {
    final rawCode = _gtinController.text.trim();
    final fotos = _fotosValidas;
    if (rawCode.isEmpty && fotos.isEmpty) {
      MensajesApp.mostrar(
        context,
        'Primero escanea/digita el código GTIN o toma las fotografías de la caja.',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }

    setState(() => _analizandoFotoIa = true);
    try {
      final resultado = await _iaService.procesarEscaneoYFoto(
        gtinEscaneado: rawCode,
        fotoCajaPath: fotos.isNotEmpty ? fotos.first : null,
        fotosCajaPaths: fotos,
      );
      if (!mounted) return;
      _aplicarExtraccionIA(resultado);
      if (resultado.extraidoPorIaReal) {
        await _mostrarModalAdvertenciaExtraccionIA(resultado);
      } else {
        MensajesApp.mostrar(
          context,
          resultado.existeEnCatalogo
              ? 'Producto encontrado en el catálogo de Supabase y precargado.'
              : 'Código GS1/GTIN verificado. Completa o captura las fotos del producto.',
          tipo: TipoMensaje.exito,
        );
      }
    } on SinConexionIaException catch (e) {
      if (!mounted) return;
      MensajesApp.mostrar(context, e.message, tipo: TipoMensaje.advertencia);
    } catch (e) {
      if (!mounted) return;
      MensajesApp.mostrar(
        context,
        'No se pudo ejecutar la validación IA: $e',
        tipo: TipoMensaje.error,
      );
    } finally {
      if (mounted) setState(() => _analizandoFotoIa = false);
    }
  }

  Future<void> _seleccionarFechaCalendario() async {
    final hoy = DateTime.now();
    final inicial = _fechaVencimiento.isAfter(hoy)
        ? _fechaVencimiento
        : hoy.add(const Duration(days: 180));
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day + 1),
      lastDate: DateTime(hoy.year + 15, 12, 31),
      helpText: 'Seleccionar Fecha de Caducidad (FEFO)',
    );
    if (seleccionada != null && mounted) {
      setState(() {
        _fechaVencimiento = seleccionada;
        _fechaVencimientoController.text = _formatearFecha(seleccionada);
      });
    }
  }

  Future<void> _guardarRegistro() async {
    if (!_formKey.currentState!.validate()) return;

    final fechaParseada = _parsearFechaDdMmYyyy(
      _fechaVencimientoController.text,
    );
    if (fechaParseada == null) {
      MensajesApp.mostrar(
        context,
        'Ingresa una fecha de caducidad válida en formato DD/MM/AAAA.',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }
    final hoy = DateTime.now();
    final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);
    if (!fechaParseada.isAfter(soloHoy)) {
      MensajesApp.mostrar(
        context,
        'La fecha de vencimiento debe ser posterior a hoy (política FEFO).',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }
    _fechaVencimiento = fechaParseada;

    // Mostrar el Modal General de Revisión antes de guardar
    final confirmado = await _mostrarModalConfirmacionAntesDeGuardar();
    if (!confirmado || !mounted) return;

    // RNF-011: Verificar conectividad antes de enviar el registro a Supabase.
    final hayRed = await _iaService.verificarConectividadActiva();
    if (!hayRed) {
      if (!mounted) return;
      MensajesApp.mostrar(
        context,
        'Sin conexión a internet (RNF-011). No cierres esta pantalla: tus datos están seguros y podrás guardar apenas recuperes señal.',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }

    if (!mounted) return;
    final viewModel = context.read<AlmacenViewModel>();
    final cantidad = int.tryParse(_cantidadController.text.trim()) ?? 0;
    final cantPorPres =
        int.tryParse(_cantidadPresentacionController.text.trim()) ?? 1;
    final tempRecepcion = _requiereCadenaFrio
        ? double.tryParse(_tempRecepcionController.text.trim())
        : null;

    final exito = await viewModel.registrarMedicamentoYPrimerLote(
      medicamentoExistenteId: _medicamentoExistenteId,
      gtin: _gtinController.text.trim(),
      nombreComercial: _nombreController.text.trim(),
      principioActivo: _principioActivoController.text.trim(),
      presentacion: _presentacion,
      categoria: _categoria,
      unidadPresentacion: _unidadPresentacion,
      cantidadPorPresentacion: cantPorPres > 0 ? cantPorPres : 1,
      laboratorio: _laboratorioController.text.trim().isNotEmpty
          ? _laboratorioController.text.trim()
          : null,
      codArt: _codArtController.text.trim(),
      precioKairos: double.tryParse(
        _precioKairosController.text.trim().replaceAll(',', '.'),
      ),
      registroSanitario: _registroSanitarioController.text.trim(),
      requiereCadenaFrio: _requiereCadenaFrio,
      temperaturaMin: _tempMin,
      temperaturaMax: _tempMax,
      numeroLote: _loteController.text.trim(),
      fechaVencimiento: _fechaVencimiento,
      fechaFabricacion: _extraccionActiva?.fechaFabricacion,
      proveedor: _proveedorController.text.trim(),
      precioCompra: double.tryParse(
        _precioCompraController.text.trim().replaceAll(',', '.'),
      ),
      precioVenta: double.tryParse(
        _precioVentaController.text.trim().replaceAll(',', '.'),
      ),
      numBoleta: _numBoletaController.text.trim(),
      justificacion: _justificacion,
      temperaturaRecepcion: tempRecepcion,
      cantidadInicial: cantidad,
    );

    if (!mounted) return;

    if (exito) {
      MensajesApp.mostrar(
        context,
        _existeEnCatalogo
            ? 'Catálogo actualizado y nuevo lote ingresado al Almacén exitosamente.'
            : 'Medicamento nuevo y lote inicial ingresados al Almacén exitosamente.',
        tipo: TipoMensaje.exito,
      );
      Navigator.of(context).pop(true);
    } else {
      MensajesApp.mostrar(
        context,
        viewModel.errorMessage ?? 'No se pudo guardar el ingreso en Supabase.',
        tipo: TipoMensaje.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AlmacenViewModel>();
    final isSaving = vm.isSaving;

    final laboratoriosSugeridos = <String>{
      ..._laboratoriosBd,
      ...(vm.state is AlmacenLoaded ? (vm.state as AlmacenLoaded).catalogo : [])
          .map((m) => m.laboratorio)
          .whereType<String>()
          .where((l) => l.trim().isNotEmpty),
    }.toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: DisenoAdaptable.altoCabecera(
          context,
          base: kToolbarHeight,
        ),
        title: const Text('Revisión e Ingreso de Medicamento'),
        backgroundColor: AppColors.almacenColor,
        foregroundColor: Colors.white,
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Configurar clave de Gemini Vision IA',
            icon: const Icon(Icons.key_rounded),
            onPressed: () => ConfigurarGeminiDialog.mostrar(context),
          ),
          IconButton(
            tooltip: 'Escanear con Cámara (ML Kit + 3-4 Fotos IA)',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: _abrirEscanerCamara,
          ),
        ],
      ),
      body: ContenidoAdaptable(
        anchoMaximo: 1100,
        padding: EdgeInsets.zero,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_extraccionActiva != null)
                    _buildPanelRevisionIA(_extraccionActiva!),

                  // 1. SECCIÓN: DATOS GENERALES DEL MEDICAMENTO
                  _buildSectionHeader(
                    icon: Icons.medication_rounded,
                    title: '1. Ficha Técnica y Nombre Estandarizado (HU-015)',
                    subtitle:
                        'Formato oficial: MEDICAMENTO CANTIDADES ABREV X UNIDADES (ej. DEXAFAR 8M/2ML INY X 1)',
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Clasificación MEDICAMENTO vs DISPOSITIVO_MEDICO
                        DropdownButtonFormField<String>(
                          itemHeight: null,
                          isDense: false,
                          value: _categoria,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Categoría en Catálogo *',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'MEDICAMENTO',
                              child: Text('Medicamento Farmacéutico'),
                            ),
                            DropdownMenuItem(
                              value: 'DISPOSITIVO_MEDICO',
                              child: Text(
                                'Dispositivo Médico / Insumo Quirúrgico',
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _categoria = val;
                                if (val == 'DISPOSITIVO_MEDICO') {
                                  _unidadPresentacion = 'unidad';
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 14),

                        // Código GTIN / Barras + Escáner + Búsqueda en Supabase / IA
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _gtinController,
                                keyboardType: TextInputType.text,
                                decoration: const InputDecoration(
                                  labelText: 'Código GTIN / Código de Barras *',
                                  hintText: 'Ej: 7750215001234',
                                  prefixIcon: Icon(
                                    Icons.qr_code_scanner_rounded,
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Requerido'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.almacenColor,
                                foregroundColor: Colors.white,
                              ),
                              tooltip: 'Abrir Escáner y Captura de 3-4 Fotos',
                              onPressed: _abrirEscanerCamara,
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                            ),
                            const SizedBox(width: 4),
                            IconButton.filledTonal(
                              tooltip:
                                  'Validar GTIN en Supabase / Extraer de Fotos con IA',
                              onPressed: _analizandoFotoIa
                                  ? null
                                  : _ejecutarExtraccionIaEnFormulario,
                              icon: _analizandoFotoIa
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.auto_awesome_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Forma Farmacéutica y Unidades por Caja (antes del nombre para estandarizar al instante)
                        AccionesAdaptables(
                          anchoMinimo: 160,
                          acciones: [
                            DropdownButtonFormField<String>(
                              itemHeight: null,
                              isDense: false,
                              value: _presentacion,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText:
                                    'Presentación (${EstandarizadorNombreFarmaceutico.abreviarPresentacion(_presentacion)})',
                              ),
                              items: _formasDisponibles
                                  .map(
                                    (f) => DropdownMenuItem(
                                      value: f,
                                      child: Text(
                                        '$f (${EstandarizadorNombreFarmaceutico.abreviarPresentacion(f)})',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _presentacion = val);
                                }
                              },
                            ),
                            TextFormField(
                              controller: _cantidadPresentacionController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) =>
                                  _recalcularDesdeCostoTotalCaja(),
                              decoration: const InputDecoration(
                                labelText: 'Unidades por Caja (X UNID) *',
                                hintText: 'Ej: 1, 10, 100',
                                prefixIcon: Icon(Icons.layers_outlined),
                              ),
                              validator: (v) {
                                final n = int.tryParse(v?.trim() ?? '');
                                if (n == null || n <= 0) {
                                  return 'Entero > 0';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Nombre comercial estandarizado + botón de estandarización automática
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nombreController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Nombre Estandarizado (MARCA CANT ABREV X UNID) *',
                                  hintText: 'Ej: DEXAFAR 8M/2ML INY X 1',
                                  prefixIcon: Icon(Icons.label_outline_rounded),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Ingresa el nombre estandarizado'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: FilledButton.tonalIcon(
                                onPressed: _estandarizarNombreActual,
                                icon: const Icon(
                                  Icons.auto_fix_high_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  '${EstandarizadorNombreFarmaceutico.abreviarPresentacion(_presentacion)} X ${_cantidadPresentacionController.text.trim().isEmpty ? "1" : _cantidadPresentacionController.text.trim()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Abreviaturas: INY (Inyectable) • AMP (Ampolla) • JAB (Jarabe) • TBO (Tubo) • TAB (Tabletas) • TAB REC (Tab. Recubiertas) • CAP (Cápsulas) • INH (Inhalador) • UND (Unidad) • SOB (Sobres)',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Principio Activo y Unidad de Dispensación
                        AccionesAdaptables(
                          anchoMinimo: 160,
                          acciones: [
                            TextFormField(
                              controller: _principioActivoController,
                              decoration: const InputDecoration(
                                labelText:
                                    'Principio Activo / Especificación *',
                                hintText: 'Ej: Dexametasona 8mg/2ml',
                                prefixIcon: Icon(Icons.science_outlined),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Ingresa el principio activo'
                                  : null,
                            ),
                            DropdownButtonFormField<String>(
                              itemHeight: null,
                              isDense: false,
                              value: _unidadPresentacion,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Unidad de Dispensación',
                              ),
                              items: _unidadesDisponibles
                                  .map(
                                    (u) => DropdownMenuItem(
                                      value: u,
                                      child: Text(u.toUpperCase()),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _unidadPresentacion = val);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Registro Sanitario (RS) y Código Artículo Interno
                        AccionesAdaptables(
                          anchoMinimo: 160,
                          acciones: [
                            TextFormField(
                              controller: _registroSanitarioController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'RS / Registro Sanitario (DIGEMID)',
                                hintText: 'Ej: EE-04812, EN-01294',
                                prefixIcon: Icon(Icons.verified_outlined),
                              ),
                            ),
                            TextFormField(
                              controller: _codArtController,
                              decoration: const InputDecoration(
                                labelText: 'Código Artículo Interno (Opcional)',
                                hintText: 'Ej: ART-001',
                                prefixIcon: Icon(Icons.tag_rounded),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Laboratorio en SIGLAS con comparación automática en BD
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: RawAutocomplete<String>(
                                textEditingController: _laboratorioController,
                                focusNode: _laboratorioFocusNode,
                                optionsBuilder:
                                    (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) {
                                        return laboratoriosSugeridos;
                                      }
                                      final lowercaseText = textEditingValue
                                          .text
                                          .toLowerCase();
                                      return laboratoriosSugeridos.where((
                                        String option,
                                      ) {
                                        return option.toLowerCase().contains(
                                          lowercaseText,
                                        );
                                      });
                                    },
                                onSelected: (String selection) {
                                  _laboratorioController.text = selection;
                                },
                                fieldViewBuilder:
                                    (
                                      BuildContext context,
                                      TextEditingController
                                      textEditingController,
                                      FocusNode focusNode,
                                      VoidCallback onFieldSubmitted,
                                    ) {
                                      return TextFormField(
                                        controller: textEditingController,
                                        focusNode: focusNode,
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        onFieldSubmitted: (String value) =>
                                            onFieldSubmitted(),
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Laboratorio (Siglas / Homologado con BD)',
                                          hintText:
                                              'Ej: MEDIFARMA, PORTUGAL, HERSIL, IQFARMA',
                                          prefixIcon: Icon(
                                            Icons.business_rounded,
                                          ),
                                        ),
                                      );
                                    },
                                optionsViewBuilder:
                                    (
                                      BuildContext context,
                                      AutocompleteOnSelected<String> onSelected,
                                      Iterable<String> options,
                                    ) {
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 8.0,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxHeight: 200,
                                              maxWidth: 320,
                                            ),
                                            child: ListView.builder(
                                              padding: EdgeInsets.zero,
                                              shrinkWrap: true,
                                              itemCount: options.length,
                                              itemBuilder:
                                                  (
                                                    BuildContext context,
                                                    int index,
                                                  ) {
                                                    final String option =
                                                        options.elementAt(
                                                          index,
                                                        );
                                                    return InkWell(
                                                      onTap: () =>
                                                          onSelected(option),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16.0,
                                                              vertical: 12.0,
                                                            ),
                                                        child: Text(
                                                          option,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                              ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: FilledButton.tonalIcon(
                                onPressed: () => _homologarLaboratorioActual(
                                  laboratoriosSugeridos,
                                ),
                                icon: const Icon(Icons.sync_rounded, size: 18),
                                label: const Text(
                                  'Siglas / BD',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Switch Cadena de Frío
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _requiereCadenaFrio
                                ? Colors.cyan.withValues(alpha: 0.08)
                                : AppColors.surfaceVariant.withValues(
                                    alpha: 0.4,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _requiereCadenaFrio
                                  ? Colors.cyan
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.ac_unit_rounded,
                                color: _requiereCadenaFrio
                                    ? Colors.cyan.shade700
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Requiere Cadena de Frío',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Rango controlado de ${_tempMin.toStringAsFixed(1)} °C a ${_tempMax.toStringAsFixed(1)} °C',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _requiereCadenaFrio,
                                activeThumbColor: Colors.cyan.shade700,
                                onChanged: (v) =>
                                    setState(() => _requiereCadenaFrio = v),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // HU-014 / HU-015: Panel de 3 a 4 fotografías del empaque (guardadas en Galería)
                        _buildPanelCuatroFotosFormulario(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. SECCIÓN: CÁLCULO DE COSTO UNITARIO Y PRECIO DE VENTA (+6%)
                  _buildSectionHeader(
                    icon: Icons.monetization_on_rounded,
                    title: '2. Costo Unitario y Precio de Venta (+6%)',
                    subtitle:
                        'Costo unitario = Costo Caja / Unidades de Caja • Venta = Costo Unitario × 1.06',
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Calculadora rápida: Costo Total de la Caja -> divide entre Unidades por Caja
                        TextFormField(
                          controller: _costoTotalCajaController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => _recalcularDesdeCostoTotalCaja(),
                          decoration: InputDecoration(
                            labelText:
                                'Costo Total de la Caja (S/) — Calcula automático entre ${_cantidadPresentacionController.text.trim().isEmpty ? "1" : _cantidadPresentacionController.text.trim()} unid.',
                            hintText:
                                'Ej: Si la caja de 100 costó 150 → Costo unitario S/ 1.50 y Venta S/ 1.59',
                            prefixIcon: const Icon(Icons.calculate_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        AccionesAdaptables(
                          anchoMinimo: 150,
                          acciones: [
                            TextFormField(
                              controller: _precioCompraController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) =>
                                  _recalcularVentaDesdeCostoUnitario(),
                              decoration: const InputDecoration(
                                labelText: 'Precio Costo Unitario (S/) *',
                                hintText: 'Ej: 1.50',
                                prefixIcon: Icon(Icons.shopping_cart_outlined),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Requerido';
                                }
                                final p = double.tryParse(
                                  v.trim().replaceAll(',', '.'),
                                );
                                if (p == null || p < 0) return 'Monto inválido';
                                return null;
                              },
                            ),
                            TextFormField(
                              controller: _precioVentaController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Precio Venta Unitario (+6% S/) *',
                                hintText: 'Ej: 1.59',
                                prefixIcon: Icon(Icons.sell_outlined),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Requerido';
                                }
                                final p = double.tryParse(
                                  v.trim().replaceAll(',', '.'),
                                );
                                if (p == null || p < 0) return 'Monto inválido';
                                return null;
                              },
                            ),
                            TextFormField(
                              controller: _precioKairosController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Precio Ref. (Kairos)',
                                hintText: 'Ej: 1.59',
                                prefixIcon: Icon(
                                  Icons.monetization_on_outlined,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. SECCIÓN: DATOS DEL LOTE Y STOCK INICIAL
                  _buildSectionHeader(
                    icon: Icons.inventory_2_rounded,
                    title: '3. Recepción Física de Lote y Stock',
                    subtitle:
                        'Ingreso directo al inventario de Almacén General',
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceVariant),
                    ),
                    child: Column(
                      children: [
                        // Número de Lote (manual o escaneado) y Proveedor
                        AccionesAdaptables(
                          anchoMinimo: 150,
                          acciones: [
                            TextFormField(
                              controller: _loteController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText:
                                    'Número de Lote (Manual / Escaneado / IA) *',
                                hintText: 'Ej: L2026-B04',
                                prefixIcon: Icon(Icons.numbers_rounded),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Requerido'
                                  : null,
                            ),
                            TextFormField(
                              controller: _proveedorController,
                              decoration: const InputDecoration(
                                labelText: 'Proveedor / Droguería',
                                hintText: 'Ej: Distribuidora Sur',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Boleta y Justificación
                        AccionesAdaptables(
                          anchoMinimo: 150,
                          acciones: [
                            TextFormField(
                              controller: _numBoletaController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Nº Boleta / Factura',
                                hintText: 'Ej: F001-123',
                                prefixIcon: Icon(Icons.receipt_long_rounded),
                              ),
                            ),
                            DropdownButtonFormField<String>(
                              itemHeight: null,
                              isDense: false,
                              value: _justificacion,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Justificación',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Compra',
                                  child: Text('Compra'),
                                ),
                                DropdownMenuItem(
                                  value: 'Donacion',
                                  child: Text('Donación'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _justificacion = val);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Fecha de vencimiento con máscara + selector de calendario
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _fechaVencimientoController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [_dateMaskFormatter],
                                decoration: const InputDecoration(
                                  labelText: 'Fecha de Caducidad (FEFO) *',
                                  hintText: 'DD/MM/AAAA',
                                  prefixIcon: Icon(
                                    Icons.calendar_month_rounded,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Requerido';
                                  }
                                  final f = _parsearFechaDdMmYyyy(v);
                                  if (f == null) {
                                    return 'Usa formato DD/MM/AAAA válido';
                                  }
                                  final hoy = DateTime.now();
                                  if (!f.isAfter(
                                    DateTime(hoy.year, hoy.month, hoy.day),
                                  )) {
                                    return 'Debe ser posterior a hoy';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: 'Elegir fecha en calendario',
                              onPressed: _seleccionarFechaCalendario,
                              icon: const Icon(Icons.edit_calendar_rounded),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Cantidad a ingresar y temperatura de recepción
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _cantidadController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Cantidad Total de Unidades Recibidas *',
                                  hintText: 'Ej: 100',
                                  prefixIcon: Icon(
                                    Icons.add_shopping_cart_rounded,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Requerido';
                                  }
                                  final n = int.tryParse(v);
                                  if (n == null || n <= 0) return 'Mayor a 0';
                                  return null;
                                },
                              ),
                            ),
                            if (_requiereCadenaFrio) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _tempRecepcionController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Temp. Recepción (°C)',
                                    hintText: 'Ej: 3.8',
                                    prefixIcon: Icon(Icons.thermostat_rounded),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Botón Guardar (abre el Modal General de Verificación)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.almacenColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: isSaving ? null : _guardarRegistro,
                        icon: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.fact_check_rounded),
                        label: Text(
                          isSaving
                              ? 'REGISTRANDO EN SUPABASE...'
                              : (_existeEnCatalogo
                                    ? 'REVISAR Y REGISTRAR NUEVO LOTE'
                                    : 'REVISAR Y GUARDAR MEDICAMENTO + STOCK'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Panel de 3 a 4 fotografías del empaque dentro del formulario editable.
  Widget _buildPanelCuatroFotosFormulario() {
    final totalFotos = _fotosValidas.length;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.collections_rounded,
                color: AppColors.almacenColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fotografías del Empaque ($totalFotos/4) — 4.ª opcional • Guardado en Galería',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(4, (i) {
              final path = _fotosCaras[i];
              final existe =
                  path != null && !kIsWeb && File(path).existsSync();
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _capturarFotoEnRanura(i, ImageSource.camera),
                child: Container(
                  width: 145,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: existe
                          ? AppColors.success
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (existe)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(path),
                            height: 60,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          height: 60,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.add_a_photo_outlined,
                            color: AppColors.almacenColor,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        _etiquetasCortasFotos[i],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Cámara (Guarda en Galería)',
                            onPressed: () =>
                                _capturarFotoEnRanura(i, ImageSource.camera),
                            icon: const Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: AppColors.almacenColor,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Galería',
                            onPressed: () =>
                                _capturarFotoEnRanura(i, ImageSource.gallery),
                            icon: const Icon(
                              Icons.photo_library_outlined,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          if (totalFotos > 0) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _analizandoFotoIa
                    ? null
                    : _ejecutarExtraccionIaEnFormulario,
                icon: _analizandoFotoIa
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  _analizandoFotoIa
                      ? 'Analizando $totalFotos foto(s) con Gemini Vision IA...'
                      : 'Extraer datos completos de las $totalFotos foto(s) con IA',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Panel superior de revisión editable sincronizada entre HU-014 y HU-015.
  Widget _buildPanelRevisionIA(MedicamentoExtraccionIA d) {
    final esAlta = d.confianza == 'ALTA';
    final colorBase = d.extraidoPorIaReal
        ? AppColors.almacenColor
        : (d.existeEnCatalogo ? AppColors.info : Colors.amber.shade800);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorBase.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorBase.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                d.extraidoPorIaReal
                    ? Icons.auto_awesome_rounded
                    : (d.existeEnCatalogo
                          ? Icons.verified_rounded
                          : Icons.qr_code_2_rounded),
                color: colorBase,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revisión Editable Sincronizada (HU-014 / HU-015)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: colorBase,
                      ),
                    ),
                    Text(
                      'Fuente: ${d.origenDatos} • Confianza: ${d.confianza}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (esAlta ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  d.existeEnCatalogo ? 'EN CATÁLOGO' : 'NUEVO GTIN',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: esAlta ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          if (d.alertasValidacion.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final alerta in d.alertasValidacion)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: colorBase,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        alerta,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.almacenColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.almacenColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
