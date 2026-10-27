---
name: sitra-flutter-responsive
description: Crear o corregir interfaces Flutter de SITRA-Luz adaptables al ancho, teclado y tamaño de texto, conservando la identidad visual y evitando desbordamientos en formularios, tarjetas y modales.
---

# Diseño móvil adaptable de SITRA-Luz

Trabajar sobre las vistas solicitadas y sus componentes compartidos. No rediseñar otros módulos, cambiar permisos, mover stock ni modificar Supabase para resolver un problema de distribución.

## Base existente

Localizar estos archivos desde la raíz del repositorio antes de extenderlos:

- `app/lib/core/widgets/diseno_adaptable.dart`: márgenes, contenido de página, acciones y diálogos.
- `app/lib/core/widgets/mensajes_app.dart`: significado de información, éxito, advertencia y error, independiente del tema del área.
- `app/lib/core/theme/tema_area.dart`: paleta principal/pastel elegida por Administrador.
- `app/lib/features/administracion/presentation/widgets/catalogo_estilo.dart`: tipografía, controles, hover y tema derivado.

Ejemplos actuales: `CatalogoDialogo`, `UsuarioFormularioView`, `KitFormularioView`, `SelectorMedicamentoDialog` y `KitCard`.

La base está aplicada también a Login, los cinco paneles por rol, medicamentos/lotes, stock, solicitudes, diferencias/correcciones y escáner. Leer el registro de cobertura en `docs/contexto/RESPONSIVIDAD_MOVIL_2026-10-26.md` para distinguir implementación de aceptación visual pendiente.

## Decisiones de distribución

1. Usar el ancho local de `LayoutBuilder`, no el modelo del teléfono. `MediaQuery` aporta zonas seguras, teclado y escala de texto; no reemplaza las restricciones del componente.
2. En páginas con formulario, usar `SafeArea` y `ContenidoAdaptable`; el formulario mantiene su `ListView` o `SingleChildScrollView`. El Scaffold ajusta el cuerpo al teclado. No sumar otra vez el mismo `viewInsets.bottom` al contenido ya reducido.
3. Usar `AccionesAdaptables` con botones normales, sin `Expanded`/`Flexible` como hijos. Reorganiza en columnas iguales o apila según ancho y texto. En barras de iconos, indicar `anchoMinimo: 48`, `considerarTexto: false` y mantener ayuda accesible.
4. Usar `DialogoAdaptable` para modales del alcance actual: acota el alto visible y permite desplazar todo el contenido, incluidas cabecera y acciones. No colocar `Expanded`/`Spacer` verticales dentro de ese scroll. Una lista de búsqueda interna debe tener alto acotado para mantener la virtualización.
5. Para nuevas tareas largas, preferir una pantalla completa con formulario desplazable; reservar modales para decisiones y selecciones acotadas. No convertir pantallas existentes fuera del alcance acordado.
6. Dar espacio flexible al texto dentro de filas. Si el conjunto no cabe, reordenar mediante `Wrap`, columna o `AccionesAdaptables`; no resolverlo ocultando información esencial.
7. Para confirmaciones con contenido propio, usar `AlertaAdaptable` conservando validaciones y callbacks. Para hojas inferiores, usar `HojaAdaptable` con `isScrollControlled: true` y `useSafeArea: true`, sin Flex vertical no acotado.
8. Separar título/estado con `FilaDetalleAdaptable` cuando compitan por ancho. Usar `PanelListaAdaptable` si los filtros altos compiten con una lista. Las tablas numéricas pueden usar `TablaAdaptable` para desplazarse horizontalmente, sin comprimir cantidades.
9. La cámara mantiene su fondo a pantalla completa; adaptar sus controles y marco por separado. Evitar encerrar la cámara entera en un formulario o reducir el texto para hacer caber sus paneles.
10. Cambios de distribución pueden requerir ajustar el alto de navegación con `DisenoAdaptable.altoCabecera`. No limitar globalmente el tamaño de texto como solución.

## Legibilidad e identidad

- Conservar fuente y tamaños del tema. Reducir márgenes decorativos antes de reducir texto. Respetar `MediaQuery.textScalerOf`: no imponer `TextScaler.noScaling`, escalado global proporcional al ancho ni `FittedBox` para comprimir textos clínicos.
- Medicamento, laboratorio, motivo y justificación deben poder leerse completos. Un título de navegación puede resumirse si el detalle completo sigue accesible.
- Mantener controles táctiles de al menos 48 píxeles lógicos cuando el espacio lo permite; usar scroll/reorganización en vez de disminuir iconos hasta volverlos difíciles de tocar.
- Área: principal y pastel de su paleta; blanco/gris en superficies de lectura; texto/iconos blancos sobre encabezados de color.
- Acciones de Kits confirmadas por el usuario: editar rojo pastel con lápiz rojo y hover; eliminar rojo fuerte con icono blanco; habilitación verde/rojo con icono reconocible. No imponer otro color de edición basándose en una tendencia.
- Mensajes: error rojo/equis, advertencia ámbar/triángulo, éxito verde/check e información azul. No recolorearlos según el área.
- Conservar confirmaciones y restricciones de negocio existentes. Cancelar/cerrar un modal no confirma una acción.

## Aplicación práctica

Para una pantalla futura, comenzar con una estructura como esta, adaptando datos y acciones:

```dart
Scaffold(
  resizeToAvoidBottomInset: true,
  body: SafeArea(
    child: ContenidoAdaptable(
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          formulario,
          AccionesAdaptables(acciones: [cancelar, guardar]),
        ],
      ),
    ),
  ),
)
```

Si aparece una franja de desbordamiento, localizar primero la vista y el widget de la excepción. Revisar filas con textos largos, anchos mínimos, contenido fijo y relaciones entre Flex/scroll antes de cambiar fuentes o crear parámetros globales nuevos.

## Verificación y entrega

Respetar la autorización vigente del usuario: actualmente permite `flutter analyze`, pero realiza las pruebas manuales. No iniciar emulador, tomar capturas ni ejecutar suites por iniciativa propia. No afirmar que el análisis de Dart demuestra ausencia de errores visuales.

Proponer al usuario comprobar, en las vistas afectadas:

- Anchos de 320, 360 y 412 píxeles lógicos; además, orientación horizontal.
- Texto normal, ampliado y muy ampliado (aproximadamente 1,3 y 2 veces).
- Teclado abierto y cerrado, especialmente en búsqueda y campos del final.
- Nombres/laboratorios largos, mensajes extensos y cantidades de varios dígitos.
- Cancelar, confirmar y guardar: mismas reglas y sin doble envío.

Documentar los componentes adoptados, pantallas cubiertas y límites pendientes. Hacer commits breves del alcance autorizado; no incluir modificaciones locales ajenas. No declarar toda la aplicación adaptada por corregir un módulo. La aceptación visual requiere revisar esas pantallas en dispositivos o tamaños representativos.
