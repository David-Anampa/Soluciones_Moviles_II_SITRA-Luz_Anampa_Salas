# Kits por área — HU-017, HU-018 y HU-019

Implementación local del 26/10/2026. Pendiente de aplicar la migración y de aceptación funcional por Walter/David. Esta entrega cubre plantillas; no implementa las fichas ni pedidos Área → Farmacia (HU-003 a HU-011).

## Instalación sobre la base existente

1. Tener instaladas las migraciones de HU-012, estructura/gestión de usuarios, correo único, catálogos profesionales/colegiatura y stock en tránsito del 25/10. Son dependencias existentes del proyecto.
2. Ejecutar **solo** `docs/supabase/migracion_kits_por_area_2026_10_26.sql` en SQL Editor. Incluye las definiciones actuales de las RPC de kits y sustituye las del 22/10; no requiere ejecutar primero aquella migración de kits.
3. No volver a ejecutar la migración antigua de kits después de esta: restauraría permisos anteriores. No ejecutar el setup completo sobre la base existente.
4. Reiniciar la aplicación. Si falta una RPC, se mostrará el nombre de esta migración; no se harán escrituras alternativas.

El setup incorpora exactamente el mismo SQL al final para reconstrucciones. El nombre del alta de perfiles utilizado por `crear-usuario` se conserva: **no hace falta volver a desplegar esa Edge Function por este cambio**. La función debe estar previamente desplegada para HU-021.

## Permisos y acceso

| Perfil | Consulta | Gestión |
|---|---|---|
| Administrador activo | Todas las áreas | Todas las áreas |
| Jefatura activa | Todas las áreas | Solo lectura |
| Farmacia activa | Todas las áreas | Solo lectura |
| Enfermería / Técnico activo | Áreas vinculadas a su perfil por `profile_areas` | Solo si tiene cargo habilitado y el permiso adicional |
| Almacén, perfil inactivo o sin sesión | Sin acceso a este módulo | Sin acceso |

En Crear/Editar usuario, el checkbox **Puede gestionar kits** aparece solo para cargos Técnica/Técnico, Técnica/Técnico de Enfermería, Enfermera/Enfermero y Licenciada/Licenciado en Enfermería (ignora tildes y mayúsculas). Solo puede marcarse con rol Enfermería / Técnico; exige al menos un área asignada. Cambiar a otro cargo o rol revoca el permiso. Los perfiles existentes comienzan sin el permiso; Administrador ya tiene gestión por su propio rol.

No se crea un rol nuevo. Jefatura no gana escritura aunque tenga un cargo asistencial. La base valida sesión, perfil activo, permiso y pertenencia del área en cada operación. Las escrituras directas de clientes sobre `kits`/`kit_items` quedan revocadas: se utiliza la RPC atómica.

Accesos: Administración → Kits; Enfermería → Kits de mi área; Jefatura/Farmacia → Consultar kits por área. La ruta compartida es `/kits`; `/admin/kits` conserva su acceso administrativo. El personal con varias áreas elige su área de trabajo en los filtros al entrar; con una sola se preselecciona. La selección es de esa pantalla, no modifica sus asignaciones de perfil.

## Plantillas, variantes y disponibilidad

