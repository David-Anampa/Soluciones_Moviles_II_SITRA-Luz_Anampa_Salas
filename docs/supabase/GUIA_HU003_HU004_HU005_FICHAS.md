# Guía Técnica — Sprint 6 Completo: HU-003, HU-004, HU-005 (Fichas y Kits) y HU-014, HU-015 (Escaneo GS1/GTIN e IA Real)

**Fecha:** 2026-11-06  
**Sprint:** Semana 3 · Sprint 6 · IA y creación de fichas  
**Responsables:** Walter Salas (HU-014, HU-015) y David Anampa (HU-003, HU-004, HU-005)

---

## 1. Alcance implementado en el Sprint 6

| Historia | Requerimiento | Resumen de implementación |
|---|---|---|
| **HU-014** | **RF-014 / RNF-011** | Escaneo óptico offline de códigos EAN-13 y GS1-128/DataMatrix mediante ML Kit (`EscanerGtinView` + `Gs1BarcodeParser`: AI `01` GTIN, AI `17` vencimiento, AI `10` lote y dígito de control Modulo-10), captura fotográfica del empaque físico (`image_picker`), detección de red previa al paso online (`SinConexionIaException` que conserva el código y la foto capturados sin perder el trabajo), consulta real a `public.medicamentos` en Supabase y extracción multimodal estructurada con **Google Gemini Vision** (`gemini-2.5-flash` / `gemini-2.0-flash`) sin datos simulados ni aleatorios. |
| **HU-015** | **RF-015 / RF-013** | Pantalla de revisión editable (`RegistroMedicamentoView`) sincronizada con `MedicamentoExtraccionIA`, panel de validación cruzada (código + catálogo Supabase + fotografía del empaque), selector de categoría (`MEDICAMENTO` vs `DISPOSITIVO_MEDICO`) compartido con HU-003/HU-004, configuración de API Key de Gemini desde la app (`ConfigurarGeminiDialog`) y guardado atómico en Supabase (`registrar_ingreso_lote_hu024`). |
| **HU-003** | **RF-003** | Vista dinámica única (`RegistroFichaView`) que alterna entre **Ficha General** (`paciente_nombre`, `procedencia`, `procedencia_detalle`, `diagnostico_motivo`) y **Ficha de Neonatología** (`madre_nombre`, `habitacion` opcional, `recien_nacido_apellidos`, `tipo_parto`), con selección de área clínica autorizada, turno, prioridad, modalidad de financiamiento (`PARTICULAR`, `SEGURO`, `CONVENIO`), médico a cargo y personal receptor del área. Incluye edición auditada de fichas en estado `SOLICITADO`. |
| **HU-004** | **RF-004** | Selector de catálogo con stock disponible en Farmacia en tiempo real (`SelectorItemFichaDialog` + RPC `catalogo_stock_ficha_hu004`). Los ítems sin stock en Farmacia (`farmacia_disponible <= 0`) aparecen deshabilitados y no pueden seleccionarse individualmente. Los ítems agregados se organizan en dos secciones diferenciadas: **Medicamentos** y **Dispositivos médicos e insumos**. |
| **HU-005** | **RF-005** | Selector de plantillas de kits activos del área (`SelectorKitFichaDialog`). Al aplicar un kit, sus ítems y cantidades se copian de forma independiente al borrador (`FichaBorrador.aplicarKit`) y a `public.dispensacion_items` (`origen_kit = true`), permitiendo editar cantidades, quitar o agregar ítems sin alterar la plantilla del kit ni fichas históricas. |

---

## 2. Cómo aplicar la migración en Supabase

1. Abre el **SQL Editor** de tu proyecto en Supabase.
2. Copia y ejecuta el contenido completo de:
   - `docs/supabase/migracion_hu003_hu004_hu005_fichas_2026_11_06.sql`
3. Verifica que las siguientes funciones RPC existan en el esquema `public`:
   - `public.puede_registrar_ficha_area(p_area TEXT)`
   - `public.contexto_registro_ficha_hu003(p_area TEXT)`
   - `public.catalogo_stock_ficha_hu004(p_busqueda TEXT, p_desde INTEGER, p_limite INTEGER)`
   - `public.listar_fichas_recientes_hu003(p_area TEXT, p_limite INTEGER)`
   - `public.registrar_ficha_hu003(p_solicitud_id UUID, p_id UUID, p_datos JSONB)`

---

## 3. Contrato de persistencia (`public.registrar_ficha_hu003`)

El contrato es estable y compatible con el resto del sprint (HU-014/HU-015):
- **Parámetros:**
  - `p_solicitud_id UUID`: clave de idempotencia generada en el cliente (`generarSolicitudId()`) para evitar duplicados ante reintentos de red.
  - `p_id UUID DEFAULT NULL`: `NULL` al crear una nueva ficha; `UUID` de la ficha cuando se edita en estado `SOLICITADO`.
  - `p_datos JSONB`: contiene cabecera (`tipo_ficha`, `area_origen`, `turno`, `prioridad`, `tipo_atencion`, `financiamiento_id`, `doctor_id`, `doctor_nombre`, `receptor_id`, `recibido_por`, campos de General o Neonatología, `kit_id`, `confirmar_faltante_kit`, `observaciones`) y arreglo `items` (`medicamento_id`, `cantidad`, `categoria_item`, `origen_kit`).
- **Trazabilidad:** registra automáticamente el evento `FICHA_CREADA` o `FICHA_ACTUALIZADA` en `public.auditoria_trazabilidad` con el estado anterior y nuevo completo.

