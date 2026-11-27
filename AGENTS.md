# Instrucciones del proyecto

Antes de crear o modificar interfaces, leer
[las reglas de uniformidad y colores](docs/contexto/REGLAS_UNIFORMIDAD_Y_COLORES.md).
Son acuerdos explícitos del usuario y se aplican también a cambios pequeños,
formularios, filtros, modales y vistas compartidas.

- Resolver la apariencia según el módulo abierto; no confundirla con el rol
  autenticado que determina permisos. Administración entrando a Farmacia debe
  ver el módulo verde, conservando sus permisos reales.
- Reutilizar componentes y temas compartidos. No reintroducir colores fijos
  rojos/azules en controles que deben seguir el color del módulo.
- Conservar datos, validaciones, estados, stock, justificaciones y auditoría
  durante cambios visuales. Documentar cualquier cambio de alcance necesario.
- Uniformar combobox y checkbox con los componentes compartidos y el color del
  módulo: `SelectorCatalogo` y `OpcionMultiple`. Más de cuatro opciones en un
  combobox deben permitir búsqueda. Revisar también formularios y modales.
- Mantener espacio suficiente, texto legible y desplazamiento en celulares.
- Ejecutar `flutter analyze --no-pub` desde `app` para cambios de Flutter. Las
  pruebas funcionales las realiza el usuario salvo que autorice otras pruebas.
- Agrupar cambios importantes en commits; no crear un commit por cada retoque.
- Respetar cambios locales ajenos, especialmente `app/android/gradle.properties`.

Los acuerdos nuevos y explícitos del usuario prevalecen. Actualizar el documento
de diseño cuando cambien estas preferencias, indicando qué acuerdo se sustituye.
