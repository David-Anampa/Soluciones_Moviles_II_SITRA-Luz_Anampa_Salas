import 'package:flutter/material.dart';

/// Reglas de espacio compartidas; no altera ni bloquea la escala de texto del usuario.
class DisenoAdaptable {
  static double margen(double ancho) => ancho < 360
      ? 12
      : ancho < 600
      ? 16
      : 24;

  /// Altura visible para un diálogo. Dialog también aplica sus insets: no se
  /// agrega padding de teclado otra vez dentro del contenido desplazable.
  static double altoDialogo(BuildContext context) {
    final media = MediaQuery.of(context);
    final alto =
        media.size.height -
        media.viewInsets.vertical -
        media.padding.vertical -
        32;
    return alto > 0 ? alto : 0;
  }
}

/// Contenido de página centrado y con ancho de lectura limitado.
/// El llamador conserva el scroll: admite ListView o un formulario desplazable.
class ContenidoAdaptable extends StatelessWidget {
  final Widget child;
  final double anchoMaximo;
  const ContenidoAdaptable({
    super.key,
    required this.child,
    this.anchoMaximo = 800,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final ancho = limites.hasBoundedWidth
          ? limites.maxWidth
          : MediaQuery.sizeOf(context).width;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: anchoMaximo),
          child: Padding(
            padding: EdgeInsets.all(DisenoAdaptable.margen(ancho)),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Distribuye acciones en columnas iguales. En un teléfono estrecho o con letra
/// ampliada se apilan; las barras de iconos pueden desactivar el cálculo textual.
/// Recibe botones normales, nunca Expanded ni Flexible.
class AccionesAdaptables extends StatelessWidget {
  final List<Widget> acciones;
  final double anchoMinimo, separacion;
  final bool considerarTexto;
  const AccionesAdaptables({
    super.key,
    required this.acciones,
    this.anchoMinimo = 144,
    this.separacion = 12,
    this.considerarTexto = true,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      if (acciones.isEmpty) return const SizedBox.shrink();
      final ancho = limites.hasBoundedWidth
          ? limites.maxWidth
          : MediaQuery.sizeOf(context).width;
      final escala = considerarTexto
          ? MediaQuery.textScalerOf(context).scale(14) / 14
          : 1.0;
      final minimo = anchoMinimo * (escala > 1 ? escala : 1);
      var columnas = ((ancho + separacion) / (minimo + separacion))
          .floor()
          .clamp(1, acciones.length);
      // Mantiene filas equilibradas: cuatro acciones pasan a 2x2 en vez de 3+1.
      while (columnas > 1 && acciones.length % columnas != 0) {
        columnas--;
      }
      final espacio = ancho - (columnas - 1) * separacion;
      final anchoAccion = espacio > 0 ? espacio / columnas : 0.0;
      return Wrap(
        spacing: separacion,
        runSpacing: separacion,
        children: acciones
            .map((accion) => SizedBox(width: anchoAccion, child: accion))
            .toList(),
      );
    },
  );
}

/// Modal con límite visible y scroll de TODO el contenido: título y acciones
/// también son alcanzables con teclado, paisaje o texto grande. No usar Expanded
/// dentro de child; una lista interna debe tener altura acotada.
class DialogoAdaptable extends StatelessWidget {
  final Widget child;
  final double anchoMaximo;
  const DialogoAdaptable({
    super.key,
    required this.child,
    this.anchoMaximo = 620,
  });
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: EdgeInsets.symmetric(
      horizontal: DisenoAdaptable.margen(MediaQuery.sizeOf(context).width),
      vertical: 16,
    ),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: anchoMaximo,
        maxHeight: DisenoAdaptable.altoDialogo(context),
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: child,
      ),
    ),
  );
}
