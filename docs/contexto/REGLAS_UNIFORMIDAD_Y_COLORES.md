# Uniformidad visual y colores de SITRA-Luz

Acuerdos del usuario consolidados el **24/11/2026**. Consultar antes de cualquier
cambio de interfaz. Este documento registra el diseño que debe conservarse;
no certifica que todas las pantallas heredadas ya lo cumplan.

## Colores por módulo

| Módulo | Color principal | Aplicación |
| --- | --- | --- |
| Farmacia | Verde `#00796B` | Cabeceras, botones, iconos y selección de filtros; fondos verdes pastel. |
| Enfermería | Rojo `#C62828` | Sus vistas y la consulta/gestión compartida de kits. |
| Almacén | Naranja `#E65100` | Identidad de Almacén; misma estructura visual que Farmacia. |
| Jefatura de Farmacia | Azul `#1A3A6B` | Identidad de supervisión. |
| Administración | Rojo `#C62828` | Menú y gestión administrativa acordados con el usuario. |

Usar tonos suaves derivados del principal para fondos, y tonos oscuros legibles
para iconos/textos sobre pastel. Las cabeceras de color usan letras e iconos
blancos. Las tarjetas de contenido conservan fondo blanco y bordes suaves.

**Deuda heredada:** `AppColors.adminColor` todavía declara morado y
`AppColors.primary`/el fallback de `TemaPedidos.colorRol` son azules. No tomar esos
fallbacks como una nueva decisión del usuario para Administración o Farmacia.
No cambiar toda la paleta global indiscriminadamente para corregir una pantalla.

## Módulo visual y permisos son cosas diferentes

- Entrar a Farmacia desde Administración debe mostrar verde aunque la identidad
  autenticada siga siendo ADMINISTRADOR.
- En componentes compartidos, la apariencia sigue el módulo desde el que se
  accede: kits verde para Farmacia y rojo para Enfermería. No crear copias de los
  kits ni de sus datos por el color.
- `TemaPedidos.rolActual(context)` resuelve el ámbito **visual** mediante la ruta
  del módulo y el origen de kits (`/kits?vista=FARMACIA` o `ENFERMERIA`), con la
  sesión como fallback. Nunca usarlo para habilitar permisos o filtrar datos.
- Los permisos reales siguen usando AuthViewModel/contexto del servidor y SQL.
- Revisar también las rutas hijas, ventanas de confirmación, filtros y estados
  de carga; cambiar solo la cabecera no completa la uniformidad.

## Excepción del detalle clínico

La vista general **Atender pedidos de áreas** pertenece a Farmacia y usa verde.
El código y la identificación del área pueden conservar su color propio.
Al abrir **Revisar pedido**, el fondo suave y la cabecera identifican el área
solicitante, manteniendo las tarjetas blancas. No extender el color de esa área
al listado general de Farmacia.

**Nueva ficha (27/11):** el formulario completo, sus iconos de campos y los
selectores de productos/kits usan el color del módulo que registra, nunca el
tema del área seleccionada. Técnico/Enfermería lo ve rojo; Farmacia verde. El
selector Otras áreas / Neonatología son dos pestañas anchas con icono, nombre y
selección marcada; solo se apilan con ancho muy reducido o texto ampliado. Las
opciones sin área autorizada siguen deshabilitadas. No usar un control vertical
estrecho ni reducir la letra para hacerlas caber. El helper de pedidos resuelve
Administración explícitamente en rojo; el fallback azul no define ese módulo.

Rojo de error, anulación y advertencia justificada es semántico: no sustituirlo
por verde solo para teñir toda la pantalla. Urgencia debe seguir siendo visible.

## Componentes y tipografía

- Reutilizar `TemaPedidos`, `CabeceraMenu`/`FranjaPedidos`, `BotonModulo`,
  `CuadriculaPanel`, `DisenoAdaptable` y componentes de stock existentes.
- Separar secciones con **franja horizontal**, color del módulo, icono y texto
  blanco, esquinas redondeadas y separación vertical. Evitar subtítulos sueltos.
- Menús en dos columnas cuando el ancho lo permite: tarjeta pastel, borde blanco,
  círculo blanco para el icono y nombre comprensible. En Farmacia, icono verde
  oscuro. No añadir descripciones ni etiquetas redundantes como «Abrir módulo».
- Conservar la tipografía y el tamaño ya usados; botones y cuerpo alrededor de
  14 px, franjas alrededor de 15 px según el componente existente. No reducir
  letras para resolver desbordamientos ni bloquear la escala de texto de Android.
- Botones con iconos adecuados, etiquetas breves, área táctil mínima de 48 px y
  separación suficiente. Separar **Revisar pedido** de los resúmenes de cantidades.
- **Acuerdo vigente:** agregar productos y aumentar cantidades usan el color
  del módulo con el «+» blanco, verde en Farmacia. Esto sustituye la solicitud
  anterior de pintarlos rojos.
- Quitar referencias HU/RF y explicaciones de implementación de los textos de
  interfaz. Conservar instrucciones necesarias para cantidades, faltantes,
  cobertura, diferencias y justificaciones.

