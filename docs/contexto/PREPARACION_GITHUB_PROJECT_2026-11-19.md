# Preparación de GitHub Project — 19/11/2026

**Actualización posterior:** las 30 historias ya se publicaron como issues y se
verificaron dentro del Project mediante su automatización. Ver el resultado y
las limitaciones de personalización en `ACTUALIZACION_GITHUB_PROJECT_2026-11-19.md`.
Los párrafos de preparación siguientes conservan el antecedente previo al acceso.

Documento de preparación y antecedentes. La publicación posterior creó y verificó
las 30 issues con sus asignaciones, hitos y estados; ver el informe de resultado.
Project identificado: https://github.com/users/David-Anampa/projects/1.
GitHub CLI ya tiene permiso `project`; falta escritura directa del colaborador en
el Project para personalizar sus campos/vistas. El usuario proporcionó ocho dailys el 19/11;
la cronología consolidada está en `CRONOLOGIA_DAILYS_Y_TABLERO_2026-11-19.md`.

## Fuentes y prioridad

1. Confirmaciones directas de Walter en la conversación, incluida la corrección
   de responsables de Sprint 6 del 19/11/2026.
2. Código/migraciones vigentes de `Sprint-07` y verificación remota actual.
3. `ESTADO_HISTORIAS_USUARIO_2026-10-13.md` y guías actualizadas, distinguiendo
   proyección de ejecución y aceptación real.
4. Backlog, evidencias, ramas, commits, issues y PR anteriores, verificando su
   correspondencia por contenido. El código antiguo US no equivale al HU actual.

No copiar automáticamente los estados futuros de las tablas de proyección a las
columnas Listo/Done del tablero. Existen implementaciones pendientes de aceptación
y hallazgos de revisión; una rama subida no demuestra aceptación funcional.

## Colaboradores autorizados

Solo asignar trabajo a:

- `@David-Anampa`: David Jordan Anampa Pancca.
- `@Wsalas651`: Walter Emmanuel Salas Jimenez.

Las referencias históricas a un tercer integrante o a «Integrante 1/2/3» no
permiten adjudicar automáticamente esas tareas a uno de los dos colaboradores.

## Reparto confirmado

| Sprint | Walter (`@Wsalas651`) | David (`@David-Anampa`) |
|---|---|---|
| 4 | HU-012; estructura de HU-020. | Resto de HU-020, HU-021 y HU-022. |
| 5 | HU-023, HU-024 y ajuste HU-029; validación conjunta de HU-030. | HU-017/HU-018/HU-019; validación conjunta de HU-030. |
| 6 | Todo el trabajo de ese sprint ajeno a IA: HU-003/HU-004/HU-005 e integración. | Reconocimiento OCR/IA, extracción y revisión de datos: HU-014/HU-015. |
| 7 | HU-008/HU-009/HU-010/HU-011. | HU-006/HU-007 y refinamiento del contrato HU-025. |
| 8 | HU-025/HU-028. | HU-026/HU-027. |

HU-020 conserva una sola historia con subtareas y responsables diferenciados.
El refinamiento del contrato HU-025 en Sprint 7 no significa que David sea el
responsable de completar esa historia en Sprint 8; Walter conserva esa entrega.
El trabajo de integración ajeno a IA en Sprint 6 debe detallarse con la evidencia
correspondiente, sin duplicar historias ni modificar la autoría de commits.

## Información que debe tener cada issue

```markdown
# HU-XXX — Título estable

## Historia
Como [rol], quiero [capacidad] para [beneficio].

## Alcance
- Comportamiento y reglas acordadas.
- Qué pertenece a esta HU y sus dependencias con otras historias.

## Criterios de aceptación
- [ ] Criterios comprobables tomados de los acuerdos y requisitos vigentes.

## Responsables y subtareas
- Responsable principal: @...
- [ ] Subtarea concreta — @...
- Revisión/integración, si corresponde: @...

## Planificación y ejecución
- Sprint planificado: ...
- Sprint de ejecución/cierre: ... o pendiente de confirmar.
- Inicio real: ... o sin evidencia.
- Fin de desarrollo: ... o sin evidencia.
- Validación/aceptación: pendiente o evidencia confirmada.
- Arrastre y motivo, si corresponde: ...

## Estado actual
- Estado y explicación sustentados por código, despliegue y validación.
- Pendientes, bloqueos y diferencias conocidas.

## Evidencia
- Markdown/requisitos.
- Archivos y migraciones.
- Commits, rama y PR relacionados.
- Resultado de las verificaciones realmente realizadas.

## Seguimiento
- Enlaces a registros reales de daily/revisión y acuerdos.
```

