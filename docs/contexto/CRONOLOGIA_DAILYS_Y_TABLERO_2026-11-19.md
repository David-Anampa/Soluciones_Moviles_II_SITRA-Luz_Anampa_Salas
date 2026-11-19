# Cronología de dailys y organización del Project

Fuentes proporcionadas por Walter el 19/11/2026: `G04-INFORME-DAILY01.md`,
`DAILY02.md`, `DAILY03.md` y `G04-INFORME-DAILY04.docx.md` a
`G04-INFORME-DAILY08.docx.md`, en Descargas de su computadora. Se resume su
contenido operativo; no se copian matrículas ni imágenes base64 a los issues.

Project objetivo: https://github.com/users/David-Anampa/projects/1

## Criterio de lectura confirmado por el usuario

El 19/11 Walter indicó que la entrega de los dailys acredita el trabajo realizado
de esa entrega. Por tanto, se toma esa confirmación para el desarrollo reportado,
aunque algunas tablas conserven redacción de plantilla («objetivo previsto»,
«proyección»). Conservar por separado los pendientes/impedimentos explícitos y las
observaciones técnicas detectadas después; no inventar resultados de pruebas o
aceptaciones de Jefatura que el informe señala pendientes.

La entrega histórica y la revisión técnica posterior son dos datos distintos.
Si se registra una historia como entregada según daily, su descripción debe
mostrar también las observaciones actuales y el seguimiento correctivo necesario.
No reescribir la autoría ni la fecha de los commits para hacerlas coincidir con
el informe académico.

## Relación de entregas

| Daily | Sprint declarado | Ventana declarada | Fecha de sesión/entrega | Trabajo y estado reportado |
|---|---|---|---|---|
| 01 | 1 | 07/09–18/09/2026 | 11/09/2026 | Base técnica/MVVM/CI y diseños; entregas parciales, contrato API y documentación en curso. |
| 02 | 1 | 07/09–18/09/2026 | 18/09/2026 | HU-001 login; HU-002/RNF-001 roles; seguridad RNF-012; ajustes móviles RNF-005. |
| 03 | 2 | 21/09–02/10/2026 | 25/09/2026 | HU-013 catálogo, stock inicial HU-023, HU-016 edición; escaneo offline HU-014 parte 1; abastecimiento HU-029/HU-030 en revisión. |
| 04 | 4 | 12/10–18/10/2026 | 16/10/2026 | HU-012 y HU-020/HU-021/HU-022; estructura y funcionalidad de usuarios repartidas. |
| 05 | 5 | 17/10–23/10/2026 | 23/10/2026 | HU-017/HU-018/HU-019, HU-023/HU-024 y ajustes/validación de HU-029/HU-030. |
| 06 | 6 | 30/10–05/11/2026 | 05/11/2026 | HU-003/HU-004/HU-005 y HU-014/HU-015; aplicar el reparto corregido por Walter del 19/11. |
| 07 | 7 | 06/11–12/11/2026 | 12/11/2026 | HU-006 a HU-011 y refinamiento del contrato de Kardex HU-025. |
| 08 | 7 | 09/11–13/11/2026 | 13/11/2026 | Ajustes de botones, filtros, navegación y fluidez de HU-006 a HU-011; recorrido Q/A reportado por David; aceptación de Jefatura pendiente. |

No se recibió un daily específico de Sprint 3 ni una entrega de Sprint 8. No
inventar esos reportes. En Sprint 1 hay dos registros; en Sprint 7 también hay dos.
Los documentos proporcionados no sustentan una regla universal de dos dailys por
semana. Se conserva un registro por cada informe real recibido.

## Desfases documentales que deben quedar visibles

- Daily 01 llama «HU-23» al inicio de sesión: reconciliar por título/alcance con
  **HU-001 actual**, no confundir con **HU-023 de stock**.
- Daily 01–03 pertenecen al repositorio y Project iniciales de Bruno. Se preservan
  como antecedente de la aplicación actual y no se duplican sus historias por
  haber cambiado de repositorio/equipo.
- El objetivo de Daily 05 repite el de administración de Daily 04, pero su tabla
  de trabajo corresponde a kits/inventario. Para el alcance usar esa tabla, no
  asignar nuevamente HU-012/HU-020 a Sprint 5 por el encabezado repetido.