## Campos y adaptación a celulares

- Dar ancho y alto acordes al dato: nombres, médicos, receptores y laboratorios
  largos deben poder leerse; diagnóstico y observaciones admiten varias líneas.
- Campos en una columna en teléfonos estrechos y con letra ampliada. Agregar
  columnas solo si cada campo mantiene espacio suficiente.
- Dropdowns con estilos del módulo, contenido expandido y valores válidos. No
  seleccionar un área antes de que exista en sus opciones; sincronizar el estado
  del campo al cargar catálogo, cambiar filtros o restablecerlos.
- Detalles largos deben desplazarse verticalmente. Nunca ocultar las franjas
  amarillas/negras de overflow recortando contenido o reduciendo tipografía.
- Evitar que botones flotantes tapen el último registro o las acciones.

## Comportamientos de presentación conservados

- Solicitar a Almacén: tres resultados por página, búsqueda en todo el catálogo
  cargado, anterior/siguiente y filtro de laboratorio editable con sugerencias.
  Los productos seleccionados y sus cantidades se conservan al buscar.
- Registro clínico: Neonatología / Otras áreas, usando el catálogo autorizado;
  Otras áreas muestra su dropdown. No crear áreas ni alterar permisos para el UI.
- Registrar pedido se presenta como botón flotante, con el permiso existente.
- El nombre del botón del menú coincide con el título de su vista principal.
  Los subflujos pueden tener títulos específicos que describan su acción.
- Leer una notificación no atiende un pedido. La bandeja de prueba y el flujo
  operativo son distintos; no declarar terminados los avisos automáticos reales.

## Verificación de cada cambio

Acuerdo de profesionales (27/11): solo Administración crea, edita y activa o
desactiva desde **Gestionar profesionales**, con la paleta roja administrativa.
Nombre completo, colegio/institución, número único dentro de ese colegio y áreas
múltiples. El UUID es interno; Enfermería/Farmacia buscan por nombre, seleccionan
los activos del área y no dan altas desde la ficha. Las siglas compartidas COP
no identifican por sí solas a una institución. Ver
[guía del catálogo](../supabase/GUIA_PROFESIONALES_ADMIN_2026_11_27.md).

Revisar consistencia entre inicio, destino, filtros seleccionados/no seleccionados,
modales, carga y error; considerar Farmacia abierta desde Administración y kits
desde Enfermería. Ejecutar `flutter analyze --no-pub` desde `app`. No afirmar
aceptación visual o funcional si no se observó: el usuario realiza esas pruebas.
No modificar stock, auditoría ni permisos como parte de un retoque visual.
Agrupar cambios importantes en commits y mantener este acuerdo actualizado.

## Menú de Jefatura aplicado — 27/11/2026

Se reutilizan las tarjetas en dos columnas, azul pastel, círculo blanco e icono
azul oscuro. Dos franjas azules con texto blanco separan Consultas de supervisión
y Historial y auditoría. Accesos reales: Supervisar pedidos, Consultar existencias,
Consultar kits por área, Reportes y diferencias e Ingresos y correcciones.
Se conservan los parámetros `soloLectura` de las vistas de auditoría.

La navegación compartida a `/fichas` y `/kits` conserva el ámbito visual mediante
`vista=JEFATURA_FARMACIA`, también si Administración abre el módulo. No otorga
permisos. La cabecera principal permite color de módulo explícito.

Se retiraron del inicio los indicadores numéricos fijos, la alerta de un lote de
ejemplo y los accesos que solo mostraban un snackbar, sin una pantalla real. Eso
no implementa ni cierra reportes de consumo, aprobaciones especiales o indicadores
reales de HU-028: siguen pendientes de su desarrollo y validación respectivos.
Comprobación de esta entrega: `flutter analyze --no-pub`; pruebas funcionales y
aceptación visual a cargo del usuario.


## Selectores de Nueva ficha — acuerdo del 27/11/2026

- Todos los selectores conservan tema, iconos y borde del módulo abierto.
- Hasta cuatro opciones: menú blanco, esquinas redondeadas y selección del color del módulo.
- Más de cuatro: diálogo con buscador por nombre, sin distinguir tildes, mayúsculas ni espacios; texto multilínea, desplazamiento y teclado adaptables. Profesional a cargo mantiene su buscador por nombre.
- Reutilizar `SelectorCatalogo`; mantener las opciones autorizadas y los identificadores reales.
- Procedencia del paciente es un catálogo compartido, independiente de las áreas clínicas y sus permisos. «Otra procedencia…» permite guardarla para siguientes usuarios; Supabase reutiliza el nombre canónico y audita las nuevas altas. No prometer detección de sinónimos ni errores ortográficos.


## Regla general: combobox y checkbox — 27/11/2026

Se aplica a todas las interfaces nuevas o modificadas, incluidos crear/editar y
sus modales; amplía el acuerdo previo de selectores de Nueva ficha.

- Combobox: reutilizar `SelectorCatalogo`, campos blancos con borde redondeado,
  iconos y selección del color del módulo; nombres largos sin recortar.
  Más de cuatro opciones abre búsqueda. Conservar validadores y estado del formulario.
