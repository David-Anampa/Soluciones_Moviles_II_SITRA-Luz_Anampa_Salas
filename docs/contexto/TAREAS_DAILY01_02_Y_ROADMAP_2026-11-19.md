# Tareas de Daily 01/02 y Roadmap — 19/11/2026

## Alcance y fuentes

Walter solicitó completar las tareas omitidas al registrar inicialmente las 30 HU,
asociar sus ramas/relaciones y ordenar el Roadmap con las fechas de los dailys.
Posteriormente autorizó estimar las fechas no documentadas por continuidad del
calendario. Las estimaciones se identifican como planificación, sin atribuirles
ejecución histórica ni entrega real.

Daily 01 (11/09/2026) y Daily 02 (18/09/2026) indican expresamente **Sprint 01**,
del **07/09/2026 al 18/09/2026**. No corresponden a Sprint 02.

## Issues adicionales

Todas tienen milestone Sprint 01 y vínculo real a Sprint-01 en Development.

| Código | Issue | Trabajo | Autor histórico | Seguimiento actual |
|---|---|---|---|---|
| TT-01 | [#31](https://github.com/David-Anampa/Soluciones_Moviles_II_SITRA-Luz_Anampa_Salas/issues/31) | Esquema MSSQL/NoSQL | Bruno | David |
| TT-02 | [#32](https://github.com/David-Anampa/Soluciones_Moviles_II_SITRA-Luz_Anampa_Salas/issues/32) | Contrato API | Bruno | David |
| TT-03 | [#33](https://github.com/David-Anampa/Soluciones_Moviles_II_SITRA-Luz_Anampa_Salas/issues/33) | MVVM, CI/CD y entornos iniciales | Walter | Walter |
| TT-04 | [#34](https://github.com/David-Anampa/Soluciones_Moviles_II_SITRA-Luz_Anampa_Salas/issues/34) | Documentación ER/modelo híbrido | David | David |
| DT-01 | [#35](https://github.com/David-Anampa/Soluciones_Moviles_II_SITRA-Luz_Anampa_Salas/issues/35) | Wireframes de los tres módulos | David | David |
| RNF-001 | [#36](https://github.com/David-Anampa/Soluciones_Moviles_II_SITRA-Luz_Anampa_Salas/issues/36) | Autorización por roles | Walter | Walter |
| RNF-012 | [#37](https://github.com/David-Anampa/Soluciones_Moviles_II_SITRA-Luz_Anampa_Salas/issues/37) | Seguridad de credenciales | David | David |
| RNF-005 | [#38](https://github.com/David-Anampa/Soluciones_Moviles_II_SITRA-Luz_Anampa_Salas/issues/38) | Interfaz táctil móvil | David | David |

Solo se asignan los colaboradores autorizados David-Anampa y Wsalas651.
La asignación de seguimiento de TT-01/02 a David no sustituye la autoría de Bruno.
MSSQL, NoSQL y Firebase se preservan como antecedentes del diseño inicial; no se
recrean ni se presentan como infraestructura actual de la aplicación Supabase.

Las ocho tareas se cerraron administrativamente conforme al criterio de entrega
de dailys confirmado por Walter. Cada descripción conserva el estado de la sesión:
TT-01/DT-01 parcialmente listos, TT-02/TT-04 en progreso, TT-03 en pruebas y RNF-005
en revisión. No se inventa fecha de finalización individual. Solo RNF-001/RNF-012,
que figuran listos en Daily 02, tienen Entrega reportada del 18/09. Las fechas
Inicio sprint/Fin sprint expresan la ventana del sprint, no duración individual.

## Relaciones nativas

- RNF-001 (#36) es subtarea de HU-002 (#2).
- RNF-012 (#37) es subtarea de HU-001 (#1).
- TT-02 y TT-04 dependen de TT-01.
- RNF-001, RNF-012 y RNF-005 dependen de TT-03.
- RNF-005 depende de DT-01.
- HU-001 y HU-002 dependen de TT-03 como base técnica de la aplicación.

Se añadieron ocho dependencias a las 68 existentes: **76 dependencias** en total,
además de las dos relaciones padre/subtarea. Las 30 HU conservan su identidad.
El antiguo «HU-23 — Inicio de sesión» de Daily 01 se interpreta como antecedente
de HU-001; no se duplica ni se confunde con HU-023 de stock.

## Calendario del Roadmap

| Sprint | Inicio | Fin | Origen |
|---|---|---|---|
| 01 | 07/09/2026 | 18/09/2026 | Daily 01/02 |
| 02 | 21/09/2026 | 02/10/2026 | Daily 03 |
| 03 | 05/10/2026 | 11/10/2026 | **Estimado**, hueco anterior a Sprint 4 |
| 04 | 12/10/2026 | 18/10/2026 | Daily 04 |
| 05 | 17/10/2026 | 23/10/2026 | Daily 05; conserva solapamiento declarado |
| 06 | 30/10/2026 | 05/11/2026 | Daily 06 |
| 07 | 06/11/2026 | 12/11/2026 | Daily 07; seguimiento Daily 08 el 13/11 |
| 08 | 16/11/2026 | 22/11/2026 | **Estimado**, semana posterior a Daily 08 |

Las fechas estimadas de Sprint 3/8 están en las descripciones y vencimientos de
sus milestones. Sprint 3 sigue sin tareas acreditadas: el hito tiene calendario
estimado, pero no se crean issues ficticias para dibujar una barra. Las cuatro HU
de Sprint 8 tienen etiqueta fechas-estimadas, explicación en el cuerpo y fechas de
planificación en el Project; Entrega reportada permanece vacía.

[Roadmap](https://github.com/users/David-Anampa/projects/1/views/4): inicio = Inicio
sprint, objetivo = Fin sprint, agrupación por Sprint, orden Sprint y Title
ascendente, escala trimestral y títulos acotados. La configuración se guardó para
los colaboradores y se comprobó su persistencia al recargar. Iteration conserva
su calendario de plantilla y no determina las barras del Roadmap.

## Verificación final

API remota: 38 ítems del Project, 34 Done, 3 Backlog y 1 Ready. HU-028 se encontró
en Ready y asignada a Walter durante esta actualización; se preservó ese estado y
esa asignación. Se comprobaron las ocho ramas, hitos, responsables, fechas, campos
de seguimiento, subtareas y total de dependencias. No se modificó código de la
aplicación, Supabase ni main; no se ejecutaron pruebas funcionales.
