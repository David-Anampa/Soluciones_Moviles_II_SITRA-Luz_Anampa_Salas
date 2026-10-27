# Asignación de áreas según rol — 27/10/2026

## Regla confirmada

| Rol | Asignación |
| --- | --- |
| Almacén | Solo `ALMACEN`; asignación fija. |
| Farmacia | Solo `FARMACIA`; asignación fija. |
| Jefatura de Farmacia | `FARMACIA`; sus permisos de supervisión dependen del rol. |
| Administrador | Sin asignaciones físicas; acceso global por rol. |
| Enfermería / Técnico | Selector múltiple de áreas clínicas; puede tener más de dos. |

El selector de Enfermería excluye Farmacia, Almacén y Jefatura por código o nombre. Mantiene las asignaciones históricas a áreas clínicas deshabilitadas para poder consultarlas o retirarlas; no ofrece nuevas asignaciones a esas áreas.

El permiso **Puede gestionar kits** sigue requiriendo rol Enfermería/Técnico, cargo elegible y al menos un área. Las áreas no convierten al usuario en administrador ni conceden otro rol.

## Interfaz y perfiles anteriores

En Crear/Editar usuario solo Enfermería tiene buscador y selección múltiple. Los otros roles muestran una nota con su asignación fija o alcance global. Al cambiar de rol se ajusta únicamente el borrador del formulario.

Cuando un perfil anterior tiene asignaciones incompatibles, el formulario avisa que se ajustarán al guardar. Abrir o cancelar no cambia la base. La migración tampoco actualiza perfiles existentes en masa.

## Migración

Ejecutar `migracion_areas_por_rol_2026_10_27.sql` después de `migracion_nombre_usuario_mayusculas_2026_10_27.sql`. No volver a ejecutar la anterior después, porque reemplaza la misma función de validación. El setup contiene las reglas finales para reconstrucciones.

La migración actualiza `hu021_normalizar_perfil`, compartida por el alta y la edición. Conserva nombre de usuario, unicidad, colegiatura y resolución de códigos; rechaza áreas incompatibles con el rol. No introduce nuevas tablas ni nuevas funciones públicas. No se ejecutó esta migración remota durante la entrega.

## Verificación

Se aprobaron 7 pruebas locales: reconocimiento de áreas reservadas, formulario/guardado para los cinco roles y permiso de Kits condicionado al cargo. Usan repositorios simulados; no certifican el SQL instalado.

Después de aplicar la migración, comprobar como Administrador:

1. Editar un usuario Almacén: debe mostrar únicamente Almacén y no permitir agregar SOP.
2. Farmacia y Jefatura: mostrar Farmacia fija. Administrador: indicar acceso global.
3. Enfermería: mostrar SOP, Emergencia, UCI y las demás áreas clínicas; ocultar las reservadas.
4. Asignar tres áreas clínicas, guardar y reabrir: conservar las tres.
5. Cambiar de Enfermería a Almacén: avisar del ajuste; guardar y comprobar que queda solo Almacén.
6. Cancelar la edición: conservar las asignaciones anteriores.
7. Una petición de alta/edición con rol Almacén y varias áreas debe rechazarse también en el servidor.
