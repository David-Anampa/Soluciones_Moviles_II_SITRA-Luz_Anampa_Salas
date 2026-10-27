# Base adaptable móvil — 26/10/2026

**Cobertura ampliada a todas las pantallas actualmente implementadas.** Se revisaron las vistas y componentes de presentación de todos los módulos. Esta es cobertura de cambios de código, no una certificación visual de todos los celulares; la aceptación manual sigue pendiente.

Guía reutilizable del proyecto: [SKILL.md](../../.agents/skills/sitra-flutter-responsive/SKILL.md).

La corrección combina componentes compartidos y adaptación de las vistas que los utilizan. No hay una variable global capaz de corregir todas las filas y modales. No se reduce ni se bloquea la escala de letra elegida por el usuario.

## Cambios en código

`app/lib/core/widgets/diseno_adaptable.dart` aporta:

- `ContenidoAdaptable`: limita el ancho de lectura y ajusta márgenes al espacio local. El llamador controla el scroll.
- `AccionesAdaptables`: reparte botones en columnas iguales; cuando no caben o aumenta la letra, los apila. La barra de iconos puede pasar de cuatro a dos columnas sin reducir la zona táctil.
- `DialogoAdaptable`: limita el alto según pantalla, zonas seguras y teclado; desplaza todo el contenido para que cabecera y acciones sigan siendo alcanzables. Una lista interna conserva su propio alto limitado y virtualización.
- `AlertaAdaptable`: misma información y callbacks de las confirmaciones anteriores, con contenido y acciones desplazables/reorganizados.
- `HojaAdaptable`: detalle de usuarios, opciones de ingreso y selector de códigos en hojas inferiores que respetan teclado y zonas seguras.
- `FilaDetalleAdaptable`: mueve estado/cantidad debajo del encabezado si el título necesita más espacio.
- `PanelListaAdaptable`: permite desplazar filtros y cabeceras antes de la lista cuando no caben en la altura visible.
- `TablaAdaptable`: conserva los números completos; las comparaciones se desplazan horizontalmente cuando no caben.
- `DisenoAdaptable.altoCabecera`: calcula espacio para la letra ampliada en las barras de navegación, sin bloquear su escala.

Aplicado a:

| Vista/componente | Adaptación |
|---|---|
| `CatalogoDialogo` (Áreas, Seguros/Convenios) | Modal completo desplazable y botones adaptables. |
| `MensajesApp.confirmar` | Confirmaciones con contenido largo y acciones desplazables/apilables. |
| `UsuarioFormularioView` | Zonas seguras, contenedor compartido, formulario desplazable y acciones adaptables. |
| `KitFormularioView` | Zonas seguras, contenedor compartido, título de sección flexible, cantidades que se reorganizan y botones adaptables. |
| `SelectorMedicamentoDialog` | Modal adaptable, lista con alto acotado, cantidad en Wrap y acciones adaptables. |
| `KitCard` | Barra de iconos adaptable manteniendo su tamaño táctil y colores acordados. |
| Login | Ancho de lectura limitado, zonas seguras, scroll con teclado y botón sin alto máximo rígido. |
| Paneles de Administrador, Almacén, Farmacia, Enfermería y Jefatura | Zonas seguras, ancho limitado, cabecera que crece con el texto, resúmenes que se reorganizan y etiquetas que admiten varias líneas. |
| Listados de Áreas/Seguros y Usuarios | Filtros desplazables/reorganizados, tarjetas con estado separado del título cuando falta ancho y hojas de detalle adaptables. |
| Registro y edición de medicamentos | Campos antes colocados en filas rígidas pasan a columnas si no caben; cuerpo desplazable y acciones sin alto rígido. |
| Ingreso de lotes | Campos y acciones adaptables, con cuerpo y selectores preparados para teclado/letra ampliada. |
| Stock Farmacia/Almacén | Cantidades por ubicación reorganizables, zonas seguras y ancho limitado. |
| Crear solicitud / envío a Farmacia | Formulario desplazable, selectores con ancho y altura de ítem adaptables y cabecera con espacio para texto. |
| Solicitudes Farmacia → Almacén | Contenido seguro, etiquetas largas sin fila rígida y modales de toma, cancelación, despacho y recepción con acciones alcanzables. |
| Transferencia a Farmacia | Modal adaptable, resumen origen/destino reorganizable y atajos de cantidad distribuidos según el ancho. |
| Diferencias e ingresos/correcciones | Listados y formularios adaptados, confirmaciones desplazables y tablas con scroll horizontal para no comprimir cantidades. |
| Escáner GTIN y fotografía | Cámara a pantalla completa; marco ajustado al espacio, controles desplazables en paisaje/letra grande, lista de códigos con alto acotado y espera de IA desplazable. |

Scaffold continúa ajustando los formularios al teclado; no se añade dos veces el espacio del teclado. Se conservan fuente, temas de área, colores de acciones/mensajes y reglas de guardado/permisos. No hay migración SQL.

## Uso en nuevas pantallas

Leer la skill y reutilizar estos componentes. Para formularios largos, usar una pantalla desplazable. No colocar `Expanded`/`Spacer` vertical dentro de `DialogoAdaptable` ni pasar `Expanded` como acción. Validar siempre la distribución propia del nuevo contenido.

La skill queda versionada dentro del repositorio para Walter y David; puede indicarse su ruta al iniciar un nuevo chat. No se modificó la configuración personal de skills fuera del proyecto.

## Verificación pendiente por el usuario

En un teléfono pequeño y en el dispositivo que mostró la franja:

1. Abrir Crear/Editar área y seguro, desplegar el teclado en campos del final y llegar a Guardar/Cancelar mediante desplazamiento.
2. Revisar las confirmaciones con nombres y mensajes largos; comprobar que ambos botones se pueden alcanzar.
3. Abrir Crear/Editar usuario y kit; aumentar la letra del sistema y repetir con teclado.
4. En el selector de medicamentos, buscar, seleccionar, escribir cantidad y llegar a Agregar sin recortes.
5. Desplegar un kit con laboratorio/nombre largo; revisar barra de acciones y cantidades.
6. Girar el dispositivo y repetir. No debe depender de bloquear la orientación o reducir la letra para que funcione.
7. Repetir en Login y en cada panel por rol, incluidos resúmenes y tarjetas con nombres extensos.
8. En Almacén abrir Registrar/Editar medicamento e Ingreso de lote; escribir en los campos inferiores con teclado visible y revisar los selectores.
9. Abrir solicitudes como Farmacia y como Almacén: revisar toma/cancelación/rechazo/despacho/recepción sin confirmar operaciones reales durante la revisión puramente visual.
10. Revisar diferencias y correcciones con valores de varios dígitos; desplazar las tablas para leer todas las columnas.
11. Girar el escáner y ampliar letra; comprobar que los controles de cámara y las opciones de captura pueden alcanzarse sin recortes.

`flutter analyze --no-pub` terminó sin observaciones tras ampliar la cobertura. No se ejecutaron suites, emulador, capturas ni SQL. No se modificaron repositorios de datos, entidades, permisos ni movimientos de stock; el cambio es de presentación.

Las pantallas futuras deben reutilizar la skill y los componentes, pero no se adaptan automáticamente por tener esta base. Una franja concreta todavía requiere identificar su widget y reproducir su combinación de tamaño, teclado y texto. La revisión estática y el análisis no garantizan ausencia de desbordamientos en todas las configuraciones posibles.
