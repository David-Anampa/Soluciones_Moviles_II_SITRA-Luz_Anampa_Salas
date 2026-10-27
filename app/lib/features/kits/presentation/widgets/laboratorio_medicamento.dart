import 'package:flutter/material.dart';

/// Mantiene visible el laboratorio y distingue datos faltantes de un nombre real.
/// La referencia del catálogo solo se usa si el componente no trae laboratorio.
class LaboratorioMedicamento extends StatelessWidget {
  final String? laboratorio, referencia;
  const LaboratorioMedicamento({super.key, this.laboratorio, this.referencia});

  @override
  Widget build(BuildContext context) {
    final original = laboratorio?.trim() ?? '';
    final nombre = original.isNotEmpty ? original : referencia?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'Laboratorio: ${nombre.isEmpty ? 'No registrado' : nombre}',
        style: const TextStyle(
          fontSize: 12,
          height: 1.4,
          color: Color(0xFF616161),
        ),
      ),
    );
  }
}
