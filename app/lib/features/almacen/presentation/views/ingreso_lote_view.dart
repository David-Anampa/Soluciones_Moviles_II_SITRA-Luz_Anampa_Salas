import 'package:flutter/material.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/medicamento_entity.dart';
import '../viewmodels/almacen_viewmodel.dart';
import '../states/almacen_state.dart';

/// Vista completa para registrar un nuevo ingreso de lote de stock.
class IngresoLoteView extends StatefulWidget {
  final List<MedicamentoEntity> catalogo;
  final MedicamentoEntity? medicamentoPreseleccionado;

  const IngresoLoteView({
    super.key,
    required this.catalogo,
    this.medicamentoPreseleccionado,
  });

  @override
  State<IngresoLoteView> createState() => _IngresoLoteViewState();
}

class _IngresoLoteViewState extends State<IngresoLoteView> {
  final _formKey = GlobalKey<FormState>();

  // Buscador
  final _busquedaController = TextEditingController();
  MedicamentoEntity? _selectedMedicamento;
  List<MedicamentoEntity> _resultados = [];
  bool _showSugerencias = false;

  final _loteController = TextEditingController();
  final _laboratorioController = TextEditingController();
  final _laboratorioFocusNode = FocusNode();
  final _proveedorController = TextEditingController();
  final _numBoletaController = TextEditingController();
  final _precioCompraController = TextEditingController();
  final _cantidadController = TextEditingController(text: '50');
  String _justificacion = 'Compra';

  // Fecha con máscara
  late final TextEditingController _fechaController;
  final _dateMask = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void initState() {
    super.initState();
    final venc = DateTime.now().add(const Duration(days: 365));
    _fechaController = TextEditingController(
      text:
          '${venc.day.toString().padLeft(2, '0')}/${venc.month.toString().padLeft(2, '0')}/${venc.year}',
    );
    _resultados = widget.catalogo;
    if (widget.medicamentoPreseleccionado != null) {
      _selectedMedicamento = widget.medicamentoPreseleccionado;
      _busquedaController.text =
          widget.medicamentoPreseleccionado!.nombreComercial;
      if (widget.medicamentoPreseleccionado!.laboratorio != null) {
        _laboratorioController.text =
            widget.medicamentoPreseleccionado!.laboratorio!;
      }
    }
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    _fechaController.dispose();
    _loteController.dispose();
    _laboratorioController.dispose();
    _laboratorioFocusNode.dispose();
    _proveedorController.dispose();
    _numBoletaController.dispose();
    _precioCompraController.dispose();
    _cantidadController.dispose();
    super.dispose();
  }

