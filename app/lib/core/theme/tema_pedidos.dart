import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import 'package:flutter/material.dart';
import '../widgets/menu_modulos.dart';
import 'app_theme.dart';

/// Apariencia compartida; no contiene permisos ni acciones de los pedidos.
class TemaPedidos {
  /// Ámbito exclusivamente visual. Nunca usar este resultado para permisos.
  static String rolActual(BuildContext context) {
    try {
      final uri = GoRouter.of(context).routeInformationProvider.value.uri;
      // Los subflujos de Navigator conservan la ruta del módulo de origen.
      for (final entry in const {
        '/farmacia': 'FARMACIA',
        '/enfermeria': 'ENFERMERIA',
        '/almacen': 'ALMACEN',
        '/jefatura': 'JEFATURA_FARMACIA',
      }.entries) {
        if (uri.path == entry.key || uri.path.startsWith('${entry.key}/')) {
          return entry.value;
        }
      }
      if (uri.path == '/kits') {
        final vista = uri.queryParameters['vista'];
        if (vista == 'FARMACIA' || vista == 'ENFERMERIA') return vista!;
      }
    } catch (_) {
      /* Sin router: usar la identidad de la sesión. */
    }
    return context.read<AuthViewModel>().currentUser?.rol.dbValue ?? '';
  }

  static Color colorRol(String rol) => switch (rol.toUpperCase()) {
    'ALMACEN' => AppColors.almacenColor,
    'FARMACIA' => AppColors.farmaciaColor,
    'JEFATURA_FARMACIA' => AppColors.jefaturaColor,
    'ENFERMERIA' => AppColors.enfermeriaColor,
    _ => AppColors.primary,
  };

  static ThemeData aplicar(
    BuildContext context,
    String rol, {
    ThemeData? base,
  }) {
    final theme = base ?? Theme.of(context);
    final color = colorRol(rol);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final buttons = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      shape: WidgetStatePropertyAll(shape),
      textStyle: WidgetStatePropertyAll(
        theme.textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return theme.copyWith(
      chipTheme: theme.chipTheme.copyWith(
        selectedColor: color.withValues(alpha: .10),
        checkmarkColor: color,
      ),
      scaffoldBackgroundColor: AppColors.background,
      progressIndicatorTheme: theme.progressIndicatorTheme.copyWith(
        color: color,
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        errorMaxLines: 3,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
      ),
      colorScheme: theme.colorScheme.copyWith(
        primary: color,
        secondary: color,
        secondaryContainer: color.withValues(alpha: .10),
        onSecondaryContainer: color,
        onPrimary: Colors.white,
        surfaceTint: Colors.transparent,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: color,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: buttons.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? const Color(0xFFE5E7EB)
                : color,
          ),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttons.copyWith(
          foregroundColor: WidgetStatePropertyAll(color),
          side: WidgetStatePropertyAll(
            BorderSide(color: color.withValues(alpha: .4)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: buttons.copyWith(foregroundColor: WidgetStatePropertyAll(color)),
      ),
    );
  }
}

class FranjaPedidos extends StatelessWidget {
  final String titulo;
  final IconData icono;
  const FranjaPedidos({super.key, required this.titulo, required this.icono});
  @override
  Widget build(BuildContext context) => CabeceraMenu(
    titulo: titulo,
    icono: icono,
    color: Theme.of(context).colorScheme.primary,
  );
}