- Crear un kit personalizado requiere nombre, área autorizada y al menos un componente con cantidad entera positiva. No exige existencias para definir una plantilla.
- Duplicar abre otra plantilla, solicita otro nombre y conserva el área de origen. Se pueden cambiar componentes/cantidades antes de guardar. El original conserva su identidad y composición. La auditoría guarda `KIT_DUPLICADO` e identifica el kit de origen.
- Editar sustituye únicamente los componentes de la plantilla, dentro de una transacción con su cabecera y auditoría. No reescribe `dispensaciones` ni `dispensacion_items`.
- No se asignan plantillas nuevas a áreas deshabilitadas. Una edición puede conservar su área histórica deshabilitada, sin aserciones del selector. Rehabilitar el kit o crear una variante exige habilitar antes el área.
- Eliminar requiere confirmación y se bloquea si tiene dispensaciones asociadas. Habilitar/inhabilitar conserva historial y también mantiene la confirmación de la interfaz de kits.
- Se muestran nombre completo, presentación, laboratorio y cantidades separadas de Farmacia, Almacén y tránsito. Los faltantes en Farmacia se resaltan en rojo pastel con texto que indica cuántas unidades faltan. Almacén no cuenta como disponibilidad inmediata de Farmacia.
- La consulta utiliza las reglas actuales de `consultar_stock_ubicaciones`, incluyendo exclusión de lotes vencidos/deshabilitados y tratamiento de tránsito. El dato corresponde al momento de la consulta; deslizar hacia abajo en Kits vuelve a consultarlo. La búsqueda del selector también consulta el servidor.
- Crear, editar o duplicar kits no reserva ni descuenta stock. La reserva y el consumo pertenecen al futuro flujo Área → Farmacia.

## RPC y mantenimiento

- `contexto_kits_por_area`: rol, áreas autorizadas y capacidad de gestionar; incluye áreas históricas para consulta.
- `listar_kits_hu017`: plantillas y composición con alcance por área.
- `medicamentos_para_kits`: catálogo y disponibilidad, paginados, sin movimientos.
- `administrar_kit_hu018`: guardar/estado/eliminar, validación de permisos, bloqueo y auditoría en una transacción.
- `listar_permisos_kits`: complemento paginado del listado administrativo.
- `administrar_usuario_con_kits`: envuelve la edición vigente y guarda el permiso en la misma transacción; conserva validaciones de colegiatura, último administrador y autoacciones.
- `registrar_perfil_usuario_hu021`: conserva el contrato de la Edge Function y añade el permiso al alta atómica del perfil.
- Helpers de cargo/acceso y trigger de protección: centralizan reglas; no conceden gestión por sí solos. `asignar_permiso_kits` es privado para los clientes.

## Comprobaciones realizadas y pendientes

`flutter analyze --no-pub`: sin observaciones al terminar la implementación. No se ejecutaron pruebas, emulador, capturas ni migraciones remotas en esta entrega. El análisis de Dart no demuestra que el SQL esté instalado ni que los flujos estén aceptados.

Revisión manual por el usuario:

1. Aplicar la migración sin errores. Abrir Kits como Administrador, crear una plantilla y comprobar el desglose de stock/laboratorio.
2. Duplicarla, poner otro nombre y cambiar una cantidad. Confirmar que el original sigue igual. Probar un nombre ya utilizado: debe rechazarse sin crear filas parciales.
3. Editar un usuario con cargo Técnica/Enfermera, rol Enfermería y dos áreas. Marcar el permiso, guardar y reabrir para comprobar su persistencia.
4. Entrar con ese usuario y seleccionar área de trabajo; comprobar que no accede a kits de áreas no asignadas. Sin el checkbox debe consultar sin acciones de escritura.
5. Como Jefatura/Farmacia, comprobar lectura sin crear/editar/duplicar/eliminar. Intentos de escritura por API deben ser rechazados también.
6. Deshabilitar un área y comprobar que sus kits siguen consultables; se puede conservar esa asignación en una edición, pero no crear/duplicar hacia ella ni habilitar un kit allí.
7. Cambiar el cargo/rol a otro no elegible y comprobar la revocación. Un perfil deshabilitado no debe poder operar.
8. Abrir un kit con faltantes: verificar cantidades por ubicación. Guardar la plantilla no debe cambiar stock. Cancelar una confirmación no debe modificar datos.
9. Si existe un kit usado por una dispensación, intentar eliminarlo: debe bloquearse; editar la plantilla no debe cambiar los ítems históricos de la ficha.

Estas comprobaciones son instrucciones pendientes, no resultados de pruebas ejecutadas.