  void _onBusqueda(String query) {
    setState(() {
      _showSugerencias = true;
      _selectedMedicamento = null;
      if (query.trim().isEmpty) {
        _resultados = widget.catalogo;
      } else {
        final q = query.toLowerCase();
        _resultados = widget.catalogo.where((m) {
          return m.nombreComercial.toLowerCase().contains(q) ||
              m.principioActivo.toLowerCase().contains(q) ||
              (m.codArt?.toLowerCase().contains(q) ?? false) ||
              m.gtin.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  void _elegir(MedicamentoEntity med) {
    setState(() {
      _selectedMedicamento = med;
      _busquedaController.text = med.nombreComercial;
      if (med.laboratorio != null) {
        _laboratorioController.text = med.laboratorio!;
      }
      _showSugerencias = false;
    });
  }

  Future<void> _guardar() async {
    if (_selectedMedicamento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Selecciona un medicamento'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    // Parsear fecha
    DateTime fechaVenc;
    final partes = _fechaController.text.split('/');
    try {
      fechaVenc = DateTime(
        int.parse(partes[2]),
        int.parse(partes[1]),
        int.parse(partes[0]),
      );
      final hoy = DateTime.now();
      if (fechaVenc.day != int.parse(partes[0]) ||
          fechaVenc.month != int.parse(partes[1]) ||
          fechaVenc.year != int.parse(partes[2]) ||
          !fechaVenc.isAfter(DateTime(hoy.year, hoy.month, hoy.day))) {
        throw const FormatException('Fecha inválida o vencida');
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Fecha inválida. Usa DD/MM/AAAA'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final precioTexto = _precioCompraController.text.trim().replaceAll(
      ',',
      '.',
    );
    final precio = precioTexto.isEmpty ? null : double.tryParse(precioTexto);
    if (precioTexto.isNotEmpty &&
        (precio == null ||
            !precio.isFinite ||
            precio < 0 ||
            precio > 99999999.99)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa el precio de compra.')),
      );
      return;
    }
    final vm = context.read<AlmacenViewModel>();
    if (vm.isSaving) return;
    final exito = await vm.registrarLoteParaMedicamentoExistente(
      medicamentoId: _selectedMedicamento!.id,
      numeroLote: _loteController.text.trim(),
      fechaVencimiento: fechaVenc,
      laboratorio: _laboratorioController.text.trim().isNotEmpty
          ? _laboratorioController.text.trim()
          : null,
      proveedor: _proveedorController.text.trim().isNotEmpty
          ? _proveedorController.text.trim()
          : null,
      numBoleta: _numBoletaController.text.trim().isNotEmpty
          ? _numBoletaController.text.trim()
          : null,
      precioCompra: precio,
      justificacion: _justificacion,
      cantidadInicial: int.tryParse(_cantidadController.text.trim()) ?? 0,
    );
    if (!mounted) return;

    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Lote ingresado correctamente'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Error: ${vm.errorMessage ?? "No se pudo registrar"}',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _header({
    required IconData icon,
    required String titulo,
    required String subtitulo,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.almacenColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.almacenColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitulo,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: child,
    );
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nuevo Ingreso de Lote',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Recepción de stock — Almacén General',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppColors.almacenColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.almacenColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSaving ? null : _guardar,
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.add_box_rounded, size: 20),
                  label: Text(
                    isSaving ? 'Registrando...' : 'Ingresar Stock',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ContenidoAdaptable(
        anchoMaximo: 1100,
        padding: EdgeInsets.zero,
        child: SafeArea(
          child: GestureDetector(
            onTap: () => setState(() => _showSugerencias = false),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ═══ SECCIÓN 1: MEDICAMENTO ══════════════════════
                    _header(
                      icon: Icons.medication_rounded,
                      titulo: '1. Medicamento',
                      subtitulo:
                          'Busca por nombre, principio activo o código interno',
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _busquedaController,
                            onChanged: _onBusqueda,
                            onTap: () =>
                                setState(() => _showSugerencias = true),
                            decoration: InputDecoration(
                              labelText: 'Buscar medicamento *',
                              hintText: 'Ej: Amoxicilina, Paracetamol...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _selectedMedicamento != null
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.success,
                                    )
                                  : null,
                            ),
                            validator: (_) => _selectedMedicamento == null
                                ? 'Selecciona un medicamento de la lista'
                                : null,
                          ),

                          // Sugerencias
                          if (_showSugerencias && _resultados.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 210),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.almacenColor.withOpacity(
                                    0.35,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                itemCount: _resultados.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                                itemBuilder: (_, i) {
                                  final m = _resultados[i];
                                  return InkWell(
                                    onTap: () => _elegir(m),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppColors.almacenColor
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.medication_rounded,
                                              size: 16,
                                              color: AppColors.almacenColor,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  m.nombreComercial,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                Text(
                                                  '${m.principioActivo} · ${m.presentacion}${m.laboratorio != null && m.laboratorio!.isNotEmpty ? ' · ${m.laboratorio}' : ''}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (m.codArt != null)
                                            Text(
                                              m.codArt!,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          // Chip de seleccionado
                          if (_selectedMedicamento != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.success.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.success,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedMedicamento!.nombreComercial,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          '${_selectedMedicamento!.principioActivo} · ${_selectedMedicamento!.presentacion}${_selectedMedicamento!.laboratorio != null && _selectedMedicamento!.laboratorio!.isNotEmpty ? ' · ${_selectedMedicamento!.laboratorio}' : ''}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ═══ SECCIÓN 2: DATOS DEL LOTE ══════════════════
                    _header(
                      icon: Icons.inventory_2_rounded,
                      titulo: '2. Datos del Lote',
                      subtitulo:
                          'Número de lote, cantidad y fecha de caducidad (FEFO)',
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _loteController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Número de Lote *',
                              hintText: 'Ej: L2026-X09',
                              prefixIcon: Icon(Icons.numbers_rounded),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _fechaController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [_dateMask],
                            decoration: const InputDecoration(
                              labelText: 'Fecha de Caducidad (FEFO) *',
                              hintText: 'DD/MM/AAAA',
                              prefixIcon: Icon(Icons.calendar_month_rounded),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Requerido';
                              }
                              if (v.length < 10) {
                                return 'Formato incompleto (DD/MM/AAAA)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _cantidadController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cantidad Recibida *',
                              prefixIcon: Icon(Icons.inventory_2_rounded),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Requerido';
                              }
                              final n = int.tryParse(v);
                              if (n == null || n <= 0) {
                                return 'Debe ser mayor a 0';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ═══ SECCIÓN 3: ORIGEN DEL LOTE ═════════════════
                    _header(
                      icon: Icons.science_outlined,
                      titulo: '3. Origen del Lote',
                      subtitulo:
                          'Laboratorio fabricante y distribuidora/proveedor',
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        children: [
                          RawAutocomplete<String>(
                            textEditingController: _laboratorioController,
                            focusNode: _laboratorioFocusNode,
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return laboratoriosSugeridos;
                                  }
                                  final lowercaseText = textEditingValue.text
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
                                      labelText: 'Laboratorio (Fabricante)',
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
                                              (
                                                BuildContext context,
                                                int index,
                                              ) {
                                                final String option = options
                                                    .elementAt(index);
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
                          TextFormField(
                            controller: _proveedorController,
                            decoration: const InputDecoration(
                              labelText: 'Proveedor (Distribuidora)',
                              hintText: 'Ej: Distribuidora Médica SAC',
                              prefixIcon: Icon(Icons.local_shipping_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ═══ SECCIÓN 4: DATOS DE COMPRA ══════════════════
                    _header(
                      icon: Icons.receipt_long_rounded,
                      titulo: '4. Datos de Compra',
                      subtitulo:
                          'Precio de adquisición y documentos sustentatarios',
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _precioCompraController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Precio de Compra (S/.)',
                              hintText: 'Ej: 15.00',
                              prefixIcon: Icon(Icons.shopping_cart_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _numBoletaController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'Nº Boleta / Factura',
                                  hintText: 'Ej: F001-0234',
                                  prefixIcon: Icon(Icons.receipt_long_rounded),
                                ),
                              ),
                              const SizedBox(height: 18),
                              DropdownButtonFormField<String>(
                                itemHeight: null,
                                isDense: false,
                                value: _justificacion,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Justificación',
                                  prefixIcon: Icon(Icons.fact_check_outlined),
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
