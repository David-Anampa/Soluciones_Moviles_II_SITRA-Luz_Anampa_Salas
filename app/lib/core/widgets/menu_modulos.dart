import 'package:flutter/material.dart';

/// Filas equilibradas, también cuando hay un número impar de tarjetas.
class CuadriculaPanel extends StatelessWidget {
  final List<Widget> children;
  final bool esResumen;
  const CuadriculaPanel({
    super.key,
    required this.children,
    this.esResumen = false,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limits) {
      final gap = limits.maxWidth < 360 ? 10.0 : 16.0;
      final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columnas =
          esResumen &&
              (limits.maxWidth < 280 || (escala > 1.5 && limits.maxWidth < 480))
          ? 1
          : 2;
      return Column(
        children: [
          for (var i = 0; i < children.length; i += columnas) ...[
            if (i > 0) SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: children[i]),
                  if (columnas == 2) ...[
                    SizedBox(width: gap),
                    Expanded(
                      child: i + 1 < children.length
                          ? children[i + 1]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// Acceso uniforme para los menús de todos los roles, sin alterar su navegación.
class BotonModulo extends StatelessWidget {
  final String nombre;
  final IconData icono;
  final VoidCallback? onTap;
  const BotonModulo({
    super.key,
    required this.nombre,
    required this.icono,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activo = onTap != null;
    final acento = activo ? const Color(0xFFC62828) : const Color(0xFF777780);
    return Semantics(
      button: true,
      enabled: activo,
      child: Material(
        color: activo ? const Color(0xFFFFF1F1) : const Color(0xFFF2F2F5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Colors.white, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 154),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icono, size: 40, color: acento),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    nombre,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: activo ? const Color(0xFF262630) : acento,
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
