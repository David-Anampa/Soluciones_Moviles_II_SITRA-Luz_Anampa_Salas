# Base adaptable móvil — 26/10/2026

Guía reutilizable del proyecto: [SKILL.md](../../.agents/skills/sitra-flutter-responsive/SKILL.md).

La corrección combina componentes compartidos y adaptación de las vistas que los utilizan. No hay una variable global capaz de corregir todas las filas y modales. No se reduce ni se bloquea la escala de letra elegida por el usuario.

## Cambios en código

`app/lib/core/widgets/diseno_adaptable.dart` aporta:

- `ContenidoAdaptable`: limita el ancho de lectura y ajusta márgenes al espacio local. El llamador controla el scroll.
- `AccionesAdaptables`: reparte botones en columnas iguales; cuando no caben o aumenta la letra, los apila. La barra de iconos puede pasar de cuatro a dos columnas sin reducir la zona táctil.
- `DialogoAdaptable`: limita el alto según pantalla, zonas seguras y teclado; desplaza todo el contenido para que cabecera y acciones sigan siendo alcanzables. Una lista interna conserva su propio alto limitado y virtualización.

Aplicado a:

| Vista/componente | Adaptación |
|---|---|
| `CatalogoDialogo` (Áreas, Seguros/Convenios) | Modal completo desplazable y botones adaptables. |
| `MensajesApp.confirmar` | Confirmaciones con contenido largo y acciones desplazables/apilables. |
| `UsuarioFormularioView` | Zonas seguras, contenedor compartido, formulario desplazable y acciones adaptables. |
| `KitFormularioView` | Zonas seguras, contenedor compartido, título de sección flexible, cantidades que se reorganizan y botones adaptables. |
| `SelectorMedicamentoDialog` | Modal adaptable, lista con alto acotado, cantidad en Wrap y acciones adaptables. |
| `KitCard` | Barra de iconos adaptable manteniendo su tamaño táctil y colores acordados. |

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

`flutter analyze` revisa el código; no reemplaza estas comprobaciones visuales. No se ejecutaron suites, emulador ni capturas. Los demás módulos y otros modales que no usan estos componentes necesitan su revisión por separado; no se garantiza ausencia de desbordamientos en toda la aplicación.