- Checkbox: reutilizar `OpcionMultiple` para listas de opciones. Tarjeta blanca,
  borde suave, separación de 10 px; seleccionada con fondo pastel del módulo.
  Casilla redondeada del color del módulo y marca blanca; toda la fila pulsable,
  texto de 14 px con varias líneas, objetivo táctil mínimo de 48 px.
  El tema compartido `TemaPedidos` define estados marcado, deshabilitado y error.
- En Profesionales se aplica al filtro Estado, colegio y áreas de atención.
  La ampliación aprobada a continuación migra también los controles heredados
  identificados. La aceptación visual sigue a cargo del usuario.


## Unificación aprobada y aplicada — 27/11/2026

El usuario confirmó extender los estilos a los controles existentes, con pastel
según módulo, manteniendo fluidez, datos y comportamiento.

- Todos los `DropdownButtonFormField<String>` identificados pasan a
  `SelectorCatalogo`: Usuarios, catálogos administrativos, formularios de medicamentos,
  ingresos/correcciones, diferencias, transferencias, Kardex, listados/detalle de
  fichas y selectores/formularios de kits. Profesionales y Nueva ficha ya lo usaban.
- Hasta cuatro opciones: menú blanco redondeado. Más de cuatro: modal con franja,
  búsqueda por nombre, selección pastel y marca. Buscar filtra todas las opciones
  recibidas; se presentan hasta 30 filas, ampliables. No equivale a búsqueda remota
  en tablas que la pantalla original no hubiera cargado.
- Laboratorio en Solicitar a Almacén conserva búsqueda y sugerencias en el propio
  campo, fondo blanco, bordes redondeados y color del módulo: es un filtro editable.
- Checkbox de permisos y áreas de usuarios, cobertura de medicamentos y copias de
  kits usan `OpcionMultiple`. Selecciones: tarjeta blanca/pastel. Confirmaciones de
  kits: recuadro suave incluso sin marcar, manteniendo la advertencia y el texto.
- Áreas de Profesionales siguen visibles (cinco); áreas de Usuarios conservan su
  modal con búsqueda, contador y confirmación. Filtrar no borra selecciones.
- Ambos componentes resuelven el módulo visual con `TemaPedidos`; el pastel no
  depende de colores rojos/azules fijos ni cambia el rol que concede permisos.
- Conservar opciones nulas como «Todos los lotes», validación obligatoria,
  callbacks originales y estados deshabilitados. No hay migración SQL para esto.
- Verificación: análisis estático Flutter; revisión visual y funcional con el
  usuario pendiente. No cerrar historias por la unificación visual.


## Refinamiento de selección — 27/11/2026

Sustituye los contornos marcados de las tarjetas de selección anteriores:
- Fondo pastel del módulo cubriendo toda la opción seleccionada, sin contorno.
- Esquinas discretas de 8 px en opciones de menú, resultados y tarjetas checkbox.
- Campo combobox seleccionado también en pastel, sin borde en reposo; conserva
  borde de foco fino y errores visibles. No cambiar tipografía ni área táctil.
- Mantener la casilla y marca como señal adicional al color.
- Aplicado en los dos componentes compartidos; los colores se derivan del módulo.


## Acciones de gestión — acuerdo del 27/11/2026

El usuario eligió el patrón de **Usuarios**, sustituyendo la propuesta de botones
Editar sólidos: acciones de icono en blanco/pastel, borde discreto, redondez de
8 px, objetivo táctil de 48 px y tooltip. `AccionGestion` deriva su color del
módulo abierto. No usar el color decorativo de la tarjeta para estas acciones.

- Ver detalle (ojo), Editar (lápiz) y Eliminar (papelera) en la misma fila.
- Activar/desactivar junto al nombre: check/bloqueo, pastel del módulo cuando
  está activo. Quitar etiquetas Activo/Inactivo repetidas, sin ocultar el estado.
- Papelera gris deshabilitada si existen vínculos protegidos o falta información.
  Ver detalle explica el bloqueo y muestra **cantidades por tipo y por área**;
  nunca listas de fichas ni pacientes. Una operación puede intervenir en dos áreas.
- Eliminación con modal adaptado al módulo, conteos actuales, Cancelar y Eliminar.
  El servidor vuelve a comprobar vínculos, permiso y versión antes de escribir.
- Usuarios: nueva excepción autorizada, puede eliminarse una cuenta nunca usada,
  sin inicio de sesión ni vínculos operativos; nunca la propia ni el último admin.
  Se elimina cuenta y perfil en la misma transacción y se conserva auditoría.
- Auditoría administrativa de creación/edición se conserva como instantánea y no
  cuenta por sí sola como uso clínico. Auditoría operativa y referencias sí bloquean.
- Aplicado a Usuarios, Profesionales, Áreas, Seguros y Convenios. Claves de IA usa
  los mismos botones; su borrado/rotación sigue su flujo seguro específico.
- Kits y medicamentos tienen gestiones operativas propias (variantes, ítems,
  stock, borradores); no añadirles borrado de registros clínicos por analogía.
  Este acuerdo no certifica una revisión visual completa de esas pantallas.
