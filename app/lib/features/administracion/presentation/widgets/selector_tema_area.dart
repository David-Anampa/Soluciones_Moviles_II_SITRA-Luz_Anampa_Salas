import 'package:flutter/material.dart';
import '../../../../core/theme/tema_area.dart';

/// Permite elegir una pareja principal/pastel y revisar su contraste antes de guardar.
class SelectorTemaArea extends StatelessWidget {
  final String valor, nombreArea;
  final ValueChanged<String>? onChanged;
  const SelectorTemaArea({
    super.key,
    required this.valor,
    required this.nombreArea,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tema = TemaArea.desde(valor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tema del área',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Color principal y fondo pastel. Los mensajes conservan sus colores de significado.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64646D), height: 1.4),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TemaArea.opciones
              .map(
                (opcion) => ChoiceChip(
                  label: Text(opcion.nombre),
                  selected: valor == opcion.codigo,
                  selectedColor: opcion.suave,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(color: opcion.principal, fontSize: 13),
                  checkmarkColor: opcion.principal,
                  avatar: CircleAvatar(
                    backgroundColor: opcion.principal,
                    radius: 9,
                  ),
                  side: BorderSide(
                    color: valor == opcion.codigo
                        ? opcion.principal
                        : const Color(0xFFE0E0E0),
                  ),
                  onSelected: onChanged == null
                      ? null
                      : (_) => onChanged!(opcion.codigo),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                color: tema.principal,
                child: Row(
                  children: [
                    const Icon(
                      Icons.apartment_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        nombreArea.trim().isEmpty
                            ? 'Área de trabajo'
                            : nombreArea.trim(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                color: tema.suave,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vista previa del tema',
                      style: TextStyle(
                        color: tema.principal,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Tarjetas y campos claros para facilitar la lectura.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF424242),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: tema.principal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Wrap(
                        alignment: WrapAlignment.start,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          Text(
                            'Botón principal',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
