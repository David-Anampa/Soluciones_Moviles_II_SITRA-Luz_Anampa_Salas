# Profesionales a cargo — gestión administrativa

Acuerdo del 27/11/2026: se busca por **nombre**, con UUID interno y unicidad de
colegio/institución + número. No se crean usuarios ni permisos clínicos nuevos.

## Acceso y campos

Administración → **Gestionar profesionales** (`/admin/profesionales`). Diseño rojo
con franjas, tarjetas, iconos, campos amplios y editor desplazable. Permite crear,
editar y activar/desactivar (sin borrar las fichas históricas).

- Nombre completo, colegio, número de colegiatura y una o varias áreas activas.
- Búsqueda por nombre/colegiatura y filtro activo/inactivo. El UUID no se pide
  ni se muestra como identificador que deba conocer el personal.
- Lista de colegios existentes; Administración puede añadir otro nombre oficial
  y sigla. El formulario no valida habilitación profesional contra una web externa.
- Un colegio/número ya registrado no puede volver a crearse, aunque el registro
  esté inactivo. El nombre no es único: no confundir homónimos con duplicados.
- La clave normaliza mayúsculas, separadores, ceros iniciales en números y los
  prefijos conocidos CMP/CTMP/COP/CEP/CQFP. El número visible conserva su formato.
- Las siglas no son la identidad de la institución: Odontología y Obstetras
  comparten COP, pero tienen códigos internos diferentes y no colisionan.
- Se conserva la especialidad de registros anteriores; no se inventan valores.

Fuentes de nombres: [Colegio Médico del Perú](https://conoceatumedico.cmp.org.pe/),
[Tecnólogos Médicos](https://ctmperu.org.pe/),
[Odontológico](https://www.cop.org.pe/),
[Obstetras](https://colegiodeobstetras.pe/). No se añadió un colegio «CGOP»:
ginecología/obstetricia médica no se trata como un colegio profesional separado.

## Integración con HU-003

Nueva ficha ofrece **Profesional a cargo**, con búsqueda por nombre, información
de colegiatura y especialidad existente. Solo muestra registros activos asignados
al área solicitante. Al cambiar área se retira una selección incompatible.
Enfermería/Farmacia no pueden dar de alta ni editar el catálogo desde ese selector.

La pertenencia al área se valida también al guardar en SQL; no depende solo del
filtro del teléfono. El nombre guardado en fichas previas no se reescribe al editar
el catálogo. Un cambio de áreas tampoco reasigna fichas históricas.

## Base de datos y auditoría

Migración incremental: `migracion_profesionales_admin_2026_11_27.sql`, aplicada en
`nedeqnvpkalrchswrapr`. Añade campos a `doctores`, relación `doctor_areas`, sigla
de colegio e índice único por institución/número normalizado. Amplía el contexto
HU-003 sin sustituir las correcciones de receptor y stock. Se incluyó al final del
setup para bases nuevas; **no ejecutar el setup completo sobre la base actual**.

Escrituras exclusivamente por RPC administrativa, comprobando perfil/rol activo.
Las operaciones de profesional y áreas se guardan en la misma transacción y
registran actor, fecha, antes/después y áreas en `auditoria_trazabilidad`.
La versión `updated_at` evita sobrescribir una edición concurrente. Se conserva
el UUID durante un reintento idéntico de creación. Un timeout no se interpreta
como rollback: revisar/actualizar la lista antes de repetir la operación.

## Registros anteriores y comprobaciones

Había **cuatro profesionales**: se conservaron sin asignarles colegios ni áreas
inventados. Aparecen con un aviso para completar datos. **Antes de continuar
P003-1**, Administración debe editar el profesional de prueba, confirmar su
colegiatura y asignarle el área; luego actualizar el catálogo de Nueva ficha.
No se borraron, fusionaron ni desactivaron los registros anteriores.

Verificado: compilación de la migración en transacción revertida, aplicación
incremental, lectura de RPC administrativa, ampliación del contexto, conservación
de cuatro registros, índice/normalización y ausencia de escritura directa de
authenticated en doctores/áreas. `flutter analyze --no-pub` sin observaciones.
Sin altas/ediciones de personas ni fichas de prueba ejecutadas por el agente.

Pruebas manuales pendientes del usuario:

1. Administración crea/edita un profesional y le asigna dos áreas.
2. Intentar el mismo colegio/número con diferencias de formato: debe bloquearse;
   otro colegio puede usar el mismo número porque representa otra matrícula.
3. Enfermería de cada área lo encuentra por nombre; un área no asignada no lo ofrece.
4. Desactivar: deja de ofrecerse en nuevas fichas; historial anterior consultable.
5. Dos administradores editando la misma versión: el segundo debe actualizar.
6. Acceso de Farmacia/Enfermería al módulo/RPC administrativo: denegado.

Esto amplía el criterio de catálogo de HU-003; no crea otra HU ni acredita por sí
solo el cierre de la historia. La revisión visual y funcional sigue con el usuario.


## Ajuste de áreas del formulario (27/11/2026)

En alta y edición solo se ofrecen Hospitalización, Sala de Operaciones,
Emergencias, Neonatología y Coche de Paros. Almacén y Farmacia no son opciones
de atención del profesional. Se conservan nombres/códigos del catálogo,
estilos rojos de Administración y selección múltiple.
El filtro se aplica al formulario, incluidas sus selecciones iniciales: guardar
una edición conserva únicamente las áreas asistenciales seleccionadas.
No hay limpieza masiva de asignaciones, cambios al catálogo general ni migración
necesaria para este ajuste de presentación. Las pruebas manuales siguen pendientes.


## Uniformidad de controles (27/11/2026)

Filtro Estado y colegio usan `SelectorCatalogo`: menú hasta cuatro opciones,
buscador con más de cuatro; conserva la validación obligatoria del colegio.
Áreas usa `OpcionMultiple`: tarjetas pulsables con casillas redondeadas, marca
blanca y rojo/pastel administrativos. El tema compartido define los estados.
La instrucción general se guarda en AGENTS.md y reglas de uniformidad.
Análisis estático requerido; aceptación visual y pruebas manuales con el usuario.
