import '../../../../core/theme/tema_pedidos.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/stock_ubicaciones_repository.dart';
import '../../domain/entities/stock_ubicacion_entity.dart';
import '../viewmodels/almacen_viewmodel.dart';
import '../widgets/stock_presentacion.dart';

/// Dos iniciativas con el mismo conteo de recepción: Farmacia solicita y
/// Almacén también puede enviar una parte o todo lo elegido, con motivo obligatorio.
class CrearSolicitudAbastecimientoView extends StatefulWidget {
  final bool iniciadoPorAlmacen;
  final StockUbicacionEntity? productoInicial;
  final StockUbicacionesRepository repositorio;
  const CrearSolicitudAbastecimientoView({
    super.key,
    this.iniciadoPorAlmacen = false,
    this.productoInicial,
    this.repositorio = const StockUbicacionesRepository(),
  });
  @override
  State<CrearSolicitudAbastecimientoView> createState() =>
      _CrearSolicitudAbastecimientoViewState();
}

class _CrearSolicitudAbastecimientoViewState
    extends State<CrearSolicitudAbastecimientoView> {
  final _form = GlobalKey<FormState>();
  final _buscar = TextEditingController(), _notas = TextEditingController();
  final _laboratorio = TextEditingController();
  int _pagina = 0;
  Color get _color => TemaPedidos.colorRol(_envio ? 'ALMACEN' : 'FARMACIA');
  void _filtrarLaboratorio() {
    if (mounted) setState(() => _pagina = 0);
  }

  final _cantidades = <String, TextEditingController>{};
  List<StockUbicacionEntity> _productos = [];
  bool _cargando = true;
  String? _error;
  String _turno = 'DIA',
      _justificacion = 'RELLENAR_STOCK',
      _modalidad = 'ENTREGA';
  bool get _envio => widget.iniciadoPorAlmacen;
  bool get _guardando => context.read<AlmacenViewModel>().isSaving;
  @override
  void initState() {
    super.initState();
    _laboratorio.addListener(_filtrarLaboratorio);
    _cargar();
  }

  @override
  void dispose() {
    _laboratorio.dispose();
    _buscar.dispose();
    _notas.dispose();
    for (final c in _cantidades.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await widget.repositorio.cargar(incluirLaboratorio: true);
      if (!mounted) return;
      setState(() {
        _productos = datos;
        _pagina = 0;
        final inicial = widget.productoInicial;
        if (inicial != null &&
            _cantidades.isEmpty &&
            datos.any((p) => p.id == inicial.id && p.activo)) {
          _cantidades[inicial.id] = TextEditingController(text: '1');
        }
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo cargar el stock real. Revisa la conexión y vuelve a intentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _agregar(StockUbicacionEntity p) {
    setState(
      () =>
          _cantidades.putIfAbsent(p.id, () => TextEditingController(text: '1')),
    );
    FocusScope.of(context).unfocus();
  }

  void _quitar(String id) {
    final c = _cantidades.remove(id);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      c?.dispose();
    });
  }

  Future<void> _guardar() async {
    if (_guardando || _cargando) return;
    if (_envio && _notas.text.trim().isEmpty) {
      setState(() => _error = 'Indica el motivo del envío.');
      _form.currentState!.validate();
      return;
    }
    if (_cantidades.isEmpty) {
      setState(() => _error = 'Selecciona al menos un producto.');
      return;
    }
    final items = <String, int>{};
    for (final e in _cantidades.entries) {
      final cantidad = int.tryParse(e.value.text) ?? 0;
      final opciones = _productos.where((p) => p.id == e.key && p.activo);
      if (opciones.isEmpty ||
          cantidad <= 0 ||
          cantidad > 2147483647 ||
          (_envio && cantidad > opciones.first.almacen)) {
        setState(
          () => _error =
              'Revisa las cantidades y el stock disponible en Almacén.',
        );
        _form.currentState!.validate();
        return;
      }
      items[e.key] = cantidad;
    }
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    final vm = context.read<AlmacenViewModel>();
    final exito = await vm.crearPedidoAbastecimiento(
      areaDestino: 'ALMACEN',
      turno: _turno,
      justificacion: _justificacion,
      notas: _notas.text.trim(),
      items: items,
      iniciadoPorAlmacen: _envio,
      modalidadEntrega: _modalidad,
    );
    if (!mounted) return;
    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _envio
                ? 'Envío registrado en tránsito. Farmacia debe contar y confirmar.'
                : 'Solicitud enviada. Almacén confirmará las cantidades que despache.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(
        () => _error = vm.errorMessage ?? 'No se pudo registrar la operación.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final guardando = context.watch<AlmacenViewModel>().isSaving;
    final q = _buscar.text.trim().toLowerCase();
    final laboratorio = _laboratorio.text.trim().toLowerCase();
    final laboratorios =
        _productos
            .where((p) => p.activo && p.laboratorio.isNotEmpty)
            .map((p) => p.laboratorio)
            .toSet()
            .toList()
          ..sort();
    final coincidencias = _productos
        .where(
          (p) =>
              p.activo &&
              ('${p.nombre} ${p.principioActivo} ${p.gtin}'
                  .toLowerCase()
                  .contains(q)) &&
              p.laboratorio.toLowerCase().contains(laboratorio) &&
              !_cantidades.containsKey(p.id),
        )
        .toList();
    final pagina = _pagina.clamp(
      0,
      coincidencias.isEmpty ? 0 : (coincidencias.length - 1) ~/ 3,
    );
    final resultados = coincidencias.skip(pagina * 3).take(3).toList();
    final elegidos = _productos
        .where((p) => _cantidades.containsKey(p.id))
        .toList();
    return Theme(
      data: TemaPedidos.aplicar(
        context,
        _envio ? 'ALMACEN' : 'FARMACIA',
        base: temaStock(context),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        appBar: AppBar(
          toolbarHeight: DisenoAdaptable.altoCabecera(
            context,
            base: kToolbarHeight,
          ),
          title: Text(
            _envio ? 'Enviar a Farmacia' : 'Solicitar a Almacén',
            style: const TextStyle(fontSize: 18),
          ),
        ),
        body: ContenidoAdaptable(
          anchoMaximo: 1100,
          padding: EdgeInsets.zero,
          child: SafeArea(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : Form(
                    key: _form,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        StockSeccion(
                          color: _color,
                          titulo: _envio
                              ? 'Envío desde Almacén'
                              : 'Reposición de Farmacia',
                          icono: _envio
                              ? Icons.local_shipping_outlined
                              : Icons.add_shopping_cart_rounded,
                          children: [
                            Text(
                              _envio
                                  ? 'Elige cuánto enviar. El resto queda en Almacén y Farmacia contará lo recibido antes de disponer de ello.'
                                  : 'Consulta lo que hay en ambas ubicaciones y solicita únicamente lo que necesitas.',
                              style: const TextStyle(height: 1.5),
                            ),
                            _selector(
                              'Turno',
                              _turno,
                              {
                                'DIA': 'Día',
                                'TARDE': 'Tarde',
                                'NOCHE': 'Noche',
                              },
                              Icons.schedule_rounded,
                              (v) => setState(() => _turno = v),
                              guardando,
                            ),
                            _selector(
                              'Justificación',
                              _justificacion,
                              {
                                'STOCK_CERO': 'Sin stock en Farmacia',
                                'RELLENAR_STOCK': 'Reposición de stock',
                              },
                              Icons.assignment_outlined,
                              (v) => setState(() => _justificacion = v),
                              guardando,
                            ),
                            if (_envio)
                              _selector(
                                'Modalidad',
                                _modalidad,
                                {
                                  'ENTREGA': 'Almacén entrega',
                                  'RECOJO': 'Farmacia recoge',
                                },
                                Icons.route_outlined,
                                (v) => setState(() => _modalidad = v),
                                guardando,
                              ),
                            TextFormField(
                              controller: _notas,
                              enabled: !guardando,
                              maxLines: 3,
                              maxLength: 1000,
                              validator: (v) =>
                                  _envio && (v ?? '').trim().isEmpty
                                  ? 'Indica el motivo del envío.'
                                  : null,
                              decoration: InputDecoration(
                                labelText: _envio
                                    ? 'Motivo del envío'
                                    : 'Observaciones (opcional)',
                                prefixIcon: const Icon(
                                  Icons.edit_note_rounded,
                                  color: stockRojo,
                                ),
                              ),
                            ),
                          ],
                        ),
                        StockSeccion(
                          color: _color,
                          titulo:
                              'Productos seleccionados (${elegidos.length})',
                          icono: Icons.checklist_rounded,
                          compacta: true,
                          children: [
                            if (elegidos.isEmpty)
                              const Text('Agrega productos desde el buscador.'),
                            for (var i = 0; i < elegidos.length; i++) ...[
                              _productoSeleccionado(elegidos[i], guardando),
                              if (i < elegidos.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                        StockSeccion(
                          color: _color,
                          titulo: 'Buscar productos',
                          icono: Icons.search_rounded,
                          compacta: true,
                          children: [
                            TextField(
                              controller: _buscar,
                              enabled: !guardando,
                              onChanged: (_) => setState(() => _pagina = 0),
                              decoration: InputDecoration(
                                labelText: 'Nombre, principio activo o código',
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: _color,
                                ),
                                suffixIcon: _buscar.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Limpiar búsqueda',
                                        onPressed: guardando
                                            ? null
                                            : () => setState(() {
                                                _buscar.clear();
                                                _pagina = 0;
                                              }),
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                              ),
                            ),
                            LayoutBuilder(
                              builder: (context, limits) =>
                                  DropdownMenu<String>(
                                    width: limits.maxWidth,
                                    controller: _laboratorio,
                                    enabled: !guardando,
                                    enableFilter: true,
                                    enableSearch: true,
                                    requestFocusOnTap: true,
                                    menuHeight: 260,
                                    label: const Text('Laboratorio'),
                                    leadingIcon: Icon(
                                      Icons.science_outlined,
                                      color: _color,
                                    ),
                                    inputDecorationTheme: InputDecorationTheme(
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 18,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    menuStyle: MenuStyle(
                                      backgroundColor:
                                          const WidgetStatePropertyAll(
                                            Colors.white,
                                          ),
                                      shape: WidgetStatePropertyAll(
                                        RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    dropdownMenuEntries: [
                                      const DropdownMenuEntry(
                                        value: '',
                                        label: 'Todos los laboratorios',
                                      ),
                                      for (final nombre in laboratorios)
                                        DropdownMenuEntry(
                                          value: nombre,
                                          label: nombre,
                                        ),
                                    ],
                                    onSelected: (value) {
                                      if (value == '') _laboratorio.clear();
                                    },
                                  ),
                            ),
                            if (_laboratorio.text.isNotEmpty)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: guardando
                                      ? null
                                      : _laboratorio.clear,
                                  icon: const Icon(
                                    Icons.filter_alt_off_outlined,
                                  ),
                                  label: const Text('Quitar laboratorio'),
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${coincidencias.length} coincidencias · ${resultados.length} visibles',
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Anteriores',
                                  onPressed: pagina > 0
                                      ? () =>
                                            setState(() => _pagina = pagina - 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_left_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Siguientes',
                                  onPressed:
                                      (pagina + 1) * 3 < coincidencias.length
                                      ? () =>
                                            setState(() => _pagina = pagina + 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_right_rounded),
                                ),
                              ],
                            ),
                            if (resultados.isEmpty)
                              const Text('No hay más coincidencias.'),
                            for (var i = 0; i < resultados.length; i++) ...[
                              _resultadoProducto(resultados[i], guardando),
                              if (i < resultados.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                        if (_error != null)
                          StockSeccion(
                            color: _color,
                            titulo: 'Revisar operación',
                            icono: Icons.error_outline_rounded,
                            children: [
                              Text(
                                _error!,
                                style: const TextStyle(
                                  height: 1.5,
                                  color: stockRojo,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: guardando ? null : _cargar,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Actualizar stock'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: 54),
              child: FilledButton.icon(
                onPressed: guardando || _cargando || _productos.isEmpty
                    ? null
                    : _guardar,
                icon: guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _envio
                            ? Icons.local_shipping_outlined
                            : Icons.send_outlined,
                      ),
                label: Text(
                  guardando
                      ? 'Guardando…'
                      : _envio
                      ? 'Despachar a Farmacia'
                      : 'Enviar solicitud',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Agrupa nombre, tres ubicaciones y cantidad sin márgenes repetidos por campo.
  /// Mantiene los mismos controladores y validaciones de la operación original.
  Widget _productoSeleccionado(StockUbicacionEntity p, bool guardando) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF30343F),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Quitar producto',
                onPressed: guardando ? null : () => _quitar(p.id),
                icon: const Icon(
                  Icons.close_rounded,
                  color: stockRojo,
                  size: 21,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          StockContadores(item: p, compacto: true, color: _color),
          const SizedBox(height: 10),
          _controlCantidad(p, guardando),
        ],
      );

  /// Integra pasos táctiles y escritura numérica. El máximo de Almacén solo se
  /// aplica al envío; las solicitudes conservan su validación de cantidad entera.
  Widget _controlCantidad(StockUbicacionEntity p, bool guardando) {
    final controlador = _cantidades[p.id]!;
    final actual = int.tryParse(controlador.text) ?? 0;
    final maximo = _envio ? p.almacen : 2147483647;
    void ajustar(int paso) => setState(() {
      controlador.text = (actual + paso).clamp(1, maximo).toString();
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _envio ? 'Cantidad a enviar' : 'Cantidad a solicitar',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF50505B),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  border: Border.all(color: const Color(0xFFE6DADA)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      tooltip: 'Reducir cantidad',
                      color: stockRojo,
                      onPressed: guardando || maximo < 1 || actual <= 1
                          ? null
                          : () => ajustar(-1),
                      icon: const Icon(Icons.remove_rounded, size: 21),
                    ),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('cantidad-${p.id}'),
                        controller: controlador,
                        enabled: !guardando,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF30343F),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) {
                          final n = int.tryParse(v ?? '') ?? 0;
                          if (n <= 0 || n > 2147483647) {
                            return 'Escribe una cantidad entera mayor que cero.';
                          }
                          if (_envio && n > p.almacen) {
                            return 'Almacén dispone de ${p.almacen}.';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          hintText: '0',
                          filled: false,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 14,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          errorMaxLines: 3,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Aumentar cantidad',
                      style: IconButton.styleFrom(
                        backgroundColor: stockRojo,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: guardando || maximo < 1 || actual >= maximo
                          ? null
                          : () => ajustar(1),
                      icon: const Icon(Icons.add_rounded, size: 21),
                    ),
                  ],
                ),
              ),
            ),
            if (_envio) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: 'Usar todo el stock de Almacén: ${p.almacen}',
                child: OutlinedButton(
                  onPressed: guardando || p.almacen == 0
                      ? null
                      : () => setState(
                          () => controlador.text = p.almacen.toString(),
                        ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: const Icon(
                    Icons.select_all_rounded,
                    size: 22,
                    semanticLabel: 'Usar todo el stock de Almacén',
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// El acceso Agregar comparte fila con el nombre; conserva el bloqueo por falta
  /// de stock y muestra siempre las tres ubicaciones, también al buscar.
  Widget _resultadoProducto(StockUbicacionEntity p, bool guardando) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              p.nombre,
              style: const TextStyle(
                fontSize: 14,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: Color(0xFF30343F),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Agregar producto',
            child: FilledButton(
              onPressed: guardando || (_envio && p.almacen == 0)
                  ? null
                  : () => _agregar(p),
              style: FilledButton.styleFrom(
                backgroundColor: stockRojo,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.all(12),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 22,
                semanticLabel: 'Agregar producto',
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      if (p.laboratorio.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(p.laboratorio, style: const TextStyle(fontSize: 12)),
        ),
      StockContadores(item: p, compacto: true, color: _color),
    ],
  );

  Widget _selector(
    String etiqueta,
    String valor,
    Map<String, String> opciones,
    IconData icono,
    ValueChanged<String> cambiar,
    bool bloqueado,
  ) => DropdownButtonFormField<String>(
    itemHeight: null,
    isDense: false,
    value: valor,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: etiqueta,
      prefixIcon: Icon(icono, color: _color),
    ),
    items: opciones.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList(),
    onChanged: bloqueado
        ? null
        : (v) {
            if (v != null) cambiar(v);
          },
  );
}