Los nombres de campos y opciones deben adaptarse al Project existente, evitando
crear campos o issues duplicados. Reutilizar los issues correctos una vez
verificada su equivalencia. La descripción complementa los campos de sprint,
responsable, prioridad, estimación, fechas y estado disponibles en el tablero.
No inventar puntos, horas invertidas, fechas de aceptación o reuniones.

## Fechas y seguimiento

- Distinguir fecha de creación del issue de fecha histórica de trabajo.
- Distinguir calendario planificado del sprint de fecha real de ejecución.
- El plan ubica Sprint 6 entre 26/10 y 01/11, pero la entrega tiene referencias
  a 06/11. Es un posible arrastre/desfase a confirmar, no una fecha a corregir
  automáticamente para que el calendario parezca cumplido.
- Documentar los dailys/seguimientos que sí se hicieron. Los títulos «daily
  semanal — registro proyectado» actuales no prueban reuniones realizadas.
- Si se reconstruye un periodo sin actas, denominarlo «resumen retrospectivo
  reconstruido», con fuentes/fecha de preparación y hechos por confirmar.
- Para futuros seguimientos se pueden planificar dos registros semanales si
  coincide con el formato docente; eso no autoriza a inventarlos en el pasado.

## Evidencia histórica localizada

- `docs/sprints/sprint-01/SPRINT_BACKLOG.md`: existe planificación de Sprint 1,
  con fechas 04/09–14/09/2026 e integrantes genéricos. Confirmar vigencia/ejecución
  y responsables antes de trasladarla como historia real del tablero.
- `docs/evidencias/S01/`, `S02/`, `S03/`: existen evidencias, que deben contrastarse
  con entregas y registro docente. Su presencia no completa automáticamente el
  tablero ni valida todas las historias.
- `docs/evidencias/S03/salidas/git_log.txt`: contiene referencias a «Taller 03»
  y planificación de Sprint 1. No equiparar número de taller con número de sprint.
- `docs/sprints/PRODUCT_BACKLOG.csv`: usa US-01… con contenidos que no coinciden
  uno a uno con las HU actuales. Reconciliar por título/alcance, no por número.
- El plan detallado por persona en Estado de HU cubre Sprint 4–8. El contenido
  y responsables efectivos de Sprint 3 siguen requiriendo confirmación.

## Información recibida y bloqueo de acceso

1. El usuario entregó el enlace exacto al Project y los Daily 01–08.
2. Confirmó que la entrega del daily acredita el trabajo realizado. Se conserva
   esa declaración diferenciada de verificaciones técnicas y observaciones nuevas.
3. La cronología usa las fechas de esos informes, incluidos sus solapamientos y
   el seguimiento posterior del Sprint 7. No se inventa un daily de Sprint 3.
4. Se registrará un seguimiento por cada informe recibido; no generar dos por
   semana de forma automática.
5. El usuario delegó redacción, prioridades y metadatos sustentados en el proyecto.
6. Las asignaciones actuales se limitan a David/Walter, conservando la autoría
   histórica de Bruno en la descripción cuando el daily la documenta.

La autorización de GitHub CLI se completó con `project`. Se publicaron las 30
historias y la automatización existente las añadió al Project: 26 Done y 4 Backlog,
verificadas individualmente. El acceso directo al Project de Wsalas651 sigue en
lectura; únicamente personalizar sus campos/vistas queda condicionado a que
David conceda Write. Los sprints están en Milestone y prioridades en etiquetas;
no se afirma que estén asignados en los campos personalizados Iteration/Priority.

Mientras faltan datos se puede completar descripciones, criterios, dependencias
y reparto sustentados; mantener explícitos los campos históricos desconocidos.