- Las ventanas de Sprint 4/5 se solapan. Se conservan como declaradas en los
  documentos; no se alteran fechas silenciosamente. Un campo de selección de
  sprint más sus fechas declaradas puede representar esto sin inventar iteraciones
  nuevas o cambiar calendarios existentes.
- Daily 06 tiene el reparto invertido frente a la corrección directa de Walter:
  **David realizó OCR/IA HU-014/HU-015; Walter el resto del Sprint 6, incluidas
  HU-003/HU-004/HU-005 e integración ajena a IA.** Esa confirmación prevalece.
- Daily 08 dice jueves 13/11/2026; la fecha numérica corresponde a viernes.
  Conservar **13/11/2026** como fecha declarada, anotando el error de día de semana.
- El ajuste de interfaz reportado el 13/11 continúa Sprint 7 aunque Daily 07
  situara su cierre el 12/11. Registrar ese seguimiento, sin convertir Daily 08
  en una entrega del Sprint 8.
- Las referencias posteriores de archivos/commits del 26/10 o 06/11 pueden ser
  integración/corrección posterior a la entrega académica. Mostrar ambos hitos.

## Responsables del Project actual

Solo `@David-Anampa` y `@Wsalas651` se asignan a tarjetas del tablero actual.

| Sprint | Walter (`@Wsalas651`) | David (`@David-Anampa`) |
|---|---|---|
| 1 | HU-002; estructura MVVM/CI según Daily 01. | Validación de seguridad y adaptación móvil según Daily 02. |
| 2 | Escaneo GTIN offline inicial (parte 1 de HU-014). | HU-016 y abastecimiento inicial HU-029/HU-030. |
| 4 | HU-012 y estructura/columnas de HU-020. | Funcionalidad de HU-020, HU-021 y HU-022. |
| 5 | HU-023, HU-024 y ajuste HU-029; validación compartida de HU-030. | HU-017/HU-018/HU-019; validación compartida de HU-030. |
| 6 | HU-003/HU-004/HU-005 e integración ajena a IA. | HU-014/HU-015, OCR/IA y revisión de resultados. |
| 7 | HU-008/HU-009/HU-010/HU-011; mejoras posteriores del flujo. | HU-006/HU-007, interfaz/Q/A y contrato HU-025. |
| 8 | HU-025/HU-028, aún sin entrega acreditada. | HU-026/HU-027, aún sin entrega acreditada. |

Daily 02 atribuye la implementación inicial de HU-001 a Bruno y Daily 03 el
catálogo inicial HU-013 a Bruno. Se preserva esa autoría histórica en la
descripción. Si se asignan responsables actuales entre los dos colaboradores
autorizados, identificarlos como mantenimiento/seguimiento actual, sin adjudicarles
retroactivamente el desarrollo de Bruno. El contrato HU-025 de David en Sprint 7
no sustituye la responsabilidad de Walter por la interfaz de Sprint 8.

## Contenido mínimo de las historias

- Historia con rol, capacidad y beneficio.
- Alcance, reglas y criterios de aceptación verificables.
- Responsable principal, colaboración y subtareas cuando corresponda.
- Sprint de entrega/planificación y etapas anteriores de la misma historia.
- Ventana declarada del sprint y fecha de entrega del daily pertinente.
- Desarrollo reportado, verificación técnica y aceptación funcional separados.
- Dependencias, fuentes, rama/PR/commits y migraciones relevantes.
- Prioridad propuesta y pendientes/observaciones actuales.

Las prioridades se proponen según seguridad, integridad de stock y dependencias.
No se crean estimaciones históricas de puntos ni horas que el equipo no haya
acordado. Las fechas del trabajo se registran como información histórica, sin
alterar la fecha real de creación de un issue.

## Cierre de esta preparación

Se prepararon localmente 30 historias HU-001…HU-030 para conciliar con los ítems
existentes del Project. HU-025…HU-028 permanecen sin entrega reportada del Sprint 8.
La lectura/edición del tablero necesita permiso `project` de GitHub; la credencial
Git existente de `Wsalas651` permite repositorio pero inicialmente no Projects.
No se considera actualizado el tablero hasta ejecutar y verificar los cambios
con una sesión autorizada.
