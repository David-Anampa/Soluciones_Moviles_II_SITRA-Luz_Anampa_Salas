# Actualización de GitHub Project — 19/11/2026

Repositorio: https://github.com/David-Anampa/Soluciones_Moviles_II_SITRA-Luz_Anampa_Salas

Project: https://github.com/users/David-Anampa/projects/1

Vista de tablero sin filtro de iteración: https://github.com/users/David-Anampa/projects/1/views/3

## Resultado publicado

Se crearon las **30 historias HU-001…HU-030** como issues del repositorio, números
**#1…#30**, con descripción, criterios de aceptación, responsables, prioridades,
dependencias enlazadas, fuentes, ramas de referencia y fechas históricas.

Se crearon hitos `Sprint 01` a `Sprint 08` y se asignó cada historia a su hito.
Sprint 03 se conserva sin inventar historias/fechas no acreditadas por los ocho
dailys recibidos. Sprint 08 contiene HU-025, HU-026, HU-027 y HU-028 en backlog.

La automatización existente del Project añadió las issues creadas al tablero y
actualizó su Status al cerrar las entregas declaradas. Se verificó su presencia:
**30 tarjetas**, con **26 Done** y **4 Backlog**.

Done registra la entrega histórica confirmada por Walter a partir de los dailys.
No constituye una declaración nueva del agente de aceptación funcional completa:
los criterios verificables, las observaciones y las validaciones pendientes
permanecen expresamente en cada descripción y sus etiquetas de seguimiento.

## Responsables y fechas

- Solo se asignaron `@David-Anampa` y `@Wsalas651`.
- Sprint 6: David es responsable de OCR/IA HU-014/HU-015; Walter del resto,
  incluidas HU-003/HU-004/HU-005. Se preserva la contribución inicial de Walter
  al escaneo GTIN offline de Sprint 2.
- HU-020 tiene ambos colaboradores, diferenciando estructura de Walter y
  funcionalidad de David. HU-030 distingue implementación inicial e integración
  posterior y conserva colaboración de ambos.
- HU-001 y HU-013 conservan en su descripción la autoría inicial de Bruno
  documentada en los dailys. Las asignaciones actuales son de mantenimiento/
  seguimiento; no se falsifica quién implementó originalmente esas funciones.
- Cada issue indica la ventana del sprint y fecha de entrega reportada. Su fecha
  real de creación/cierre en GitHub es 19/11/2026; no se intenta retrofecharla.
- El seguimiento de Daily 08 del 13/11 queda asociado a las mejoras del Sprint 7.

## Contenido y prioridad

Cada historia incluye:

1. Rol, capacidad y beneficio.
2. Alcance y criterios verificables.
3. Responsable principal y colaboradores; subtareas compartidas cuando procede.
4. Sprint, ventana declarada y entrega reportada.
5. Dependencias con enlaces a las issues correctas.
6. Archivos, guías, migraciones y rama relacionada.
7. Desarrollo entregado frente a observaciones de revisión/validación posterior.
8. Prioridad propuesta con etiquetas `prioridad:critica`, `prioridad:alta`,
   `prioridad:media` o `prioridad:baja`.

Las prioridades se sustentan en seguridad, stock, dependencias y alcance. No se
inventaron puntos de historia ni horas reales. No se duplicaron historias por
su trabajo en varios sprints; esas etapas se describen dentro de la misma issue.
La rama enlazada es una referencia documental al trabajo; no se crean ramas ni
pull requests ficticios para poblar la sección Development.

## Acceso al Project y alcance de los cambios

GitHub CLI está autorizado como `Wsalas651` con los alcances `repo` y `project`.
La cuenta tiene WRITE en el repositorio, pero el Project devuelve
`viewerCanUpdate=false`. La automatización existente permitió incorporar tarjetas
y sincronizar Done/Backlog desde las issues, y los campos integrados de
Assignees/Milestone/Labels reflejan los datos del repositorio.

No se editaron directamente los campos personalizados del Project como Priority,
Size, Estimate o Iteration ni sus vistas/configuración. La prioridad está en
etiquetas/descripción, y el sprint en Milestone; no afirmar que se cargaron en
Priority/Iteration. Personalizar esos campos requiere que David otorgue a
`Wsalas651` Write en Project → Settings → Manage access.

Las vistas Current iteration y Next iteration tienen filtros de Iteration. Si
aparecen vacías, abrir la vista Prioritized backlog (views/3), cuyo filtro está
vacío, y consultar/filtrar por Milestone y Assignees. No falta información por
el solo hecho de que una vista filtrada no muestre tarjetas históricas.

Fuentes: `CRONOLOGIA_DAILYS_Y_TABLERO_2026-11-19.md`,
`PREPARACION_GITHUB_PROJECT_2026-11-19.md`, Estado de HU, guías y código vigente.
No se modificó código de la app ni datos de Supabase durante esta actualización.
