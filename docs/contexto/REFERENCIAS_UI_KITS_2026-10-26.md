# Actualización visual de Kits — 26/10/2026

Este bloque adapta la presentación de Kits al estilo existente de Administración. No completa los permisos por área ni el checkbox «Puede gestionar kits», que siguen pendientes de implementación.

## Referencias consultadas

- [Material 3: listas](https://m3.material.io/components/lists/overview).
- [Android: distribución y contenido en móviles](https://developer.android.com/design/ui/mobile/guides/layout-and-content/common-layouts).

Son referencias para organizar contenido y acciones; se conserva la identidad visual de SITRA-Luz.

## Cambios aplicados

- Tema compartido con Administración: rojo #C62828, rojo pastel, blanco y gris claro; tipografía heredada de la aplicación.
- Encabezado rojo con título, iconos y flecha blancos.
- Filtros de estado y área en filas independientes, desplazables horizontalmente.
- Tarjetas con composición desplegable y presentación/laboratorio bajo el nombre del medicamento cuando existen datos.
- Acciones mediante iconos, distribuidas en tres espacios iguales, con ayuda contextual y respuesta al hover. Se mantienen las confirmaciones existentes.
- Formulario con controles de cantidad en una fila separada del nombre para facilitar la lectura en móvil.
- Botones finales flexibles y mensajes sin identificadores técnicos de historias de usuario.

## Validación realizada

`flutter analyze --no-pub lib/features/kits/presentation`: sin observaciones.

No se ejecutaron pruebas, emulador, capturas ni cambios en Supabase. La revisión visual y funcional en dispositivo queda a cargo de Walter.

## Revisión manual sugerida

1. Abrir Administración → Kits y comprobar los colores del encabezado y la flecha.
2. Buscar por nombre y combinar filtros de área y estado.
3. Desplegar un kit con nombres largos; comprobar la lectura del medicamento, presentación, laboratorio y cantidad.
4. Mantener pulsados los iconos para ver su ayuda; en escritorio, pasar el cursor para revisar el hover.
5. Abrir Nuevo kit y Editar; comprobar espacios, selector de área y botones inferiores en el teléfono.
6. Abrir una confirmación de cambio de estado o eliminación y cancelarla antes de modificar datos reales.
