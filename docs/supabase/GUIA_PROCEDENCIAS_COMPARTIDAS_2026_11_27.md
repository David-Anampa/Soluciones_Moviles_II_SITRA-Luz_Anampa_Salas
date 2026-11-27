# HU-003 — selectores y procedencias compartidas

Actualizado el 27/11/2026. Rama Sprint-08. Revisión manual pendiente.

## Implementación

Nueva ficha utiliza `SelectorCatalogo` en área, turno, prioridad, tipo de parto,
procedencia, tipo de atención, financiamiento y receptor. Menú hasta cuatro opciones;
con más de cuatro abre diálogo de búsqueda sobre todas las opciones recibidas,
con carga visual de 30 filas ampliable. El profesional conserva su buscador por nombre.
Tema según módulo (Enfermería/Técnico rojo; Farmacia verde), tipografía legible,
texto multilínea, iconos y selección coherentes. No cambian opciones ni permisos.

## Persistencia y seguridad

Migración incremental `migracion_procedencias_compartidas_2026_11_27.sql`
aplicada en Supabase y añadida al setup para instalaciones nuevas.
No ejecutar el setup completo contra producción.

`procedencias_paciente` mantiene código, nombre canónico, identidad normalizada
única, autor, fecha y estado. Inicialmente Emergencia y Hospitalización.
No se importan automáticamente textos históricos de Otro.
`registrar_procedencia_ficha(text)` solo admite perfiles activos de Administración,
Farmacia o Enfermería. Sin acceso directo de escritura desde el cliente. Ignora
mayúsculas, tildes y separadores al comparar; bloqueo transaccional más restricción
única evitan duplicados concurrentes. No identifica sinónimos ni faltas ortográficas.
Las nuevas altas generan `PROCEDENCIA_CREAR` en auditoría.

Seleccionar Otra procedencia…, escribir de 2 a 120 caracteres y pulsar Guardar
procedencia. Si ya existe se selecciona su nombre canónico; si es nueva queda
compartida incluso si luego se cancela la ficha. El guardado final de una ficha con
Otro también la registra/reutiliza mediante trigger en la misma transacción.

Se conserva el contrato histórico de fichas: EMERGENCIA/HOSPITALIZACION/OTRO y
procedencia_detalle. Las opciones nuevas se traducen a OTRO con nombre canónico,
sin cambiar la restricción de fichas ni sus datos previos. No se crea un área ni
se asigna acceso por registrar una procedencia. Los siguientes usuarios ven las
opciones al abrir o actualizar Nueva ficha; no hay suscripción en tiempo real.

## Verificación técnica realizada

- Validación de la migración en transacción revertida antes de aplicarla.
- Lectura remota: contexto devuelve las dos opciones iniciales, normalización de
  Hospitalización correcta, trigger activo, RPC habilitada para authenticated,
  escritura directa y ejecución anónima bloqueadas.
- Sin crear pacientes, fichas ni procedencias de prueba, ni alterar stock.
- `flutter analyze --no-pub`: sin observaciones (27/11/2026).

## Comprobación manual con el usuario (no ejecutada)

- Enfermería/Técnico: abrir Nueva ficha General; comprobar rojo, espacios y
  selecciones; Farmacia: repetir desde su módulo y comprobar verde.
- Con cuatro opciones debe haber menú; con cinco, buscador. Probar búsqueda,
  selección, cancelación, teclado y nombres largos. Repetir en Neonatología.
- Crear una procedencia de prueba acordada; con otra sesión abrir/actualizar el
  formulario y verificar que aparece. Intentar la misma con tildes, mayúsculas o
  espacios distintos: reutilización sin segunda alta.
- Guardar y volver a consultar una ficha General con esa procedencia; comprobar
  nombre canónico e historial. Las áreas autorizadas no deben cambiar.
- Verificar auditoría del alta con Jefatura/Administración. Estos pasos no cierran
  HU-003 hasta registrar el resultado real.
