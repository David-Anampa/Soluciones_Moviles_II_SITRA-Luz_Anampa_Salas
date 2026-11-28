# Acciones y vínculos de gestión — 27/11/2026

## Alcance

Usuarios, Profesionales, Áreas y Financiamientos (seguros/convenios). Patrón de
botones de Usuarios compartido, color del módulo, sin etiqueta Activo repetida.
Claves de IA reutiliza apariencia; mantiene custodia y rotación independientes.
No se cambian flujos operativos de kits, medicamentos, stock, fichas ni recepción.

## Datos y trazabilidad

Migración incremental `migracion_acciones_gestion_2026_11_27.sql` aplicada.
No ejecutar el setup completo contra la base existente.

RPC de lectura `relaciones_gestion_admin()` entrega a Administración metadatos
para bloquear papeleras; `referencias_gestion_admin(entidad,id)` actualiza los
conteos al abrir detalle/confirmación. No entrega filas clínicas ni pacientes.
Cuenta relaciones por tabla (una fila una vez aunque enlace varios roles), con
cantidades por área de origen/destino/asignación cuando existan. Una operación
puede pertenecer a dos áreas: sus conteos por área no deben sumarse como total.
Las asignaciones de configuración de un usuario/profesional y la cobertura del
financiamiento no equivalen a uso clínico; se conservan en la instantánea auditada.
Las asignaciones a un área sí impiden borrar esa área.

Papelera deshabilitada con tooltip si hay vínculos, motivos de protección o
metadatos no disponibles. Se consulta el desglose desde Ver detalle. Usuarios
conserva su detalle completo y suma el resumen de vínculos, sin quitar permisos
ni acciones de recuperación existentes.

`eliminar_registro_gestion_admin` exige Administrador activo, bloquea registros,
verifica versión y vuelve a contar relaciones. Audita antes de borrar dentro de
la misma transacción. Se preservan todos los eventos administrativos y sus
instantáneas; por sí solos no bloquean borrar un registro sin uso. Los vínculos
a operaciones y auditoría operativa sí lo bloquean.

Cuenta de usuario: solo si nunca inició sesión y carece de vínculos operativos;
no permite autoeliminación ni quitar el último Administrador activo. Elimina la
cuenta de Auth, que elimina su perfil por el FK CASCADE verificado. Toda la
operación está en el servidor; Flutter no recibe credenciales administrativas.
Los objetos Storage del usuario también impiden borrarlo. Un fallo revierte la
operación; no se crea una cuenta a medias ni se borra auditoría.
Referencia de plataforma: [gestión de usuarios de Supabase](https://supabase.com/docs/guides/auth/managing-user-data).

Profesional: fichas y referencias históricas impiden borrar; asignaciones del
catálogo se retiran únicamente durante una eliminación autorizada. Área:
Farmacia/Almacén son esenciales y las referencias, stock, kits, perfiles e
historial impiden borrar. Financiamiento: fichas e historial operativo bloquean.
Un trigger protege también la vía previa de eliminación de catálogos.

## Verificación realizada

- Validación de DDL y ejecución de lecturas en transacción revertida.
- Lectura agregada: 20 registros comprobados, 15 con vínculos y 31 grupos con
  desglose de áreas en la base al revisar (no son totales de pacientes).
- FK de perfiles a Auth ON DELETE CASCADE comprobado.
- No se ejecutó ninguna eliminación, ni se crearon usuarios o datos de prueba.
- `flutter analyze --no-pub`: sin observaciones. Contrato remoto de 20 registros y permisos RPC verificados por lectura. La aceptación visual y funcional es del usuario.

## Revisión manual pendiente

1. Administración: abrir Usuarios, Profesionales, Áreas y Financiamientos;
   comprobar iconos, color, espacios y estado sin etiqueta repetida.
2. Ojo: comprobar cantidades y áreas contra datos conocidos, sin filas clínicas.
3. Registro con vínculos: papelera gris y motivo; intentar desactivar conserva historial.
4. Registro de prueba nunca utilizado y acordado: modal muestra cero vínculos,
   cancelar no cambia nada; confirmar elimina y deja instantánea en auditoría.
5. Para usuarios, verificar cuenta propia/último admin/inicio de sesión bloqueados.
6. Cambiar un registro desde otra sesión antes de confirmar: versión nueva impide
   borrar datos distintos de los revisados. No marcar historias completas sin resultados.


## Auditoría explícita de eliminación

La migración `migracion_auditoria_eliminacion_detallada_2026_11_27.sql` amplía
el evento GESTION_ELIMINAR sin borrar ni reescribir eventos anteriores.
`descripcion` identifica por nombre al administrador, la acción «eliminó», el
tipo/nombre/UUID del registro, cantidad de vínculos operativos, nombres de áreas,
cantidades de configuración (asignaciones/cobertura) y auditoría previa conservada.
`detalles_extra` conserva esos datos estructurados, incluida identidad del actor
al momento de actuar, para que renombrar después no cambie quién ejecutó la acción.
La fecha/hora sigue en `fecha` y el estado previo en `estado_anterior`.

Con las reglas actuales, toda eliminación autorizada tiene cero vínculos
operativos: si existen movimientos se bloquea. Puede haber asignaciones de áreas,
cobertura y auditoría administrativa previas; sus cantidades y ubicaciones se
registran por separado. No confundirlas con movimientos clínicos ni habilitar
el borrado de estos para obtener un conteo mayor. No se ejecutaron eliminaciones
para validar esta ampliación.
