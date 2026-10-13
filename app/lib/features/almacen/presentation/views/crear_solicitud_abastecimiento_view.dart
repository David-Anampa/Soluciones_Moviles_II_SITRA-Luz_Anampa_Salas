import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/medicamento_entity.dart';
import '../states/almacen_state.dart';
import '../viewmodels/almacen_viewmodel.dart';

/// HU-029: Registrar solicitud de abastecimiento por faltantes de guardia.
/// Vista para que Farmacia genere un nuevo pedido de reposición a Almacén.
class CrearSolicitudAbastecimientoView extends StatefulWidget {
  const CrearSolicitudAbastecimientoView({super.key});

  @override
  State<CrearSolicitudAbastecimientoView> createState() =>
      _CrearSolicitudAbastecimientoViewState();
}

class _CrearSolicitudAbastecimientoViewState
    extends State<CrearSolicitudAbastecimientoView> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _notasController = TextEditingController();

  String _turnoSeleccionado = 'DIA';
  String _justificacionSeleccionada = 'RELLENAR_STOCK';

  // Ítems seleccionados (Medicamento : Cantidad a pedir)
  final Map<MedicamentoEntity, int> _itemsSeleccionados = {};
  final Map<String, TextEditingController> _cantidadControllers = {};

  // Filtro de búsqueda dinámico
  List<MedicamentoEntity> _resultadosBusqueda = [];
  bool _mostrarResultados = false;

  @override
  void initState() {
    super.initState();
    // Pre-cargar datos si es necesario (el catálogo debe estar cargado en AlmacenLoaded)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlmacenViewModel>().cargarInventario();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notasController.dispose();
    for (final controller in _cantidadControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _buscarMedicamento(String query, List<MedicamentoEntity> catalogo) {
    if (query.trim().isEmpty) {
      setState(() {
        _resultadosBusqueda = [];
        _mostrarResultados = false;
      });
      return;
    }

    final queryLower = query.toLowerCase();
    setState(() {
      _resultadosBusqueda = catalogo.where((med) {
        return med.nombreComercial.toLowerCase().contains(queryLower) ||
            med.principioActivo.toLowerCase().contains(queryLower) ||
            med.gtin.toLowerCase().contains(queryLower) ||
            (med.laboratorio?.toLowerCase().contains(queryLower) ?? false);
      }).toList();
      _mostrarResultados = true;
    });
  }

  void _agregarItem(MedicamentoEntity medicamento) {
    setState(() {
      if (!_itemsSeleccionados.containsKey(medicamento)) {
        _itemsSeleccionados[medicamento] = 1;
      } else {
        _itemsSeleccionados[medicamento] =
            _itemsSeleccionados[medicamento]! + 1;
      }
      final cantidad = _itemsSeleccionados[medicamento]!;
      final controller = _cantidadControllers.putIfAbsent(
        medicamento.id,
        () => TextEditingController(text: cantidad.toString()),
      );
      controller.value = TextEditingValue(
        text: cantidad.toString(),
        selection: TextSelection.collapsed(offset: cantidad.toString().length),
      );
      // Limpiar buscador tras agregar
      _searchController.clear();
      _mostrarResultados = false;
      FocusScope.of(context).unfocus();
    });
  }

  void _actualizarCantidad(MedicamentoEntity medicamento, int delta) {
    setState(() {
      final actual = _itemsSeleccionados[medicamento] ?? 0;
      final nueva = actual + delta;
      if (nueva <= 0) {
        _itemsSeleccionados.remove(medicamento);
        final controller = _cantidadControllers.remove(medicamento.id);
        // El campo termina de desmontarse antes de liberar su controlador.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller?.dispose();
        });
      } else {
        _itemsSeleccionados[medicamento] = nueva;
        _cantidadControllers[medicamento.id]!.value = TextEditingValue(
          text: nueva.toString(),
          selection: TextSelection.collapsed(offset: nueva.toString().length),
        );
      }
    });
  }

  Future<void> _enviarSolicitud() async {
    if (_itemsSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe agregar al menos un medicamento a la solicitud.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final vm = context.read<AlmacenViewModel>();

    if (_itemsSeleccionados.values.any((cantidad) => cantidad <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe una cantidad mayor que cero para cada medicamento.'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();

    // Transformar el mapa de entidades a Map<String, int> para el repositorio
    final Map<String, int> itemsParaBackend = {};
    for (var entry in _itemsSeleccionados.entries) {
      itemsParaBackend[entry.key.id] = entry.value;
    }

    final exito = await vm.crearPedidoAbastecimiento(
      areaDestino: 'ALMACEN',
      turno: _turnoSeleccionado,
      justificacion: _justificacionSeleccionada,
      notas: _notasController.text.trim(),
      items: itemsParaBackend,
    );

    if (!mounted) return;

    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud enviada a Almacén exitosamente.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${vm.errorMessage ?? "No se pudo registrar la solicitud"}',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AlmacenViewModel>();
    final state = vm.state;

    // Colores solicitados: Rojo, Blanco, Gris Claro (Premium)
    const Color brandRed = Color(0xFFC62828); // Un rojo elegante y profundo
    const Color brandGrey = Color(0xFFF4F6FB); // Gris claro de fondo
    const Color brandWhite = Colors.white;

    final baseTheme = Theme.of(context);
    final pedidoTheme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: brandRed, secondary: brandRed, surface: brandWhite,
        surfaceTint: Colors.transparent,
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandRed, width: 1.5),
        ),
      ),
    );
    return Theme(data: pedidoTheme, child: Scaffold(
      backgroundColor: brandGrey,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nueva Solicitud',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Abastecimiento Farmacia → Almacén',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: brandRed,
        foregroundColor: brandWhite,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: state is AlmacenLoaded
          ? _buildForm(context, state.catalogo, brandRed, brandWhite)
          : const Center(child: CircularProgressIndicator(color: brandRed)),
      bottomNavigationBar: state is AlmacenLoaded
          ? _buildBottomBar(brandRed, brandWhite, vm.isSaving)
          : null,
    ));
  }

  Widget _buildForm(
    BuildContext context,
    List<MedicamentoEntity> catalogo,
    Color brandRed,
    Color brandWhite,
  ) {
    return GestureDetector(
      onTap: () =>
          FocusScope.of(context).unfocus(), // Ocultar teclado al tocar fuera
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // 1. Contexto Operativo
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: brandWhite,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.assignment_ind_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Contexto del Pedido',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Turno
                const Text(
                  'Turno actual:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'DIA',
                      label: Text('Día', style: TextStyle(fontSize: 13)),
                    ),
                    ButtonSegment(
                      value: 'TARDE',
                      label: Text('Tarde', style: TextStyle(fontSize: 13)),
                    ),
                    ButtonSegment(
                      value: 'NOCHE',
                      label: Text('Noche', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                  selected: {_turnoSeleccionado},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() => _turnoSeleccionado = newSelection.first);
                  },
                  style: SegmentedButton.styleFrom(
                    selectedForegroundColor: brandWhite,
                    selectedBackgroundColor: brandRed.withOpacity(0.9),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),

                const SizedBox(height: 20),

                // Justificación
                const Text(
                  'Justificación:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _CustomRadioCard(
                        title: 'Rellenar Stock',
                        icon: Icons.inventory_2_outlined,
                        value: 'RELLENAR_STOCK',
                        groupValue: _justificacionSeleccionada,
                        onChanged: (val) =>
                            setState(() => _justificacionSeleccionada = val!),
                        activeColor: brandRed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CustomRadioCard(
                        title: 'Stock Cero',
                        icon: Icons.warning_amber_rounded,
                        value: 'STOCK_CERO',
                        groupValue: _justificacionSeleccionada,
                        onChanged: (val) =>
                            setState(() => _justificacionSeleccionada = val!),
                        activeColor: brandRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Buscador Dinámico
          const Text(
            'Catálogo de Medicamentos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => _buscarMedicamento(val, catalogo),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, código o laboratorio...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _buscarMedicamento('', catalogo);
                        },
                      )
                    : null,
                filled: true,
                fillColor: brandWhite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          // Resultados del buscador
          if (_mostrarResultados && _resultadosBusqueda.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: brandWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _resultadosBusqueda.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: Color(0xFFEEF2FA)),
                itemBuilder: (context, index) {
                  final med = _resultadosBusqueda[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: brandRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.medication_outlined,
                        color: brandRed,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      '${med.nombreComercial} ${med.presentacion}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Cod: ${med.gtin} | Lab: ${med.laboratorio ?? "N/A"}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onTap: () => _agregarItem(med),
                    hoverColor: Colors.grey.shade50,
                  );
                },
              ),
            )
          else if (_mostrarResultados && _resultadosBusqueda.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: brandWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Text(
                'No se encontraron medicamentos.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),

          const SizedBox(height: 32),

          // 3. Carrito de Solicitud
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ítems a Solicitar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: brandRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_itemsSeleccionados.length} ítems',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: brandRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_itemsSeleccionados.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: brandWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.shade200,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 40,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No has seleccionado medicamentos',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Usa el buscador superior para agregar ítems.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _itemsSeleccionados.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final med = _itemsSeleccionados.keys.elementAt(index);
                final cantidad = _itemsSeleccionados[med]!;
                return _buildCartItem(med, cantidad, brandWhite, brandRed);
              },
            ),

          const SizedBox(height: 32),

          // 4. Notas
          const Text(
            'Notas (Opcional)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notasController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Ej: Urgente, se acabó ayer en el turno noche.',
              filled: true,
              fillColor: brandWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 40), // Respiro inferior
        ],
      ),
    );
  }

  Widget _buildCartItem(
    MedicamentoEntity med,
    int cantidad,
    Color brandWhite,
    Color brandRed,
  ) {
    final cantidadController = _cantidadControllers.putIfAbsent(
      med.id,
      () => TextEditingController(text: cantidad.toString()),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brandWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${med.nombreComercial} ${med.presentacion}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unidad: ${med.unidadPresentacion}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Stepper
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _actualizarCantidad(med, -1),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Icon(
                      Icons.remove,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: TextField(
                    controller: cantidadController,
                    enabled: !context.read<AlmacenViewModel>().isSaving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                      signed: false,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.done,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                    cursorColor: brandRed,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      hintText: '1',
                    ),
                    onChanged: (texto) {
                      setState(() {
                        _itemsSeleccionados[med] = int.tryParse(texto) ?? 0;
                      });
                    },
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  ),
                ),
                InkWell(
                  onTap: () => _actualizarCantidad(med, 1),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Icon(
                      Icons.add,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Color brandRed, Color brandWhite, bool isSaving) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: brandWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: brandRed,
            foregroundColor: brandWhite,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: isSaving ? null : _enviarSolicitud,
          child: isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'ENVIAR SOLICITUD A ALMACÉN',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}

// Custom Radio Card para Justificación
class _CustomRadioCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;
  final Color activeColor;

  const _CustomRadioCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = value == groupValue;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? activeColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? activeColor : AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
