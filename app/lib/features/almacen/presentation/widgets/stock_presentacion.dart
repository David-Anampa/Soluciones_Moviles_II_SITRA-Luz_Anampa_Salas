import 'package:flutter/material.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../domain/entities/stock_ubicacion_entity.dart';

const stockRojo = Color(0xFFC62828);
const stockPastel = Color(0xFFFFF0F0);
const stockFondo = Color(0xFFF5F5F5);

ThemeData temaStock(BuildContext context) => Theme.of(context).copyWith(
  colorScheme: Theme.of(context).colorScheme.copyWith(
    primary: stockRojo,
    secondary: stockRojo,
    onPrimary: Colors.white,
    surface: Colors.white,
    surfaceTint: Colors.transparent,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: stockRojo,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: stockRojo),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(foregroundColor: stockRojo),
  ),
  chipTheme: Theme.of(context).chipTheme.copyWith(
    selectedColor: stockPastel,
    backgroundColor: Colors.white,
    checkmarkColor: stockRojo,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: Theme.of(context).textTheme.titleLarge,
    contentTextStyle: Theme.of(context).textTheme.bodyMedium,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: stockRojo,
    foregroundColor: Colors.white,
    iconTheme: const IconThemeData(color: Colors.white),
    actionsIconTheme: const IconThemeData(color: Colors.white),
    titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF7F7F7),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: stockRojo, width: 1.5),
    ),
  ),
);

class StockSeccion extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final List<Widget> children;
  const StockSeccion({
    super.key,
    required this.titulo,
    required this.icono,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE6E6E6)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: stockPastel,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, color: stockRojo, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) const SizedBox(height: 18),
        ],
      ],
    ),
  );
}

class StockContadores extends StatelessWidget {
  final StockUbicacionEntity item;
  const StockContadores({super.key, required this.item});
  @override
  Widget build(BuildContext context) => AccionesAdaptables(
    anchoMinimo: 80,
    separacion: 8,
    acciones: [
      _dato(Icons.local_pharmacy_outlined, 'Farmacia', item.farmacia),
      _dato(Icons.warehouse_outlined, 'Almacén', item.almacen),
      _dato(Icons.local_shipping_outlined, 'En tránsito', item.transito),
    ],
  );
  Widget _dato(IconData icono, String nombre, int cantidad) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
    decoration: BoxDecoration(
      color: stockPastel,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Icon(icono, color: stockRojo, size: 21),
        const SizedBox(height: 8),
        Text(
          '$cantidad',
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: stockRojo,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          nombre,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    ),
  );
}
