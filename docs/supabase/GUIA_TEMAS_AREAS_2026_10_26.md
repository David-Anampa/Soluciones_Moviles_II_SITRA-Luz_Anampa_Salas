# Temas de áreas y mensajes — 26/10/2026

## Instalación

En una base existente, ejecutar en SQL Editor:

1. `migracion_kits_por_area_2026_10_26.sql`, si todavía no se instaló (ver sus dependencias en la guía de Kits).
2. `migracion_temas_areas_2026_10_26.sql`.

No reinstalar migraciones anteriores después de estas; reemplazarían las funciones vigentes. No ejecutar `setup_sitra_luz.sql` sobre la base existente. El setup incluye ambos bloques para bases nuevas. Esta entrega prepara SQL, **no lo ejecuta en Supabase**.

## Tema persistente del área

Administrador elige el tema en Gestión administrativa → Áreas → Crear/Editar. Se muestra una paleta y una vista previa con encabezado, zona pastel, tarjeta blanca y botón. Cancelar no cambia datos; guardar persiste datos y tema en la misma transacción, con auditoría.

`areas.tema_color` almacena un código de paleta, no un color arbitrario. La restricción SQL y la RPC aceptan exactamente estos códigos:

| Código | Nombre | Principal | Pastel |
|---|---|---|---|
| ROJO | Rojo institucional | #C62828 | #FFF0F0 |
| AZUL | Azul | #245B8F | #EDF4FB |
| CELESTE | Celeste | #156B97 | #EBF7FC |
| LAVANDA | Lavanda | #67518C | #F3EFF9 |
| ROSA | Rosa | #934261 | #FCF0F5 |
| GRIS_AZUL | Gris azulado | #4F6274 | #F0F3F6 |

Las áreas existentes conservan ROJO por defecto: no se asignan colores basándose en su nombre ni se alteran sus códigos. La paleta tiene principales suficientemente oscuros para usar letras/iconos blancos; los pasteles sirven para superficies y selección. Se conservan tipografía, tamaños, botones y espacios del estilo existente.

`guardar_area_con_tema` exige Administrador activo y reutiliza `administrar_catalogo_hu012`; no reemplaza sus controles de eliminación, asignación e historial. El evento `AREA_TEMA` registra el cambio de tema, junto con la auditoría de datos del catálogo. Un error revierte todo.

`contexto_kits_por_area` devuelve también el tema del área con los mismos permisos de consulta anteriores. Kits lo aplica a encabezado, botones, filtros, iconos y detalles pastel del área seleccionada. Crear/Editar/Duplicar conserva ese tema; cambiar de área en el formulario lo actualiza. En Administración sin área seleccionada se mantiene rojo institucional; las tarjetas de kits muestran detalles del tema de su área.

El tema se vuelve a consultar al abrir/actualizar la lista. No se instala un servicio de cambios en tiempo real. Las futuras pantallas de pedidos podrán reutilizar la paleta y el mismo campo; esas pantallas no se implementan en este bloque.

## Mensajes independientes

`core/widgets/mensajes_app.dart` define una paleta semántica separada de `TemaArea`:

- Error: círculo con equis, rojo y fondo rojo suave.
- Advertencia: triángulo con exclamación, ámbar y fondo suave.
- Éxito: círculo con check, verde y fondo suave.
- Información: círculo con «i», azul y fondo suave.

Cada aviso usa icono y texto; no depende solo del color. Se aplican en los flujos actuales de Administración y Kits: notas, errores, resultados de guardado/estado/eliminación, confirmaciones y faltantes. Las confirmaciones destructivas conservan botón rojo; los resultados breves no abren modales innecesarios. Deshabilitar áreas sigue sin modal; las confirmaciones que ya existían en Kits y Usuarios se mantienen.

Otros módulos conservan sus avisos anteriores hasta integrarlos con el componente común; no se afirma una sustitución global de todas las pantallas. Los mensajes no se configuran en la base ni cambian al elegir un tema de área.

## Verificación manual pendiente

1. Aplicar las migraciones en su orden y reiniciar la aplicación.
2. Editar un área, elegir Celeste y observar la vista previa; cancelar y verificar que el valor anterior se conserva.
3. Guardar Celeste, reabrir el editor y comprobar que sigue seleccionado.
4. Entrar en Kits con un usuario de esa área: comprobar encabezado/botón principal, superficies pastel, letras e iconos blancos sobre color principal. Probar otro tema y otra área.
5. Abrir Nuevo/Editar/Duplicar kit y el selector de medicamentos; comprobar que mantienen el tema correcto y los campos siguen legibles.
6. Guardar un registro: aviso verde con check. Provocar un error de validación/servidor: error rojo con equis. Revisar un faltante o confirmación: advertencia ámbar. Estos colores deben mantenerse también en áreas celestes o lavanda.
7. Cancelar una confirmación de eliminación y verificar que no se elimina. Confirmar solo sobre un borrador creado para la revisión, sin historial.

Se ejecuta `flutter analyze --no-pub` para revisar Dart. No se ejecutan pruebas, emulador, capturas ni migraciones remotas en esta entrega; la aceptación visual/funcional queda pendiente del usuario.
