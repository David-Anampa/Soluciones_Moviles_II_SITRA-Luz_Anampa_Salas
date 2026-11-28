import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'diseno_adaptable.dart';
import 'menu_modulos.dart';
import '../theme/tema_pedidos.dart';

/// Búsqueda/identidad textual de etiquetas: ignora tildes y separadores.
String normalizarEtiquetaCatalogo(String valor) {
  const acentos = 'áéíóúüñ';
  const simples = 'aeiouun';
  var texto = valor.toLowerCase();
  for (var i = 0; i < acentos.length; i++) {
    texto = texto.replaceAll(acentos[i], simples[i]);
  }
  return texto.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Campo controlado: cuatro opciones o menos abren menú, más de cuatro un buscador.
class SelectorCatalogo extends StatelessWidget {
  final String? value;
  final List<DropdownMenuItem<String>>? items;
  final ValueChanged<String?>? onChanged;
  final InputDecoration decoration;
  final FormFieldValidator<String>? validator;
  const SelectorCatalogo({
    super.key,
    this.value,
    this.items,
    this.onChanged,
    required this.decoration,
    this.validator,
  });

  String _texto(DropdownMenuItem<String> item) => item.child is Text
      ? (item.child as Text).data ?? item.value ?? ''
      : item.value ?? '';

  @override
  Widget build(BuildContext context) => Theme(
    data: TemaPedidos.aplicar(context, TemaPedidos.rolActual(context)),
    child: Builder(builder: _formulario),
  );

  Widget _formulario(BuildContext context) {
    if (validator == null) return _construir(context, onChanged, null);
    return FormField<String>(
      key: ValueKey(value),
      initialValue: (items ?? []).any((o) => o.value == value) ? value : null,
      enabled: onChanged != null,
      validator: validator,
      builder: (campo) => _construir(
        context,
        onChanged == null
            ? null
            : (v) {
                campo.didChange(v);
                onChanged?.call(v);
              },
        campo.errorText,
      ),
    );
  }

  Widget _construir(
    BuildContext context,
    ValueChanged<String?>? cambiar,
    String? error,
  ) {
    final opciones = items ?? const [];
    final seleccion = opciones.where((o) => o.value == value).firstOrNull;
    final activo = cambiar != null && opciones.isNotEmpty;
    final color = Theme.of(context).colorScheme.primary;
    final campo = InputDecorator(
      decoration: decoration.copyWith(
        enabled: activo,
        filled: true,
        fillColor: activo && seleccion != null
            ? color.withValues(alpha: .07)
            : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        errorText: error ?? decoration.errorText,
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              seleccion == null ? 'Selecciona una opción' : _texto(seleccion),
              softWrap: true,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: activo
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).disabledColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            opciones.length > 4
                ? Icons.manage_search_rounded
                : Icons.expand_more_rounded,
            color: activo ? color : Theme.of(context).disabledColor,
          ),
        ],
      ),
    );
    if (opciones.length <= 4) {
      return LayoutBuilder(
        builder: (context, limits) => PopupMenuButton<int>(
          enabled: activo,
          tooltip: decoration.labelText ?? 'Seleccionar',
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          constraints: BoxConstraints(
            minWidth: math.min(
              limits.maxWidth,
              MediaQuery.sizeOf(context).width - 32,
            ),
            maxWidth: math.min(
              math.max(limits.maxWidth, 240),
              MediaQuery.sizeOf(context).width - 32,
            ),
          ),
          onSelected: (index) => cambiar?.call(opciones[index].value),
          itemBuilder: (_) => [
            for (var i = 0; i < opciones.length; i++)
              PopupMenuItem<int>(
                value: i,
                enabled: opciones[i].enabled,
                padding: EdgeInsets.zero,
                child: Container(
                  decoration: BoxDecoration(
                    color: opciones[i].value == value
                        ? color.withValues(alpha: .08)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _texto(opciones[i]),
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 14,
                            color: opciones[i].value == value ? color : null,
                            fontWeight: opciones[i].value == value
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (opciones[i].value == value) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.check_circle_rounded,
                          color: color,
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
          child: campo,
        ),
      );
    }
    return Semantics(
      button: true,
      enabled: activo,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: !activo
            ? null
            : () async {
                final elegido = await showDialog<_EleccionCatalogo>(
                  context: context,
                  builder: (_) => Theme(
                    data: Theme.of(context),
                    child: _BuscadorCatalogo(
                      titulo: decoration.labelText ?? 'Seleccionar',
                      opciones: opciones,
                      seleccionado: value,
                      etiqueta: _texto,
                    ),
                  ),
                );
                if (elegido != null && context.mounted) {
                  cambiar(elegido.valor);
                }
              },
        child: campo,
      ),
    );
  }
}

class _EleccionCatalogo {
  final String? valor;
  const _EleccionCatalogo(this.valor);
}

class _BuscadorCatalogo extends StatefulWidget {
  final String titulo;
  final List<DropdownMenuItem<String>> opciones;
  final String? seleccionado;
  final String Function(DropdownMenuItem<String>) etiqueta;
  const _BuscadorCatalogo({
    required this.titulo,
    required this.opciones,
    required this.seleccionado,
    required this.etiqueta,
  });
  @override
  State<_BuscadorCatalogo> createState() => _BuscadorCatalogoState();
}

class _BuscadorCatalogoState extends State<_BuscadorCatalogo> {
  final _buscar = TextEditingController();
  int _limite = 30;
  @override
  Widget build(BuildContext context) {
    final q = normalizarEtiquetaCatalogo(_buscar.text);
    final lista = widget.opciones
        .where(
          (o) => normalizarEtiquetaCatalogo(widget.etiqueta(o)).contains(q),
        )
        .toList();
    final color = Theme.of(context).colorScheme.primary;
    return DialogoAdaptable(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CabeceraMenu(
              titulo: widget.titulo,
              icono: Icons.manage_search_rounded,
              color: color,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _buscar,
              autofocus: true,
              onChanged: (_) => setState(() => _limite = 30),
              decoration: const InputDecoration(
                labelText: 'Buscar opción',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            if (lista.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay coincidencias.'),
              ),
            for (final o in lista.take(_limite))
              ListTile(
                selected: o.value == widget.seleccionado,
                selectedTileColor: color.withValues(alpha: .08),
                selectedColor: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabled: o.enabled,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                title: Text(
                  widget.etiqueta(o),
                  softWrap: true,
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: o.value == widget.seleccionado
                    ? Icon(Icons.check_circle_rounded, color: color)
                    : null,
                onTap: () => Navigator.pop(context, _EleccionCatalogo(o.value)),
              ),
            if (lista.length > _limite)
              TextButton(
                onPressed: () => setState(() => _limite += 30),
                child: const Text('Ver más opciones'),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }
}
