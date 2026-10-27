import 'dart:io';
import '../../../../core/widgets/diseno_adaptable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/medicamento_extraccion_ia.dart';
import '../viewmodels/almacen_viewmodel.dart';
import '../states/almacen_state.dart';
import 'escaner_gtin_view.dart';

/// Formulario para registrar un nuevo medicamento y dar entrada a su primer lote en Almacén.
/// HU-014 / HU-015: Soporta precarga de datos extraídos por IA y cámara.
class RegistroMedicamentoView extends StatefulWidget {
  final MedicamentoExtraccionIA? datosIniciales;

  const RegistroMedicamentoView({super.key, this.datosIniciales});

  @override
  State<RegistroMedicamentoView> createState() =>
      _RegistroMedicamentoViewState();
}

class _RegistroMedicamentoViewState extends State<RegistroMedicamentoView> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  // Controladores de Medicamento
  final _gtinController = TextEditingController();
  final _nombreController = TextEditingController();
  final _principioActivoController = TextEditingController();
  final _codArtController = TextEditingController();
  final _precioKairosController = TextEditingController();
  final _registroSanitarioController = TextEditingController();
  final _laboratorioController = TextEditingController();
  final _laboratorioFocusNode = FocusNode();

  String _presentacion = 'Tableta';
  bool _requiereCadenaFrio = false;
  final double _tempMin = 2.0;
  final double _tempMax = 8.0;
  String? _fotoCajaPath;

  // Controladores de Lote
  final _loteController = TextEditingController();
  final _proveedorController = TextEditingController();
  final _numBoletaController = TextEditingController();
  final _precioCompraController = TextEditingController();
  final _precioVentaController = TextEditingController();
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

  final List<String> _formasDisponibles = [
    'Tableta',
    'Cápsula',
    'Ampolla',
    'Frasco Ampolla',
    'Frasco / Solución',
    'Jarabe',
    'Ungüento',
    'Inhalador',
  ];

  @override
  void initState() {
    super.initState();
    _fechaVencimientoController = TextEditingController(
      text:
          '${_fechaVencimiento.day.toString().padLeft(2, '0')}/${_fechaVencimiento.month.toString().padLeft(2, '0')}/${_fechaVencimiento.year}',
    );

    if (widget.datosIniciales != null) {
      final d = widget.datosIniciales!;
      _gtinController.text = d.gtin;
      _nombreController.text = d.nombreComercial ?? '';
      _principioActivoController.text = d.principioActivo ?? '';
      _codArtController.text = ''; // La IA no suele extraer codArt interno
      _registroSanitarioController.text = d.registroSanitario ?? '';
      _loteController.text = d.numeroLote ?? '';
      if (d.fechaVencimiento != null) {
        _fechaVencimiento = d.fechaVencimiento!;
        _fechaVencimientoController.text =
            '${_fechaVencimiento.day.toString().padLeft(2, '0')}/${_fechaVencimiento.month.toString().padLeft(2, '0')}/${_fechaVencimiento.year}';
      }
      if (d.presentacion != null &&
          _formasDisponibles.contains(d.presentacion)) {
        _presentacion = d.presentacion!;
      }
      _requiereCadenaFrio = d.requiereCadenaFrio;
      _fotoCajaPath = d.fotoCajaPath;
      if (d.temperaturaSugerida != null) {
        _tempRecepcionController.text = d.temperaturaSugerida.toString();
      }
    }
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EscanerGtinView()));
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

  void _generarGtinDemo() {
    final rand = DateTime.now().millisecondsSinceEpoch.toString();
    _gtinController.text = '7750215${rand.substring(rand.length - 6)}';
  }

  Future<void> _guardarRegistro() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = context.read<AlmacenViewModel>();
    final cantidad = int.tryParse(_cantidadController.text.trim()) ?? 0;
    final tempRecepcion = _requiereCadenaFrio
        ? double.tryParse(_tempRecepcionController.text.trim())
        : null;

    final exito = await viewModel.registrarMedicamentoYPrimerLote(
      gtin: _gtinController.text.trim(),
      nombreComercial: _nombreController.text.trim(),
      principioActivo: _principioActivoController.text.trim(),
      presentacion: _presentacion,
      laboratorio: _laboratorioController.text.trim().isNotEmpty
          ? _laboratorioController.text.trim()
          : null,
      codArt: _codArtController.text.trim(),
      precioKairos: double.tryParse(_precioKairosController.text.trim()),
      registroSanitario: _registroSanitarioController.text.trim(),
      requiereCadenaFrio: _requiereCadenaFrio,
      temperaturaMin: _tempMin,
      temperaturaMax: _tempMax,
      numeroLote: _loteController.text.trim(),
      fechaVencimiento: _fechaVencimiento,
      proveedor: _proveedorController.text.trim(),
      precioCompra: double.tryParse(_precioCompraController.text.trim()),
      precioVenta: double.tryParse(_precioVentaController.text.trim()),
      numBoleta: _numBoletaController.text.trim(),
      justificacion: _justificacion,
      temperaturaRecepcion: tempRecepcion,
      cantidadInicial: cantidad,
    );

    if (!mounted) return;

    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ Medicamento y lote inicial ingresados al Almacén exitosamente',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Error: ${viewModel.errorMessage ?? "No se pudo guardar"}',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AlmacenViewModel>();
    final isSaving = vm.isSaving;

    final laboratoriosSugeridos =
        (vm.state is AlmacenLoaded ? (vm.state as AlmacenLoaded).catalogo : [])
            .map((m) => m.laboratorio)
            .whereType<String>()
            .where((l) => l.trim().isNotEmpty)
            .toSet()
            .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: DisenoAdaptable.altoCabecera(
          context,
          base: kToolbarHeight,
        ),
        title: const Text('Ingreso de Medicamento'),
        backgroundColor: AppColors.almacenColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Escanear con Cámara (ML Kit)',
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
                  // HU-015: Revisión de IA si viene del escáner.
                  if (widget.datosIniciales != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade400),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.amber.shade800,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Revisión de datos extraídos por IA',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Fuente: ${widget.datosIniciales!.fuente}. Revisa y corrige si es necesario antes de confirmar el registro.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 1. SECCIÓN: DATOS GENERALES DEL MEDICAMENTO
                  _buildSectionHeader(
                    icon: Icons.medication_rounded,
                    title: '1. Ficha Técnica del Medicamento',
                    subtitle: 'Datos maestros catalogados para la clínica',
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
                        // Código de Artículo Interno
                        TextFormField(
                          controller: _codArtController,
                          decoration: const InputDecoration(
                            labelText: 'Código Artículo Interno',
                            hintText: 'Ej: ART-001',
                            prefixIcon: Icon(Icons.tag_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Código GTIN / Barras
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _gtinController,
                                keyboardType: TextInputType.number,
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
                              tooltip: 'Escanear con Cámara (ML Kit)',
                              onPressed: _abrirEscanerCamara,
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                            ),
                            const SizedBox(width: 4),
                            IconButton.filledTonal(
                              tooltip: 'Generar código de prueba',
                              onPressed: _generarGtinDemo,
                              icon: const Icon(Icons.auto_fix_high_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Nombre comercial
                        TextFormField(
                          controller: _nombreController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre Comercial *',
                            hintText: 'Ej: Amoxicilina 500mg, Meropenem 1g',
                            prefixIcon: Icon(Icons.label_outline_rounded),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Ingresa el nombre comercial'
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Principio Activo
                        TextFormField(
                          controller: _principioActivoController,
                          decoration: const InputDecoration(
                            labelText: 'Principio Activo *',
                            hintText: 'Ej: Amoxicilina Trihidrato',
                            prefixIcon: Icon(Icons.science_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Ingresa el principio activo'
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Forma Farmacéutica
                        DropdownButtonFormField<String>(
                          itemHeight: null,
                          isDense: false,
                          value: _presentacion,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Forma Farmacéutica',
                          ),
                          items: _formasDisponibles
                              .map(
                                (f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(
                                    f,
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
                        const SizedBox(height: 14),

                        // Registro Sanitario
                        TextFormField(
                          controller: _registroSanitarioController,
                          decoration: const InputDecoration(
                            labelText: 'Registro Sanitario (DIGEMID)',
                            hintText: 'Ej: RS-EE-04812',
                            prefixIcon: Icon(Icons.verified_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Laboratorio
                        RawAutocomplete<String>(
                          textEditingController: _laboratorioController,
                          focusNode: _laboratorioFocusNode,
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return laboratoriosSugeridos;
                            }
                            final lowercaseText = textEditingValue.text
                                .toLowerCase();
                            return laboratoriosSugeridos.where((String option) {
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
                                TextEditingController textEditingController,
                                FocusNode focusNode,
                                VoidCallback onFieldSubmitted,
                              ) {
                                return TextFormField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  onFieldSubmitted: (String value) =>
                                      onFieldSubmitted(),
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Laboratorio / Fabricante Principal',
                                    hintText:
                                        'Ej: Bayer, Pfizer, Medifarma S.A.',
                                    prefixIcon: Icon(Icons.science_outlined),
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
                                    borderRadius: BorderRadius.circular(12),
                                    clipBehavior: Clip.antiAlias,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxHeight: 200,
                                        maxWidth: 300,
                                      ),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                              final String option = options
                                                  .elementAt(index);
                                              return InkWell(
                                                onTap: () => onSelected(option),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16.0,
                                                        vertical: 12.0,
                                                      ),
                                                  child: Text(
                                                    option,
                                                    style: const TextStyle(
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
                        const SizedBox(height: 14),

                        // Switch Cadena de Frío
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _requiereCadenaFrio
                                ? Colors.cyan.withOpacity(0.08)
                                : AppColors.surfaceVariant.withOpacity(0.4),
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
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Requiere Cadena de Frío',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Rango estricto de 2.0 °C a 8.0 °C',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _requiereCadenaFrio,
                                activeColor: Colors.cyan.shade700,
                                onChanged: (v) =>
                                    setState(() => _requiereCadenaFrio = v),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // HU-014: Foto opcional de la caja.
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withOpacity(0.3),
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
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.photo_camera_outlined,
                                    color: Colors.grey,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Foto de caja / empaque (opcional)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _fotoCajaPath != null
                                          ? 'Foto adjuntada para validación y trazabilidad'
                                          : 'Captura con cámara para auditoría visual',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<ImageSource>(
                                tooltip: 'Tomar foto con cámara',
                                icon: Icon(
                                  _fotoCajaPath != null
                                      ? Icons.edit_rounded
                                      : Icons.add_a_photo_rounded,
                                  color: AppColors.almacenColor,
                                ),
                                onSelected: _capturarFotoCaja,
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: ImageSource.camera,
                                    child: Wrap(
                                      alignment: WrapAlignment.start,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        Icon(
                                          Icons.camera_alt_rounded,
                                          size: 20,
                                        ),
                                        Text('Tomar con Cámara'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: ImageSource.gallery,
                                    child: Wrap(
                                      alignment: WrapAlignment.start,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        Icon(
                                          Icons.photo_library_rounded,
                                          size: 20,
                                        ),
                                        Text('Elegir de Galería'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. SECCIÓN: PRECIOS DE COMERCIALIZACIÓN
                  _buildSectionHeader(
                    icon: Icons.monetization_on_rounded,
                    title: '2. Precios de Comercialización',
                    subtitle: 'Precios de venta al público y referenciales',
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceVariant),
                    ),
                    child: AccionesAdaptables(
                      anchoMinimo: 150,
                      acciones: [
                        TextFormField(
                          controller: _precioVentaController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Precio Venta *',
                            hintText: 'Ej: 20.00',
                            prefixIcon: Icon(Icons.sell_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Requerido'
                              : null,
                        ),
                        TextFormField(
                          controller: _precioKairosController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Precio Ref. (Kairos)',
                            hintText: 'Ej: 25.50',
                            prefixIcon: Icon(Icons.monetization_on_outlined),
                          ),
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
                        // Número de Lote y Proveedor
                        AccionesAdaptables(
                          anchoMinimo: 150,
                          acciones: [
                            TextFormField(
                              controller: _loteController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Número de Lote *',
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
                                labelText: 'Proveedor',
                                hintText: 'Ej: Medifarma',
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

                        // Precio de Compra
                        TextFormField(
                          controller: _precioCompraController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Precio Compra *',
                            hintText: 'Ej: 15.00',
                            prefixIcon: Icon(Icons.shopping_cart_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Requerido'
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Fecha de vencimiento con máscara
                        TextFormField(
                          controller: _fechaVencimientoController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [_dateMaskFormatter],
                          decoration: const InputDecoration(
                            labelText: 'Fecha de Caducidad (FEFO) *',
                            hintText: 'DD/MM/AAAA',
                            prefixIcon: Icon(Icons.calendar_month_rounded),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Requerido';
                            }
                            if (v.length < 10) return 'Formato incompleto';
                            return null;
                          },
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
                                  labelText: 'Cantidad Recibida *',
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

                  // Botón Guardar
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: 52),
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
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          isSaving
                              ? 'REGISTRANDO EN SUPABASE...'
                              : 'REGISTRAR MEDICAMENTO Y STOCK',
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
            color: AppColors.almacenColor.withOpacity(0.12),
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
