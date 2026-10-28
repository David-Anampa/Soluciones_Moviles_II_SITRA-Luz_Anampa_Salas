import 'package:flutter/material.dart';

/// Acceso a una operación existente; un callback nulo conserva su bloqueo actual.
class AccionRapidaAlmacen {
  final String titulo, descripcion;
  final IconData icono;
  final VoidCallback? onTap;
  const AccionRapidaAlmacen({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.onTap,
  });
}

/// Dos accesos por fila. La altura mínima es cuadrada; puede crecer con texto
/// ampliado para no recortar títulos ni descripciones en celulares pequeños.
class AccionesRapidasAlmacen extends StatelessWidget {
  final List<AccionRapidaAlmacen> acciones;
  const AccionesRapidasAlmacen({super.key, required this.acciones});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final lado = (limites.maxWidth - 12) / 2;
      return Column(
        children: [
          for (var i = 0; i < acciones.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _tarjeta(acciones[i], lado)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: i + 1 < acciones.length
                        ? _tarjeta(acciones[i + 1], lado)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );

  /// Superficie táctil completa con icono, título, descripción y estados de interacción.
  Widget _tarjeta(AccionRapidaAlmacen accion, double lado) {
    const rojo = Color(0xFFC62828);
    final habilitada = accion.onTap != null;
    final acento = habilitada ? rojo : const Color(0xFF777780);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: lado),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: habilitada
                ? const Color(0xFFF0CCCC)
                : const Color(0xFFE3E3E3),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                habilitada ? const Color(0xFFFFEEEE) : const Color(0xFFF4F4F4),
              ],
            ),
          ),
          child: InkWell(
            onTap: accion.onTap,
            hoverColor: rojo.withValues(alpha: .08),
            focusColor: rojo.withValues(alpha: .08),
            splashColor: rojo.withValues(alpha: .12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: acento,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(accion.icono, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    accion.titulo,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: habilitada ? const Color(0xFF262630) : acento,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    accion.descripcion,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF555560),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
