import 'package:flutter/material.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import 'catalogo_estilo.dart';

/// Selección múltiple con búsqueda: conserva el borrador hasta pulsar Aplicar.
class AreasUsuarioSelector extends StatelessWidget {
  final Map<String, String> opciones;
  final Set<String> seleccionadas, inactivas;
  final bool habilitado;
  final ValueChanged<Set<String>> onChanged;
  const AreasUsuarioSelector({
    super.key,
    required this.opciones,
    required this.seleccionadas,
    required this.inactivas,
    required this.habilitado,
    required this.onChanged,
  });

  Future<void> _abrir(BuildContext context) async {
    final resultado = await showDialog<Set<String>>(
      context: context,
      builder: (_) => Theme(
        data: CatalogoEstilo.tema(context),
        child: _SelectorAreasDialog(
          opciones: opciones,
          seleccionadas: seleccionadas,
          inactivas: inactivas,
        ),
      ),
    );
    if (context.mounted && resultado != null) onChanged(resultado);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Áreas asignadas',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      const Text(
        'Selecciona una o varias áreas de trabajo.',
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: habilitado && opciones.isNotEmpty
            ? () => _abrir(context)
            : null,
        icon: const Icon(Icons.apartment_rounded),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  seleccionadas.isEmpty
                      ? 'Buscar y seleccionar áreas'
                      : '${seleccionadas.length} áreas seleccionadas',
                ),
              ),
              const Icon(Icons.expand_more_rounded),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      if (opciones.isEmpty)
        const Text(
          'No hay áreas habilitadas. Créalas en Gestión administrativa.',
          style: TextStyle(fontSize: 13),
        )
      else if (seleccionadas.isEmpty)
        const Text(
          'Sin áreas seleccionadas',
          style: TextStyle(fontSize: 12, color: Color(0xFF777780)),
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final codigo in seleccionadas)
              InputChip(
                avatar: const Icon(
                  Icons.apartment_rounded,
                  size: 16,
                  color: CatalogoEstilo.rojo,
                ),
                label: Text(opciones[codigo] ?? codigo),
                backgroundColor: CatalogoEstilo.pastel,
                deleteButtonTooltipMessage: 'Quitar área',
                onDeleted: habilitado
                    ? () => onChanged({...seleccionadas}..remove(codigo))
                    : null,
              ),
          ],
        ),
    ],
  );
}

class _SelectorAreasDialog extends StatefulWidget {
  final Map<String, String> opciones;
  final Set<String> seleccionadas, inactivas;
  const _SelectorAreasDialog({
    required this.opciones,
    required this.seleccionadas,
    required this.inactivas,
  });
  @override
  State<_SelectorAreasDialog> createState() => _SelectorAreasDialogState();
}

class _SelectorAreasDialogState extends State<_SelectorAreasDialog> {
  late final _seleccion = {...widget.seleccionadas};
  final _buscador = TextEditingController();
  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  /// Ignora acentos al buscar por código o nombre; no cambia los datos guardados.
  String _normalizar(String valor) {
    var resultado = valor.toLowerCase();
    const acentos = 'áéíóúü', letras = 'aeiouu';
    for (var i = 0; i < acentos.length; i++) {
      resultado = resultado.replaceAll(acentos[i], letras[i]);
    }
    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    final consulta = _normalizar(_buscador.text.trim());
    final filas =
        widget.opciones.entries
            .where((o) => _normalizar('${o.key} ${o.value}').contains(consulta))
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    return AlertaAdaptable(
      title: const Row(
        children: [
          Icon(Icons.apartment_rounded, color: CatalogoEstilo.rojo),
          SizedBox(width: 10),
          Expanded(child: Text('Seleccionar áreas')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _buscador,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Buscar por nombre o código',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _buscador.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () => setState(_buscador.clear),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_seleccion.length} seleccionadas · ${filas.length} resultados',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: (MediaQuery.sizeOf(context).height * .32).clamp(
              80.0,
              280.0,
            ),
            child: filas.isEmpty
                ? const Center(child: Text('No se encontraron áreas.'))
                : ListView.builder(
                    itemCount: filas.length,
                    itemBuilder: (_, index) {
                      final area = filas[index];
                      final marcada = _seleccion.contains(area.key);
                      final disponible =
                          !widget.inactivas.contains(area.key) || marcada;
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: CatalogoEstilo.rojo,
                        title: Text(
                          area.value,
                          style: const TextStyle(fontSize: 14),
                        ),
                        value: marcada,
                        onChanged: disponible
                            ? (valor) => setState(() {
                                valor == true
                                    ? _seleccion.add(area.key)
                                    : _seleccion.remove(area.key);
                              })
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _seleccion),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Aplicar selección'),
        ),
      ],
    );
  }
}
