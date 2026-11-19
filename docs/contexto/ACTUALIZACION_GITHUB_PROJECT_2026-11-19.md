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
Tras conceder Admin en el Project, se confirmó `viewerCanUpdate=true`.
Admin permite editar el tablero y gestionar sus accesos; Write habría sido
suficiente para organizar las historias. No se cambiaron permisos desde el agente.

Las 30 tarjetas tienen campos nativos Sprint, Priority, Rama, Seguimiento y Daily.
Entrega reportada, Inicio sprint y Fin sprint se completan cuando los dailys
aportan esas fechas. Sprint 8 conserva las fechas vacías al no existir entrega
ni calendario confirmado. Assignees/Milestone/Labels reflejan el repositorio.

Priority usa P0 para crítica, P1 para alta y P2 para media/baja; las etiquetas
conservan la distinción entre las cuatro prioridades. Seguimiento diferencia
entregas con observaciones, pendientes de validación y sin entrega reportada.
No se inventaron valores para Size ni Estimate.

El campo Sprint contiene Sprint 01…08. Iteration conserva el calendario de
plantilla: sus periodos de 14 días no coinciden con las ventanas históricas de
los dailys, que además presentan solapamientos. No se sustituyeron las fechas
aportadas por periodos ficticios para encajarlas en esa plantilla.

Las vistas Current iteration y Next iteration tienen filtros de Iteration. Si
aparecen vacías, abrir la vista Prioritized backlog (views/3), cuyo filtro está
vacío, y consultar/filtrar por Sprint, Milestone y Assignees. No falta información por
el solo hecho de que una vista filtrada no muestre tarjetas históricas.

Fuentes: `CRONOLOGIA_DAILYS_Y_TABLERO_2026-11-19.md`,
`PREPARACION_GITHUB_PROJECT_2026-11-19.md`, Estado de HU, guías y código vigente.
No se modificó código de la app ni datos de Supabase durante esta actualización.

## Vinculaciones nativas de ramas y dependencias

Actualización posterior autorizada por Walter: se vincularon las **30 issues**
a sus ramas existentes en **Development** y se registraron **68 dependencias**
en **Relationships → Blocked by / Blocking**, siguiendo la sección Dependencias
de las descripciones. La comprobación remota confirmó cada rama, cada dependencia
y la conservación del estado de las 30 issues. El grafo no presenta ciclos.

| Rama vinculada | Historias |
|---|---|
| Sprint-01 | HU-001, HU-002 |
| Sprint-02 | HU-013, HU-016 |
| Sprint-04 | HU-012, HU-020, HU-021, HU-022 |
| Sprint-05 | HU-017, HU-018, HU-019, HU-023, HU-024, HU-029, HU-030 |
| Sprint-06 | HU-003, HU-004, HU-005, HU-014, HU-015 |
| Sprint-07 | HU-006, HU-007, HU-008, HU-009, HU-010, HU-011 |
| Sprint-08 | HU-025, HU-026, HU-027, HU-028 |

No se inventaron relaciones de padre/subhistoria entre historias independientes.
Las dependencias cerradas expresan requisitos ya entregados; no se reabrieron
historias para representarlas. Sprint-03 sigue sin historias acreditadas.

La vinculación de Sprint-08 representa el destino de trabajo planificado. Al
verificarla, esa rama apuntaba al mismo commit que Sprint-05; asociarla no acredita
implementación del Sprint 8. Sus cuatro historias permanecen abiertas en Backlog.

Las dependencias se aplicaron mediante la API pública desde GitHub CLI. Las ramas
existentes se asociaron desde la interfaz Development y después se verificaron
por GraphQL (`linkedBranches`). No se crearon ramas, PR ni merges a main.
