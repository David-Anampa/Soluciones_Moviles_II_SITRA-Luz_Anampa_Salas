import 'package:flutter/material.dart';

/// Reglas de espacio compartidas; no altera ni bloquea la escala de texto del usuario.
class DisenoAdaptable {
  /// Reserva alto para título/subtítulo ampliados sin bloquear la escala del sistema.
  static double altoCabecera(BuildContext context, {double base = 72}) {
    final escala = MediaQuery.textScalerOf(context);
    final necesario = escala.scale(17) + escala.scale(12) + 24;
    return necesario > base ? necesario : base;
  }

  static double margen(double ancho) => ancho < 360
      ? 12
      : ancho < 600
      ? 16
      : 24;

  /// Altura visible para un diálogo. Dialog también aplica sus insets: no se
  /// agrega padding de teclado otra vez dentro del contenido desplazable.
  static double altoDialogo(
    BuildContext context, {
    double espacioExterior = 32,
  }) {
    final media = MediaQuery.of(context);
    final alto =
        media.size.height -
        media.viewInsets.vertical -
        media.padding.vertical -
        espacioExterior;
    return alto > 0 ? alto : 0;
  }
}

/// Contenido de página centrado y con ancho de lectura limitado.
/// El llamador conserva el scroll: admite ListView o un formulario desplazable.
class ContenidoAdaptable extends StatelessWidget {
  final Widget child;
  final double anchoMaximo;
  final EdgeInsetsGeometry? padding;
  const ContenidoAdaptable({
    super.key,
    required this.child,
    this.anchoMaximo = 800,
    this.padding,
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
            padding: padding ?? EdgeInsets.all(DisenoAdaptable.margen(ancho)),
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
  final Color backgroundColor, surfaceTintColor;
  final ShapeBorder? shape;
  final EdgeInsets? insetPadding;
  const DialogoAdaptable({
    super.key,
    required this.child,
    this.anchoMaximo = 620,
    this.backgroundColor = Colors.white,
    this.surfaceTintColor = Colors.transparent,
    this.shape,
    this.insetPadding,
  });
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: backgroundColor,
    surfaceTintColor: surfaceTintColor,
    insetPadding:
        insetPadding ??
        EdgeInsets.symmetric(
          horizontal: DisenoAdaptable.margen(MediaQuery.sizeOf(context).width),
          vertical: 16,
        ),
    clipBehavior: Clip.antiAlias,
    shape:
        shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: anchoMaximo,
        maxHeight: DisenoAdaptable.altoDialogo(
          context,
          espacioExterior: insetPadding?.vertical ?? 32,
        ),
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: child,
      ),
    ),
  );
}

/// Sustituye la estructura de AlertDialog conservando su contenido y callbacks.
/// También hace desplazables sus acciones: un mensaje largo no las deja fuera.
class AlertaAdaptable extends StatelessWidget {
  final Widget? title, content;
  final List<Widget>? actions;
  final Color? backgroundColor, surfaceTintColor;
  final ShapeBorder? shape;
  final EdgeInsets? insetPadding;
  final EdgeInsetsGeometry titlePadding, contentPadding, actionsPadding;
  final double? actionsOverflowButtonSpacing;
  const AlertaAdaptable({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.backgroundColor,
    this.surfaceTintColor,
    this.shape,
    this.insetPadding,
    this.titlePadding = const EdgeInsets.fromLTRB(20, 20, 20, 16),
    this.contentPadding = const EdgeInsets.fromLTRB(20, 0, 20, 20),
    this.actionsPadding = const EdgeInsets.fromLTRB(20, 0, 20, 20),
    this.actionsOverflowButtonSpacing,
  });
  @override
  Widget build(BuildContext context) => DialogoAdaptable(
    backgroundColor: backgroundColor ?? Colors.white,
    surfaceTintColor: surfaceTintColor ?? Colors.transparent,
    shape: shape,
    insetPadding: insetPadding,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: titlePadding,
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              child: Semantics(header: true, child: title!),
            ),
          ),
        if (content != null) Padding(padding: contentPadding, child: content!),
        if (actions?.isNotEmpty == true)
          Padding(
            padding: actionsPadding,
            child: AccionesAdaptables(
              separacion: actionsOverflowButtonSpacing ?? 12,
              acciones: actions!,
            ),
          ),
      ],
    ),
  );
}

/// Hoja inferior con cabecera y cuerpo desplazables, también al abrir el teclado.
/// Usar con showModalBottomSheet(isScrollControlled: true, useSafeArea: true).
class HojaAdaptable extends StatelessWidget {
  final Widget child;
  const HojaAdaptable({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: DisenoAdaptable.altoDialogo(context),
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: child,
        ),
      ),
    ),
  );
}

/// Permite desplazar filtros/cabeceras altos antes de la lista, sin comprimirlos
/// dentro de una Column cuando aparece el teclado o se amplía el texto.
class PanelListaAdaptable extends StatelessWidget {
  final List<Widget> children;
  const PanelListaAdaptable({super.key, required this.children});
  @override
  Widget build(BuildContext context) => CustomScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    slivers: children
        .map(
          (hijo) => hijo is Flexible
              ? SliverFillRemaining(hasScrollBody: true, child: hijo.child)
              : SliverToBoxAdapter(child: hijo),
        )
        .toList(),
  );
}

/// Mantiene estado/cantidad al lado del título cuando cabe, o debajo cuando el
/// ancho y la letra necesitan más espacio. Los principales conservan su Expanded.
class FilaDetalleAdaptable extends StatelessWidget {
  final List<Widget> principales;
  final Widget detalle;
  const FilaDetalleAdaptable({
    super.key,
    required this.principales,
    required this.detalle,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final compacto =
          limites.maxWidth < 380 ||
          MediaQuery.textScalerOf(context).scale(14) > 18;
      if (!compacto) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [...principales, const SizedBox(width: 8), detalle],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: principales,
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: detalle),
        ],
      );
    },
  );
}

/// Conserva columnas y cantidades completas: si no caben, la tabla se desplaza
/// horizontalmente en vez de comprimir números o reducir la letra.
class TablaAdaptable extends StatelessWidget {
  final Widget child;
  final double anchoMinimo;
  const TablaAdaptable({
    super.key,
    required this.child,
    this.anchoMinimo = 420,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
      final minimo = anchoMinimo * (escala > 1 ? escala : 1);
      final ancho = limites.maxWidth > minimo ? limites.maxWidth : minimo;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ancho > limites.maxWidth)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Desliza para ver todas las columnas',
                style: TextStyle(fontSize: 12, color: Color(0xFF616161)),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: ancho, child: child),
          ),
        ],
      );
    },
  );
}
