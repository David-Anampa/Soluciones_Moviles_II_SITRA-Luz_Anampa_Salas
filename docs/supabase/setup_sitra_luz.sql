-- ============================================================================
-- SITRA-Luz • Sistema de Trazabilidad — Clínica La Luz (Sede Tacna)
-- Script de Creación y Configuración Completa de Base de Datos en Supabase (PostgreSQL)
-- Esquema consultado en Supabase: 13 de octubre de 2026.
-- Actualización local HU-012: 15 de octubre de 2026; migración remota pendiente.
-- ============================================================================
-- Instrucciones:
-- 1. Ingresa a tu proyecto en https://supabase.com
-- 2. Ve a la sección "SQL Editor" en el menú lateral izquierdo.
-- 3. Solo para una base nueva: pega este contenido y presiona "Run".
-- 4. Este setup incluye el detalle por lote y la función transaccional de pedidos.
--    Incluye HU-002 y HU-012 (áreas, seguros/convenios y cobertura).
--    Para reconstruir una base nueva, no necesitas ejecutar otra migración después.
-- Para una base existente, usa la migración; no vuelvas a ejecutar semillas,
-- usuarios ni CREATE POLICY de este archivo.
-- ============================================================================

-- 1. EXTENSIONES
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. TABLA DE PERFILES DE USUARIO (Vinculada a auth.users)
-- Cada usuario creado en el módulo Authentication de Supabase tendrá su perfil aquí.
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    nombre TEXT NOT NULL,
    rol TEXT NOT NULL DEFAULT 'ENFERMERIA' CHECK (rol IN (
        'ADMINISTRADOR',
        'JEFATURA_FARMACIA',
        'FARMACIA',
        'ALMACEN',
        'ENFERMERIA'
    )),
    areas_asignadas TEXT[] DEFAULT '{}',
    fcm_token TEXT, -- Almacena el token de Firebase Cloud Messaging para Push Notifications
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 3. TABLA DE ÁREAS / SERVICIOS CLÍNICOS
CREATE TABLE IF NOT EXISTS public.areas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo TEXT UNIQUE NOT NULL, -- 'FARMACIA', 'ALMACEN', 'SOP', 'EMERGENCIA', 'HOSPITALIZACION', 'COCHE_PAROS'
    nombre TEXT NOT NULL,
    descripcion TEXT,
    stock_minimo_alerta INT NOT NULL DEFAULT 5,
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4. TABLA DE MÉDICOS (Para auditoría de fichas de dispensación)
CREATE TABLE IF NOT EXISTS public.doctores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    colegiatura TEXT, -- Ej: CMP-45892
    especialidad TEXT,
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 5. TABLA MAESTRA DE MEDICAMENTOS (Catálogo con GTIN/GS1)
CREATE TABLE IF NOT EXISTS public.medicamentos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gtin TEXT UNIQUE, -- Código de barras / GS1 Datamatrix escaneado por ML Kit
    nombre_comercial TEXT NOT NULL,
    principio_activo TEXT NOT NULL,
    presentacion TEXT NOT NULL, -- 'Cápsula', 'Ampolla', 'Frasco Jarabe', 'Comprimido'
    laboratorio TEXT, -- Fabricante del medicamento; también puede registrarse por lote
    cod_art TEXT, -- Código de artículo interno
    registro_sanitario TEXT, -- Ej: 'RS-12345'
    unidad_presentacion TEXT NOT NULL DEFAULT 'unidades',
    cantidad_por_presentacion INT NOT NULL DEFAULT 1,
    requiere_cadena_frio BOOLEAN NOT NULL DEFAULT false,
    temperatura_min NUMERIC(4, 1) DEFAULT 2.0,
    temperatura_max NUMERIC(4, 1) DEFAULT 8.0,
    imagen_url TEXT,
    precio_kairos NUMERIC(10, 2), -- Precio referencial
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_medicamentos_gtin ON public.medicamentos(gtin);
CREATE INDEX IF NOT EXISTS idx_medicamentos_nombre ON public.medicamentos(nombre_comercial);

-- 6. TABLA DE LOTES (Principio FEFO: First Expired, First Out)
CREATE TABLE IF NOT EXISTS public.lotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    medicamento_id UUID NOT NULL REFERENCES public.medicamentos(id) ON DELETE CASCADE,
    numero_lote TEXT NOT NULL,
    fecha_fabricacion DATE,
    fecha_vencimiento DATE NOT NULL,
    laboratorio TEXT,
    proveedor TEXT,
    precio_compra NUMERIC(10, 2),
    precio_venta NUMERIC(10, 2),
    num_boleta TEXT,
    justificacion TEXT CHECK (justificacion IN ('Compra', 'Donacion')),
    temperatura_recepcion NUMERIC(4, 1),
    observaciones TEXT,
    activo BOOLEAN NOT NULL DEFAULT true,
    fecha_ingreso TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_medicamento_lote UNIQUE (medicamento_id, numero_lote)
);

CREATE INDEX IF NOT EXISTS idx_lotes_vencimiento ON public.lotes(fecha_vencimiento ASC);

-- 7. TABLA DE INVENTARIO Y STOCK POR ÁREA
CREATE TABLE IF NOT EXISTS public.inventario_stock (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lote_id UUID NOT NULL REFERENCES public.lotes(id) ON DELETE CASCADE,
    area_codigo TEXT NOT NULL REFERENCES public.areas(codigo) ON UPDATE CASCADE,
    cantidad INT NOT NULL DEFAULT 0 CHECK (cantidad >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_lote_area UNIQUE (lote_id, area_codigo)
);

-- 8. TABLA DE PEDIDOS DE ABASTECIMIENTO (Flujo inter-áreas: Farmacia ↔ Almacén)
-- Registra cada solicitud de reposición de stock entre áreas clínicas.
-- Flujo: PENDIENTE → EN_PREPARACION → LISTO → COMPLETADO (CANCELADO si está pendiente; RECHAZADO antes del despacho)
CREATE TABLE IF NOT EXISTS public.pedidos_abastecimiento (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo TEXT UNIQUE NOT NULL, -- Correlativo automático. Ej: 'PED-2026-001'

    -- ¿Quién pidió? (personal de farmacia que genera la solicitud)
    solicitante_id UUID REFERENCES public.profiles(id), -- La política de creación exige auth.uid()

    -- Áreas involucradas (FK a tabla maestra de áreas para escalabilidad)
    area_origen TEXT NOT NULL DEFAULT 'FARMACIA' REFERENCES public.areas(codigo) ON UPDATE CASCADE,
    area_destino TEXT NOT NULL DEFAULT 'ALMACEN'  REFERENCES public.areas(codigo) ON UPDATE CASCADE,

    -- ¿Quién despachó en almacén? (responsable que toma y prepara el pedido)
    responsable_almacen_id UUID REFERENCES public.profiles(id),

    -- ¿Quién recibió en farmacia? (responsable asignado para recojo o que confirma recepción)
    responsable_farmacia_id UUID REFERENCES public.profiles(id),

    -- Contexto operativo del pedido (lo llena farmacia al solicitar)
    turno TEXT NOT NULL DEFAULT 'DIA' CHECK (turno IN ('DIA', 'TARDE', 'NOCHE')),
    justificacion TEXT NOT NULL DEFAULT 'RELLENAR_STOCK' CHECK (justificacion IN ('STOCK_CERO', 'RELLENAR_STOCK')),

    -- Modalidad de entrega (lo decide ALMACÉN al confirmar el despacho)
    -- ENTREGA = almacén lo llevará a farmacia | RECOJO = farmacia debe ir a buscarlo
    modalidad_entrega TEXT CHECK (modalidad_entrega IN ('ENTREGA', 'RECOJO')),

    -- Estado del flujo con etapas claras:
    -- PENDIENTE: Farmacia envió la solicitud, almacén aún no la ve/toma
    -- EN_PREPARACION: Almacén tomó el pedido y está alistando los ítems
    -- LISTO: Almacén terminó de alistar, eligió modalidad, esperando entrega/recojo
    -- COMPLETADO: Ambas partes confirmaron la entrega y recepción física
    -- CANCELADO: Farmacia canceló la solicitud antes de que almacén la atienda
    -- RECHAZADO: Almacén denegó la solicitud por stock cero u otro motivo
    estado TEXT NOT NULL DEFAULT 'PENDIENTE' CHECK (estado IN (
        'PENDIENTE', 'EN_PREPARACION', 'LISTO', 'COMPLETADO', 'CANCELADO', 'RECHAZADO'
    )),

    -- Almacén confirma al despachar; únicamente Farmacia confirma la recepción física
    confirmado_almacen BOOLEAN NOT NULL DEFAULT false,  -- Almacén marcó "Entregado/Realizado"
    confirmado_farmacia BOOLEAN NOT NULL DEFAULT false,  -- Farmacia marcó "Recibido/Realizado"

    notas TEXT,                -- Observaciones de farmacia al solicitar
    notas_almacen TEXT,        -- Observaciones de almacén al despachar
    motivo_cancelacion TEXT,   -- Solo si estado = CANCELADO (cancelado por Farmacia)
    motivo_rechazo TEXT,       -- Solo si estado = RECHAZADO (rechazado por Almacén)
    cancelado_por UUID REFERENCES public.profiles(id),
    rechazado_por UUID REFERENCES public.profiles(id),
    fecha_rechazo TIMESTAMPTZ,
    observacion_recepcion TEXT, -- Motivo del contra-asiento en recepción

    -- Timestamps del ciclo de vida (cada transición de estado queda registrada)
    fecha_solicitud TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    fecha_toma TIMESTAMPTZ,        -- Cuándo almacén presionó "Tomar Pedido"
    fecha_despacho TIMESTAMPTZ,
    fecha_recepcion TIMESTAMPTZ,   -- Campo existente conservado; la RPC usa fecha_confirmacion_farmacia
    fecha_listo TIMESTAMPTZ,       -- Cuándo almacén presionó "Listo"
    fecha_confirmacion_almacen TIMESTAMPTZ,   -- Cuándo almacén marcó realizado
    fecha_confirmacion_farmacia TIMESTAMPTZ,  -- Cuándo farmacia marcó recibido
    fecha_cancelacion TIMESTAMPTZ, -- Cuándo farmacia canceló el pedido
    fecha_completado TIMESTAMPTZ   -- Cuándo ambas confirmaciones se cumplieron
);

-- 8b. DETALLE DE ÍTEMS POR PEDIDO (con trazabilidad de lote al despachar)
CREATE TABLE IF NOT EXISTS public.pedidos_abastecimiento_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID NOT NULL REFERENCES public.pedidos_abastecimiento(id) ON DELETE CASCADE,
    medicamento_id UUID NOT NULL REFERENCES public.medicamentos(id),
    cantidad_solicitada INT NOT NULL CHECK (cantidad_solicitada > 0),
    cantidad_despachada INT NOT NULL DEFAULT 0 CHECK (cantidad_despachada >= 0),
    cantidad_recibida INT, -- La sección 16 instala pedido_cantidad_recibida_check
    -- La migración agrega pedido_abastecimiento_despachos para registrar todos los lotes.
    -- Lote específico del que se descuenta al despachar (FEFO: primero el que vence antes)
    lote_id UUID REFERENCES public.lotes(id)
);

-- 9. TABLA DE KITS PREARMADOS (Para Quirófano SOP, Coche de Paros, etc.)
CREATE TABLE IF NOT EXISTS public.kits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    descripcion TEXT,
    area_destino TEXT NOT NULL, -- 'SOP', 'COCHE_PAROS', 'EMERGENCIA'
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.kit_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kit_id UUID NOT NULL REFERENCES public.kits(id) ON DELETE CASCADE,
    medicamento_id UUID NOT NULL REFERENCES public.medicamentos(id),
    cantidad INT NOT NULL DEFAULT 1 CHECK (cantidad > 0)
);

-- 10. TABLA DE FICHAS DE DISPENSACIÓN (Áreas Críticas / Enfermería -> Farmacia)
CREATE TABLE IF NOT EXISTS public.dispensaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero_ficha TEXT UNIQUE NOT NULL, -- Ej: 'FCH-2026-001'
    tipo TEXT NOT NULL CHECK (tipo IN ('KIT', 'INDIVIDUAL')),
    kit_id UUID REFERENCES public.kits(id),
    area_origen TEXT NOT NULL, -- Área que solicita: 'SOP', 'EMERGENCIA', etc.
    doctor_id UUID REFERENCES public.doctores(id),
    paciente_nombre TEXT NOT NULL,
    diagnostico_motivo TEXT,
    prioridad TEXT NOT NULL DEFAULT 'NORMAL' CHECK (prioridad IN ('NORMAL', 'URGENTE')),
    estado TEXT NOT NULL DEFAULT 'SOLICITADO' CHECK (estado IN (
        'SOLICITADO',
        'EN_PREPARACION',
        'LISTO_PARA_RECOJO',
        'ENTREGADO',
        'CANCELADO'
    )),
    foto_salida_url TEXT,
    solicitado_por UUID REFERENCES public.profiles(id),
    entregado_por UUID REFERENCES public.profiles(id),
    recibido_por TEXT, -- Nombre de la enfermera/técnico que recoge
    observaciones TEXT,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    fecha_entrega TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.dispensacion_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dispensacion_id UUID NOT NULL REFERENCES public.dispensaciones(id) ON DELETE CASCADE,
    medicamento_id UUID NOT NULL REFERENCES public.medicamentos(id),
    cantidad_solicitada INT NOT NULL CHECK (cantidad_solicitada > 0),
    cantidad_entregada INT NOT NULL DEFAULT 0 CHECK (cantidad_entregada >= 0)
);

-- 11. TABLA DE TRAZABILIDAD Y AUDITORÍA INMUTABLE (Nivel Hospitalario)
CREATE TABLE IF NOT EXISTS public.auditoria_trazabilidad (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo_evento TEXT NOT NULL, -- 'INGRESO_ALMACEN', 'TRANSFERENCIA_FARMACIA', 'DISPENSACION_AREA', 'AJUSTE_STOCK', 'CREACION_PEDIDO'
    
    -- Trazabilidad de Entidad (¿En qué documento exacto pasó esto?)
    entidad_referencia_id UUID, -- Ej: el ID de pedidos_abastecimiento, dispensaciones, etc.
    tabla_referencia TEXT,      -- Ej: 'pedidos_abastecimiento'
    
    medicamento_id UUID REFERENCES public.medicamentos(id),
    lote_id UUID REFERENCES public.lotes(id),
    usuario_id UUID REFERENCES public.profiles(id),
    
    area_origen TEXT REFERENCES public.areas(codigo) ON DELETE SET NULL,
    area_destino TEXT REFERENCES public.areas(codigo) ON DELETE SET NULL,
    
    -- Magnitud del movimiento
    cantidad INT,
    
    -- Snapshots de Estado (El Antes y el Después para comprobación matemática)
    estado_anterior JSONB,
    estado_nuevo JSONB,
    
    descripcion TEXT,
    detalles_extra JSONB DEFAULT '{}'::jsonb,
    
    fecha TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_auditoria_fecha ON public.auditoria_trazabilidad(fecha DESC);

-- ============================================================================
-- 12. TRIGGERS Y FUNCIONES AUTOMÁTICAS
-- ============================================================================

-- Trigger para crear automáticamente el perfil al registrarse un usuario en auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    -- Misma regla de HU-002 desde el inicio: el email y la metadata no asignan roles.
    -- La sección de usuarios de demostración asigna sus permisos explícitamente.
    INSERT INTO public.profiles(id, email, nombre, rol, areas_asignadas, activo)
    VALUES (NEW.id, NEW.email,
      COALESCE(NULLIF(btrim(NEW.raw_user_meta_data->>'nombre'), ''), split_part(NEW.email, '@', 1)),
      'ENFERMERIA', '{}'::TEXT[], false)
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_profiles_updated_at ON public.profiles;
CREATE TRIGGER set_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 13. POLÍTICAS DE SEGURIDAD ROW LEVEL SECURITY (RLS)
-- ============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doctores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medicamentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventario_stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedidos_abastecimiento ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedidos_abastecimiento_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kit_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispensaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispensacion_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auditoria_trazabilidad ENABLE ROW LEVEL SECURITY;

-- Las políticas definitivas y los privilegios se instalan en la sección HU-002
-- al final del setup, después de crear el detalle por lote y la función de pedidos.
-- No se crean políticas abiertas FOR ALL para usuarios autenticados.

-- ============================================================================
-- 14. DATOS INICIALES (SEED DATA PARA PRUEBAS)
-- ============================================================================

-- Áreas clínicas de la Clínica La Luz
INSERT INTO public.areas (codigo, nombre, descripcion, stock_minimo_alerta) VALUES
('ALMACEN', 'Almacén General', 'Recepción de proveedores y custodia principal', 20),
('FARMACIA', 'Farmacia Central', 'Dispensación interna a pisos y pacientes', 15),
('SOP', 'Sala de Operaciones (Quirófano)', 'Procedimientos quirúrgicos programados y de urgencia', 5),
('EMERGENCIA', 'Servicio de Emergencias', 'Atención crítica continua 24 horas', 10),
('HOSPITALIZACION', 'Pabellón de Hospitalización', 'Habitaciones y camas de reposo clínico', 8),
('COCHE_PAROS', 'Coche de Paros / Reanimación', 'Medicamentos de soporte vital y emergencia extrema', 3)
ON CONFLICT (codigo) DO NOTHING;

-- Doctores de la clínica
INSERT INTO public.doctores (nombre, colegiatura, especialidad) VALUES
('Dr. Roberto Chávez Morales', 'CMP-34120', 'Cirugía General'),
('Dra. Vanessa Ortiz Paredes', 'CMP-42901', 'Anestesiología'),
('Dr. Marco Antonio Vega', 'CMP-28754', 'Traumatología y Ortopedia'),
('Dra. Sofía Benavides Ríos', 'CMP-51209', 'Medicina de Emergencia')
ON CONFLICT DO NOTHING;

-- Medicamentos maestros
INSERT INTO public.medicamentos (gtin, cod_art, nombre_comercial, principio_activo, presentacion, registro_sanitario, unidad_presentacion, cantidad_por_presentacion, requiere_cadena_frio, precio_kairos) VALUES
('7750215001234', 'ART-001', 'Amoxicilina 500mg', 'Amoxicilina', 'Cápsula', 'RS-EE-04812', 'cápsulas', 100, false, 25.50),
('7750215005678', 'ART-002', 'Paracetamol 1g Inyectable', 'Paracetamol', 'Ampolla', 'RS-EN-01294', 'ampollas', 1, false, 5.00),
('7750215009012', 'ART-003', 'Fentanilo 0.5mg/10ml', 'Citrato de Fentanilo', 'Ampolla', 'RS-EE-09312', 'ampollas', 5, false, 80.00),
('7750215003456', 'ART-004', 'Insulina NPH Humana 100 UI/ml', 'Insulina Humana', 'Frasco', 'RS-BE-01582', 'frascos', 1, true, 45.00),
('7750215007890', 'ART-005', 'Adrenalina 1mg/ml', 'Epinefrina', 'Ampolla', 'RS-EN-03481', 'ampollas', 10, false, 15.00),
('7750215006543', 'ART-006', 'Ceftriaxona 1g', 'Ceftriaxona Sódica', 'Frasco Ampolla', 'RS-EE-07821', 'viales', 1, false, 12.00)
ON CONFLICT (gtin) DO NOTHING;

-- Lotes iniciales para demostración (con fechas de vencimiento para alertas FEFO)
DO $$
DECLARE
    med_amox UUID;
    med_parac UUID;
    med_fenta UUID;
    med_insu UUID;
    med_adren UUID;
    lote_amox_id UUID;
    lote_parac_id UUID;
    lote_fenta_id UUID;
    lote_insu_id UUID;
BEGIN
    SELECT id INTO med_amox FROM public.medicamentos WHERE gtin = '7750215001234' LIMIT 1;
    SELECT id INTO med_parac FROM public.medicamentos WHERE gtin = '7750215005678' LIMIT 1;
    SELECT id INTO med_fenta FROM public.medicamentos WHERE gtin = '7750215009012' LIMIT 1;
    SELECT id INTO med_insu FROM public.medicamentos WHERE gtin = '7750215003456' LIMIT 1;

    IF med_amox IS NOT NULL THEN
        INSERT INTO public.lotes (medicamento_id, numero_lote, fecha_vencimiento, proveedor, precio_compra, precio_venta, num_boleta, justificacion)
        VALUES (med_amox, 'L2026-A15', CURRENT_DATE + INTERVAL '180 days', 'Distribuidora Médica Sur', 18.00, 22.00, 'BOL-001', 'Compra')
        ON CONFLICT (medicamento_id, numero_lote) DO NOTHING
        RETURNING id INTO lote_amox_id;

        IF lote_amox_id IS NOT NULL THEN
            INSERT INTO public.inventario_stock (lote_id, area_codigo, cantidad)
            VALUES (lote_amox_id, 'ALMACEN', 120), (lote_amox_id, 'FARMACIA', 40)
            ON CONFLICT (lote_id, area_codigo) DO UPDATE SET cantidad = EXCLUDED.cantidad;
        END IF;
    END IF;

    IF med_parac IS NOT NULL THEN
        -- Lote próximo a vencer (alerta preventiva en semáforo)
        INSERT INTO public.lotes (medicamento_id, numero_lote, fecha_vencimiento, proveedor, justificacion)
        VALUES (med_parac, 'L2025-P02', CURRENT_DATE + INTERVAL '20 days', 'Laboratorios Roche / Perú', 'Donacion')
        ON CONFLICT (medicamento_id, numero_lote) DO NOTHING
        RETURNING id INTO lote_parac_id;

        IF lote_parac_id IS NOT NULL THEN
            INSERT INTO public.inventario_stock (lote_id, area_codigo, cantidad)
            VALUES (lote_parac_id, 'FARMACIA', 25)
            ON CONFLICT (lote_id, area_codigo) DO UPDATE SET cantidad = EXCLUDED.cantidad;
        END IF;
    END IF;

    IF med_insu IS NOT NULL THEN
        INSERT INTO public.lotes (medicamento_id, numero_lote, fecha_vencimiento, proveedor, precio_compra, precio_venta, num_boleta, justificacion)
        VALUES (med_insu, 'L2027-INS8', CURRENT_DATE + INTERVAL '300 days', 'Novo Nordisk', 35.00, 42.00, 'FAC-002', 'Compra')
        ON CONFLICT (medicamento_id, numero_lote) DO NOTHING
        RETURNING id INTO lote_insu_id;

        IF lote_insu_id IS NOT NULL THEN
            INSERT INTO public.inventario_stock (lote_id, area_codigo, cantidad)
            VALUES (lote_insu_id, 'ALMACEN', 30), (lote_insu_id, 'FARMACIA', 10)
            ON CONFLICT (lote_id, area_codigo) DO UPDATE SET cantidad = EXCLUDED.cantidad;
        END IF;
    END IF;
END $$;

-- Kits prearmados de demostración
INSERT INTO public.kits (nombre, descripcion, area_destino) VALUES
('Kit Cirugía General Estándar', 'Insumos y anestésicos para intervenciones de quirófano general', 'SOP'),
('Kit Reanimación Cardiopulmonar (RCP)', 'Medicamentos de primera línea para parada cardiorrespiratoria', 'COCHE_PAROS'),
('Kit Sutura y Urgencias Menores', 'Anestésicos locales y antibióticos profilácticos', 'EMERGENCIA')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- 15. USUARIOS OFICIALES DEL SISTEMA (5 ROLES CLÍNICOS)
-- ============================================================================
DO $$
DECLARE
    uid_admin UUID := 'a0000000-0000-0000-0000-000000000001';
    uid_jefe UUID := 'a0000000-0000-0000-0000-000000000002';
    uid_farma UUID := 'a0000000-0000-0000-0000-000000000003';
    uid_almacen UUID := 'a0000000-0000-0000-0000-000000000004';
    uid_enferm UUID := 'a0000000-0000-0000-0000-000000000005';
BEGIN
    -- 1. Administrador (admin123)
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
    VALUES (uid_admin, '00000000-0000-0000-0000-000000000000', 'admin@sitraluz.pe', crypt('admin123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"nombre":"Ing. Carlos Mendoza","rol":"ADMINISTRADOR","areas":"Sistemas,Auditoría"}', now(), now(), 'authenticated', 'authenticated')
    ON CONFLICT (id) DO NOTHING;

    -- 2. Jefatura de Farmacia (jefe123)
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
    VALUES (uid_jefe, '00000000-0000-0000-0000-000000000000', 'jefatura@sitraluz.pe', crypt('jefe123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"nombre":"Dra. Elena Ramos","rol":"JEFATURA_FARMACIA","areas":"Farmacia Central"}', now(), now(), 'authenticated', 'authenticated')
    ON CONFLICT (id) DO NOTHING;

    -- 3. Farmacia (farma123)
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
    VALUES (uid_farma, '00000000-0000-0000-0000-000000000000', 'farmacia@sitraluz.pe', crypt('farma123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"nombre":"Q.F. Manuel Flores","rol":"FARMACIA","areas":"Farmacia Central"}', now(), now(), 'authenticated', 'authenticated')
    ON CONFLICT (id) DO NOTHING;

    -- 4. Almacén General (almacen123)
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
    VALUES (uid_almacen, '00000000-0000-0000-0000-000000000000', 'almacen@sitraluz.pe', crypt('almacen123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"nombre":"Sr. Roberto Paredes","rol":"ALMACEN","areas":"Almacén General"}', now(), now(), 'authenticated', 'authenticated')
    ON CONFLICT (id) DO NOTHING;

    -- 5. Enfermería / Técnico (enfermera123)
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
    VALUES (uid_enferm, '00000000-0000-0000-0000-000000000000', 'enfermeria@sitraluz.pe', crypt('enfermera123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"nombre":"Lic. Ana Morales","rol":"ENFERMERIA","areas":"UCI Adultos,SOP"}', now(), now(), 'authenticated', 'authenticated')
    ON CONFLICT (id) DO NOTHING;
END $$;

-- Asegurar actualización de perfiles con roles específicos
UPDATE public.profiles SET rol = 'ADMINISTRADOR', nombre = 'Ing. Carlos Mendoza', areas_asignadas = ARRAY['Sistemas', 'Auditoría'], activo = true WHERE email ILIKE '%admin@sitraluz.pe%';
UPDATE public.profiles SET rol = 'JEFATURA_FARMACIA', nombre = 'Dra. Elena Ramos', areas_asignadas = ARRAY['Farmacia Central'], activo = true WHERE email ILIKE '%jefatura@sitraluz.pe%';
UPDATE public.profiles SET rol = 'FARMACIA', nombre = 'Q.F. Manuel Flores', areas_asignadas = ARRAY['Farmacia Central'], activo = true WHERE email ILIKE '%farmacia@sitraluz.pe%';
UPDATE public.profiles SET rol = 'ALMACEN', nombre = 'Sr. Roberto Paredes', areas_asignadas = ARRAY['Almacén General'], activo = true WHERE email ILIKE '%almacen@sitraluz.pe%';
UPDATE public.profiles SET rol = 'ENFERMERIA', nombre = 'Lic. Ana Morales', areas_asignadas = ARRAY['UCI Adultos', 'SOP'], activo = true WHERE email ILIKE '%enfermeria@sitraluz.pe%';

-- ============================================================================
-- 16. FLUJO TRANSACCIONAL DE PEDIDOS Y RECEPCIÓN
-- Se mantiene sincronizado con migracion_recepcion_pedidos_2026_10_12.sql.
-- ============================================================================
BEGIN;

ALTER TABLE public.pedidos_abastecimiento
  ADD COLUMN IF NOT EXISTS motivo_cancelacion TEXT,
  ADD COLUMN IF NOT EXISTS fecha_cancelacion TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS motivo_rechazo TEXT,
  ADD COLUMN IF NOT EXISTS fecha_rechazo TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cancelado_por UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS rechazado_por UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS observacion_recepcion TEXT,
  ADD COLUMN IF NOT EXISTS modalidad_entrega TEXT CHECK (modalidad_entrega IN ('ENTREGA', 'RECOJO')),
  ADD COLUMN IF NOT EXISTS confirmado_almacen BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS confirmado_farmacia BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS responsable_almacen_id UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS responsable_farmacia_id UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS fecha_toma TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS fecha_listo TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS fecha_despacho TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS fecha_confirmacion_almacen TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS fecha_confirmacion_farmacia TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS fecha_completado TIMESTAMPTZ;

ALTER TABLE public.pedidos_abastecimiento
  DROP CONSTRAINT IF EXISTS pedidos_abastecimiento_estado_check;
ALTER TABLE public.pedidos_abastecimiento
  ADD CONSTRAINT pedidos_abastecimiento_estado_check CHECK (estado IN (
    'PENDIENTE', 'EN_PREPARACION', 'LISTO', 'COMPLETADO', 'CANCELADO', 'RECHAZADO'
  ));

ALTER TABLE public.pedidos_abastecimiento_items
  ADD COLUMN IF NOT EXISTS cantidad_despachada INTEGER NOT NULL DEFAULT 0 CHECK (cantidad_despachada >= 0),
  ADD COLUMN IF NOT EXISTS lote_id UUID REFERENCES public.lotes(id),
  ADD COLUMN IF NOT EXISTS cantidad_recibida INTEGER;

ALTER TABLE public.pedidos_abastecimiento_items
  DROP CONSTRAINT IF EXISTS pedido_cantidad_recibida_check;
ALTER TABLE public.pedidos_abastecimiento_items
  ADD CONSTRAINT pedido_cantidad_recibida_check CHECK (
    cantidad_recibida IS NULL OR
    (cantidad_recibida >= 0 AND cantidad_recibida <= cantidad_despachada)
  );

-- Un medicamento puede salir de varios lotes FEFO. Conserva cada despacho
-- original y su devolución sin reemplazar las cantidades emitidas.
CREATE TABLE IF NOT EXISTS public.pedido_abastecimiento_despachos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id UUID NOT NULL REFERENCES public.pedidos_abastecimiento_items(id),
  lote_id UUID NOT NULL REFERENCES public.lotes(id),
  cantidad INTEGER NOT NULL CHECK (cantidad > 0),
  cantidad_devuelta INTEGER NOT NULL DEFAULT 0 CHECK (cantidad_devuelta >= 0 AND cantidad_devuelta <= cantidad),
  UNIQUE (item_id, lote_id)
);
ALTER TABLE public.pedido_abastecimiento_despachos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Lectura de despachos autenticados" ON public.pedido_abastecimiento_despachos;
CREATE POLICY "Lectura de despachos autenticados"
  ON public.pedido_abastecimiento_despachos FOR SELECT TO authenticated USING (true);
GRANT SELECT ON public.pedido_abastecimiento_despachos TO authenticated;

-- SECURITY DEFINER con search_path fijo: solo esta función escribe el detalle
-- por lotes; exige identidad real, perfil activo, rol y transición permitida.
CREATE OR REPLACE FUNCTION public.procesar_pedido_abastecimiento(
  p_pedido_id UUID,
  p_accion TEXT,
  p_motivo TEXT DEFAULT NULL,
  p_cantidades JSONB DEFAULT '{}'::jsonb,
  p_modalidad TEXT DEFAULT NULL,
  p_notas TEXT DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_usuario UUID := auth.uid();
  v_rol TEXT;
  v_pedido public.pedidos_abastecimiento%ROWTYPE;
  v_item RECORD;
  v_stock RECORD;
  v_despacho RECORD;
  v_cantidad INTEGER;
  v_restante INTEGER;
  v_movimiento INTEGER;
  v_total INTEGER := 0;
  v_devolucion INTEGER;
  v_evento TEXT;
  v_nuevo TEXT;
BEGIN
  SELECT rol INTO v_rol FROM public.profiles WHERE id = v_usuario AND activo;
  IF v_usuario IS NULL OR v_rol IS NULL THEN
    RAISE EXCEPTION 'Inicie sesión con un usuario activo para realizar esta acción.';
  END IF;
  IF p_accion IS NULL OR p_accion NOT IN ('TOMAR', 'CANCELAR', 'RECHAZAR', 'DESPACHAR', 'RECIBIR') THEN
    RAISE EXCEPTION 'Acción de pedido no válida.';
  END IF;
  IF p_accion IN ('CANCELAR', 'RECIBIR') AND v_rol <> 'FARMACIA'
     OR p_accion IN ('TOMAR', 'RECHAZAR', 'DESPACHAR') AND v_rol <> 'ALMACEN' THEN
    RAISE EXCEPTION 'Su rol no puede realizar esta acción.';
  END IF;

  SELECT * INTO v_pedido FROM public.pedidos_abastecimiento WHERE id = p_pedido_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'El pedido no existe.'; END IF;
  IF v_pedido.area_origen <> 'FARMACIA' OR v_pedido.area_destino <> 'ALMACEN' THEN
    RAISE EXCEPTION 'Esta operación solo admite pedidos de Farmacia a Almacén.';
  END IF;
  IF p_accion = 'CANCELAR' AND v_pedido.estado <> 'PENDIENTE' THEN
    RAISE EXCEPTION 'El pedido ya no está pendiente. Comuníquese físicamente con Almacén si requiere cancelarlo.';
  END IF;
  IF p_accion = 'TOMAR' AND v_pedido.estado <> 'PENDIENTE'
     OR p_accion = 'RECHAZAR' AND v_pedido.estado NOT IN ('PENDIENTE', 'EN_PREPARACION')
     OR p_accion = 'DESPACHAR' AND v_pedido.estado <> 'EN_PREPARACION'
     OR p_accion = 'RECIBIR' AND (v_pedido.estado <> 'LISTO' OR NOT COALESCE(v_pedido.confirmado_almacen, false)) THEN
    RAISE EXCEPTION 'El pedido cambió de estado. Actualice la lista antes de continuar.';
  END IF;
  IF p_accion IN ('CANCELAR', 'RECHAZAR') AND NULLIF(btrim(p_motivo), '') IS NULL THEN
    RAISE EXCEPTION 'Debe indicar un motivo.';
  END IF;

  IF p_accion IN ('DESPACHAR', 'RECIBIR') THEN
    IF p_cantidades IS NULL OR jsonb_typeof(p_cantidades) <> 'object' THEN
      RAISE EXCEPTION 'Las cantidades no son válidas.';
    END IF;
    IF EXISTS (
      SELECT 1 FROM jsonb_each(p_cantidades) x
      WHERE jsonb_typeof(x.value) <> 'number' OR x.value::TEXT !~ '^[0-9]+$'
        OR NOT EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i
                       WHERE i.pedido_id = p_pedido_id AND i.id::TEXT = x.key)
    ) THEN RAISE EXCEPTION 'Indique cantidades enteras de los ítems de este pedido.'; END IF;
    PERFORM id FROM public.pedidos_abastecimiento_items WHERE pedido_id = p_pedido_id ORDER BY id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'El pedido no contiene ítems.'; END IF;
    -- Orden fijo de bloqueo para evitar pérdidas por movimientos concurrentes.
    PERFORM s.id FROM public.inventario_stock s JOIN public.lotes l ON l.id = s.lote_id
      WHERE s.area_codigo IN ('ALMACEN', 'FARMACIA') AND l.medicamento_id IN (
        SELECT medicamento_id FROM public.pedidos_abastecimiento_items WHERE pedido_id = p_pedido_id
      ) ORDER BY s.id FOR UPDATE OF s;
  END IF;

  CASE p_accion
  WHEN 'TOMAR' THEN
    v_nuevo := 'EN_PREPARACION'; v_evento := 'TOMA_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo,
      responsable_almacen_id = v_usuario, fecha_toma = now() WHERE id = p_pedido_id;
  WHEN 'CANCELAR' THEN
    v_nuevo := 'CANCELADO'; v_evento := 'CANCELACION_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo,
      motivo_cancelacion = btrim(p_motivo), fecha_cancelacion = now(), cancelado_por = v_usuario
      WHERE id = p_pedido_id;
  WHEN 'RECHAZAR' THEN
    v_nuevo := 'RECHAZADO'; v_evento := 'RECHAZO_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo,
      motivo_rechazo = btrim(p_motivo), fecha_rechazo = now(), rechazado_por = v_usuario
      WHERE id = p_pedido_id;
  WHEN 'DESPACHAR' THEN
    IF p_modalidad IS NULL OR p_modalidad NOT IN ('ENTREGA', 'RECOJO') THEN
      RAISE EXCEPTION 'Seleccione si Almacén entrega o Farmacia recoge.';
    END IF;
    FOR v_item IN SELECT * FROM public.pedidos_abastecimiento_items WHERE pedido_id = p_pedido_id ORDER BY id LOOP
      v_cantidad := COALESCE((p_cantidades->>v_item.id::TEXT)::INTEGER, 0);
      v_restante := v_cantidad;
      FOR v_stock IN
        SELECT s.*, l.fecha_vencimiento FROM public.inventario_stock s
        JOIN public.lotes l ON l.id = s.lote_id
        WHERE s.area_codigo = 'ALMACEN' AND l.medicamento_id = v_item.medicamento_id
          AND l.activo AND l.fecha_vencimiento > CURRENT_DATE AND s.cantidad > 0
        ORDER BY l.fecha_vencimiento, l.id
      LOOP
        EXIT WHEN v_restante = 0;
        v_movimiento := LEAST(v_restante, v_stock.cantidad);
        UPDATE public.inventario_stock SET cantidad = cantidad - v_movimiento, updated_at = now() WHERE id = v_stock.id;
        INSERT INTO public.inventario_stock(lote_id, area_codigo, cantidad)
          VALUES(v_stock.lote_id, 'FARMACIA', v_movimiento)
          ON CONFLICT (lote_id, area_codigo) DO UPDATE
          SET cantidad = public.inventario_stock.cantidad + EXCLUDED.cantidad, updated_at = now();
        INSERT INTO public.pedido_abastecimiento_despachos(item_id, lote_id, cantidad)
          VALUES(v_item.id, v_stock.lote_id, v_movimiento);
        INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
          usuario_id, medicamento_id, lote_id, area_origen, area_destino, cantidad, descripcion)
          VALUES('TRANSFERENCIA_FARMACIA', p_pedido_id, 'pedidos_abastecimiento', v_usuario,
            v_item.medicamento_id, v_stock.lote_id, 'ALMACEN', 'FARMACIA', v_movimiento, 'Despacho de pedido ' || v_pedido.codigo);
        v_restante := v_restante - v_movimiento;
      END LOOP;
      IF v_restante > 0 THEN RAISE EXCEPTION 'Stock disponible insuficiente. Actualice las cantidades antes de despachar.'; END IF;
      UPDATE public.pedidos_abastecimiento_items SET cantidad_despachada = v_cantidad WHERE id = v_item.id;
      v_total := v_total + v_cantidad;
    END LOOP;
    IF v_total = 0 THEN RAISE EXCEPTION 'No se puede despachar un pedido vacío. Utilice Rechazar Solicitud.'; END IF;
    v_nuevo := 'LISTO'; v_evento := 'DESPACHO_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo, modalidad_entrega = p_modalidad,
      confirmado_almacen = true, responsable_almacen_id = v_usuario,
      fecha_listo = now(), fecha_despacho = now(), fecha_confirmacion_almacen = now(),
      notas_almacen = NULLIF(btrim(p_notas), '') WHERE id = p_pedido_id;
  WHEN 'RECIBIR' THEN
    FOR v_item IN SELECT * FROM public.pedidos_abastecimiento_items WHERE pedido_id = p_pedido_id ORDER BY id LOOP
      v_cantidad := COALESCE((p_cantidades->>v_item.id::TEXT)::INTEGER, v_item.cantidad_despachada);
      IF v_cantidad < 0 OR v_cantidad > v_item.cantidad_despachada THEN
        RAISE EXCEPTION 'La cantidad aceptada debe estar entre cero y lo despachado.';
      END IF;
      v_devolucion := v_item.cantidad_despachada - v_cantidad;
      IF v_devolucion > 0 THEN
        IF NULLIF(btrim(p_motivo), '') IS NULL THEN RAISE EXCEPTION 'Indique el motivo de la devolución.'; END IF;
        -- Compatibilidad con despachos anteriores que guardaban un único lote.
        IF NOT EXISTS (SELECT 1 FROM public.pedido_abastecimiento_despachos WHERE item_id = v_item.id) THEN
          IF v_item.lote_id IS NULL THEN
            RAISE EXCEPTION 'El despacho anterior no tiene lote trazable. Revise el movimiento antes de devolver.';
          END IF;
          INSERT INTO public.pedido_abastecimiento_despachos(item_id, lote_id, cantidad)
            VALUES(v_item.id, v_item.lote_id, v_item.cantidad_despachada);
        END IF;
        v_restante := v_devolucion;
        -- Retorna primero los lotes con vencimiento posterior; conserva FEFO en lo aceptado.
        FOR v_despacho IN SELECT d.* FROM public.pedido_abastecimiento_despachos d
          JOIN public.lotes l ON l.id = d.lote_id WHERE d.item_id = v_item.id
          ORDER BY l.fecha_vencimiento DESC, l.id DESC FOR UPDATE OF d
        LOOP
          EXIT WHEN v_restante = 0;
          v_movimiento := LEAST(v_restante, v_despacho.cantidad - v_despacho.cantidad_devuelta);
          IF v_movimiento = 0 THEN CONTINUE; END IF;
          UPDATE public.inventario_stock SET cantidad = cantidad - v_movimiento, updated_at = now()
            WHERE lote_id = v_despacho.lote_id AND area_codigo = 'FARMACIA' AND cantidad >= v_movimiento;
          IF NOT FOUND THEN RAISE EXCEPTION 'Stock de Farmacia insuficiente para devolver el lote. Revise el inventario.'; END IF;
          INSERT INTO public.inventario_stock(lote_id, area_codigo, cantidad)
            VALUES(v_despacho.lote_id, 'ALMACEN', v_movimiento)
            ON CONFLICT (lote_id, area_codigo) DO UPDATE
            SET cantidad = public.inventario_stock.cantidad + EXCLUDED.cantidad, updated_at = now();
          UPDATE public.pedido_abastecimiento_despachos SET cantidad_devuelta = cantidad_devuelta + v_movimiento WHERE id = v_despacho.id;
          INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
            usuario_id, medicamento_id, lote_id, area_origen, area_destino, cantidad, descripcion, detalles_extra)
            VALUES('DEVOLUCION_EN_RECEPCION', p_pedido_id, 'pedidos_abastecimiento', v_usuario,
              v_item.medicamento_id, v_despacho.lote_id, 'FARMACIA', 'ALMACEN', v_movimiento,
              btrim(p_motivo), jsonb_build_object('item_id', v_item.id, 'despachado', v_item.cantidad_despachada, 'aceptado', v_cantidad));
          v_restante := v_restante - v_movimiento;
        END LOOP;
        IF v_restante > 0 THEN RAISE EXCEPTION 'El detalle de lotes no cubre la devolución. Revise el despacho.'; END IF;
      END IF;
      UPDATE public.pedidos_abastecimiento_items SET cantidad_recibida = v_cantidad WHERE id = v_item.id;
      v_total := v_total + v_devolucion;
    END LOOP;
    v_nuevo := 'COMPLETADO'; v_evento := 'RECEPCION_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo, confirmado_farmacia = true,
      responsable_farmacia_id = v_usuario, fecha_confirmacion_farmacia = now(), fecha_completado = now(),
      observacion_recepcion = CASE WHEN v_total > 0 THEN btrim(p_motivo) ELSE NULL END WHERE id = p_pedido_id;
  END CASE;

  INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
    usuario_id, estado_anterior, estado_nuevo, descripcion, detalles_extra)
    VALUES(v_evento, p_pedido_id, 'pedidos_abastecimiento', v_usuario,
      jsonb_build_object('estado', v_pedido.estado), jsonb_build_object('estado', v_nuevo),
      p_accion || ' pedido ' || v_pedido.codigo,
      jsonb_build_object('motivo', p_motivo, 'modalidad', p_modalidad, 'cantidades', p_cantidades));
END;
$$;

REVOKE ALL ON FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;


-- ============================================================================
-- 17. HU-002: SESION Y PERMISOS POR ROL
-- Sincronizado con migracion_hu002_permisos_sesion_2026_10_13.sql.
-- ============================================================================
-- HU-002: ejecutar después de migracion_recepcion_pedidos_2026_10_12.sql.
-- Sustituye las políticas del sistema; no elimina tablas, usuarios ni registros.
-- Las fichas y kits quedan preparados para sus futuros sprints, sin implementar sus flujos.
BEGIN;

-- Consulta el perfil de la sesión, nunca el rol enviado por el cliente.
-- SECURITY DEFINER evita recursión al consultar profiles desde sus propias políticas.
CREATE OR REPLACE FUNCTION public.sitra_rol_actual()
RETURNS TEXT LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT p.rol FROM public.profiles p WHERE p.id = auth.uid() AND p.activo = true;
$$;

-- Consulta auxiliar de RLS: devuelve si el perfil autenticado y activo tiene
-- asignada el área consultada. No exige que el área siga habilitada, porque
-- las asignaciones anteriores deben conservar acceso a su información histórica.
CREATE OR REPLACE FUNCTION public.sitra_tiene_area(p_area TEXT)
RETURNS BOOLEAN LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    JOIN public.areas a ON a.codigo = p_area OR lower(btrim(a.nombre)) = lower(btrim(p_area))
    CROSS JOIN LATERAL unnest(p.areas_asignadas) AS asignada(valor)
    WHERE p.id = auth.uid() AND p.activo = true
      AND (upper(btrim(asignada.valor)) = upper(a.codigo)
           OR lower(btrim(asignada.valor)) = lower(btrim(a.nombre)))
  );
$$;
REVOKE ALL ON FUNCTION public.sitra_rol_actual() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.sitra_tiene_area(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sitra_rol_actual() TO authenticated;
GRANT EXECUTE ON FUNCTION public.sitra_tiene_area(TEXT) TO authenticated;

-- El usuario únicamente puede sincronizar su propio FCM token. Rol, activo,
-- áreas y datos de perfil se administran por Administrador o servicio autorizado.
CREATE OR REPLACE FUNCTION public.sitra_proteger_perfil()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF current_user IN ('postgres', 'service_role', 'supabase_admin') THEN RETURN NEW; END IF;
  IF public.sitra_rol_actual() = 'ADMINISTRADOR' THEN RETURN NEW; END IF;
  IF OLD.id IS DISTINCT FROM auth.uid() OR public.sitra_rol_actual() IS NULL
     OR (to_jsonb(NEW) - 'fcm_token' - 'updated_at')
        IS DISTINCT FROM (to_jsonb(OLD) - 'fcm_token' - 'updated_at') THEN
    RAISE EXCEPTION 'Solo el administrador puede modificar el perfil, rol, áreas o estado.' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.sitra_proteger_perfil() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS hu002_proteger_perfil ON public.profiles;
CREATE TRIGGER hu002_proteger_perfil BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sitra_proteger_perfil();

-- Registrarse o usar un email que contenga "admin" no concede privilegios.
-- Los nuevos perfiles requieren activación y asignación por Administración.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO public.profiles(id, email, nombre, rol, areas_asignadas, activo)
  VALUES (NEW.id, NEW.email,
    COALESCE(NULLIF(btrim(NEW.raw_user_meta_data->>'nombre'), ''), split_part(NEW.email, '@', 1)),
    'ENFERMERIA', '{}'::TEXT[], false)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

-- Elimina las políticas anteriores de estas tablas para que ninguna política
-- permisiva residual pueda abrir de nuevo el acceso (las políticas SELECT se suman).
DO $$
DECLARE v_tabla TEXT; v_politica RECORD;
BEGIN
  FOREACH v_tabla IN ARRAY ARRAY[
    'profiles', 'areas', 'doctores', 'medicamentos', 'lotes', 'inventario_stock',
    'pedidos_abastecimiento', 'pedidos_abastecimiento_items', 'pedido_abastecimiento_despachos',
    'kits', 'kit_items', 'dispensaciones', 'dispensacion_items', 'auditoria_trazabilidad'
  ] LOOP
    IF to_regclass(format('public.%I', v_tabla)) IS NULL THEN
      RAISE EXCEPTION 'Falta la tabla %. Ejecuta primero la migración de recepción de pedidos.', v_tabla;
    END IF;
    FOR v_politica IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = v_tabla LOOP
      EXECUTE format('DROP POLICY %I ON public.%I', v_politica.policyname, v_tabla);
    END LOOP;
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', v_tabla);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon, authenticated', v_tabla);
    EXECUTE format('GRANT SELECT ON TABLE public.%I TO authenticated', v_tabla);
  END LOOP;
END;
$$;

GRANT UPDATE ON public.profiles TO authenticated;
GRANT INSERT, UPDATE ON public.areas, public.doctores, public.medicamentos,
  public.lotes, public.inventario_stock, public.kits, public.kit_items TO authenticated;
GRANT INSERT ON public.pedidos_abastecimiento, public.pedidos_abastecimiento_items,
  public.dispensaciones, public.dispensacion_items, public.auditoria_trazabilidad TO authenticated;
-- No se concede DELETE. Los pedidos emitidos y sus despachos solo cambian vía RPC.

CREATE POLICY hu002_perfiles_lectura ON public.profiles FOR SELECT TO authenticated USING (
  id = auth.uid() OR public.sitra_rol_actual() IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA', 'ALMACEN')
  OR (public.sitra_rol_actual() = 'ENFERMERIA' AND rol = 'ENFERMERIA'
      AND EXISTS (SELECT 1 FROM unnest(areas_asignadas) AS area(valor) WHERE public.sitra_tiene_area(area.valor)))
);
CREATE POLICY hu002_perfiles_actualizacion ON public.profiles FOR UPDATE TO authenticated
  USING (public.sitra_rol_actual() = 'ADMINISTRADOR' OR (id = auth.uid() AND public.sitra_rol_actual() IS NOT NULL))
  WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR' OR (id = auth.uid() AND public.sitra_rol_actual() IS NOT NULL));

CREATE POLICY hu002_areas_lectura ON public.areas FOR SELECT TO authenticated USING (public.sitra_rol_actual() IS NOT NULL);
CREATE POLICY hu002_areas_creacion ON public.areas FOR INSERT TO authenticated WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR');
CREATE POLICY hu002_areas_actualizacion ON public.areas FOR UPDATE TO authenticated USING (public.sitra_rol_actual() = 'ADMINISTRADOR') WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR');
CREATE POLICY hu002_doctores_lectura ON public.doctores FOR SELECT TO authenticated USING (public.sitra_rol_actual() IS NOT NULL);
CREATE POLICY hu002_doctores_creacion ON public.doctores FOR INSERT TO authenticated WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR');
CREATE POLICY hu002_doctores_actualizacion ON public.doctores FOR UPDATE TO authenticated USING (public.sitra_rol_actual() = 'ADMINISTRADOR') WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR');

CREATE POLICY hu002_medicamentos_lectura ON public.medicamentos FOR SELECT TO authenticated USING (public.sitra_rol_actual() IS NOT NULL);
CREATE POLICY hu002_medicamentos_creacion ON public.medicamentos FOR INSERT TO authenticated WITH CHECK (public.sitra_rol_actual() IN ('ADMINISTRADOR', 'ALMACEN'));
CREATE POLICY hu002_medicamentos_actualizacion ON public.medicamentos FOR UPDATE TO authenticated USING (public.sitra_rol_actual() IN ('ADMINISTRADOR', 'ALMACEN')) WITH CHECK (public.sitra_rol_actual() IN ('ADMINISTRADOR', 'ALMACEN'));
CREATE POLICY hu002_lotes_lectura ON public.lotes FOR SELECT TO authenticated USING (public.sitra_rol_actual() IS NOT NULL);
CREATE POLICY hu002_lotes_creacion ON public.lotes FOR INSERT TO authenticated WITH CHECK (public.sitra_rol_actual() IN ('ADMINISTRADOR', 'ALMACEN'));
CREATE POLICY hu002_lotes_actualizacion ON public.lotes FOR UPDATE TO authenticated USING (public.sitra_rol_actual() IN ('ADMINISTRADOR', 'ALMACEN')) WITH CHECK (public.sitra_rol_actual() IN ('ADMINISTRADOR', 'ALMACEN'));

CREATE POLICY hu002_inventario_lectura ON public.inventario_stock FOR SELECT TO authenticated USING (
  public.sitra_rol_actual() IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'ALMACEN', 'FARMACIA')
  OR (public.sitra_rol_actual() = 'ENFERMERIA'
      AND (area_codigo IN ('FARMACIA', 'ALMACEN') OR public.sitra_tiene_area(area_codigo)))
);
CREATE POLICY hu002_inventario_creacion ON public.inventario_stock FOR INSERT TO authenticated WITH CHECK (
  public.sitra_rol_actual() = 'ADMINISTRADOR'
  OR (public.sitra_rol_actual() = 'ALMACEN' AND area_codigo IN ('ALMACEN', 'FARMACIA'))
);
CREATE POLICY hu002_inventario_actualizacion ON public.inventario_stock FOR UPDATE TO authenticated USING (
  public.sitra_rol_actual() = 'ADMINISTRADOR'
  OR (public.sitra_rol_actual() = 'ALMACEN' AND area_codigo IN ('ALMACEN', 'FARMACIA'))
) WITH CHECK (
  public.sitra_rol_actual() = 'ADMINISTRADOR'
  OR (public.sitra_rol_actual() = 'ALMACEN' AND area_codigo IN ('ALMACEN', 'FARMACIA'))
);

CREATE POLICY hu002_pedidos_lectura ON public.pedidos_abastecimiento FOR SELECT TO authenticated USING (
  public.sitra_rol_actual() IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA', 'ALMACEN')
);
CREATE POLICY hu002_pedidos_creacion ON public.pedidos_abastecimiento FOR INSERT TO authenticated WITH CHECK (
  public.sitra_rol_actual() IN ('FARMACIA', 'ADMINISTRADOR') AND solicitante_id = auth.uid()
  AND area_origen = 'FARMACIA' AND area_destino = 'ALMACEN' AND estado = 'PENDIENTE'
  AND NOT confirmado_almacen AND NOT confirmado_farmacia
  AND responsable_almacen_id IS NULL AND responsable_farmacia_id IS NULL
  AND cancelado_por IS NULL AND rechazado_por IS NULL
);
CREATE POLICY hu002_pedido_items_lectura ON public.pedidos_abastecimiento_items FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.pedidos_abastecimiento p WHERE p.id = pedido_id)
);
CREATE POLICY hu002_pedido_items_creacion ON public.pedidos_abastecimiento_items FOR INSERT TO authenticated WITH CHECK (
  public.sitra_rol_actual() IN ('FARMACIA', 'ADMINISTRADOR') AND cantidad_despachada = 0
  AND cantidad_recibida IS NULL AND lote_id IS NULL
  AND EXISTS (SELECT 1 FROM public.pedidos_abastecimiento p WHERE p.id = pedido_id
              AND p.solicitante_id = auth.uid() AND p.estado = 'PENDIENTE')
);
CREATE POLICY hu002_despachos_lectura ON public.pedido_abastecimiento_despachos FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i WHERE i.id = item_id)
);

CREATE POLICY hu002_kits_lectura ON public.kits FOR SELECT TO authenticated USING (
  public.sitra_rol_actual() IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA', 'ALMACEN')
  OR (public.sitra_rol_actual() = 'ENFERMERIA' AND public.sitra_tiene_area(area_destino))
);
CREATE POLICY hu002_kits_creacion ON public.kits FOR INSERT TO authenticated WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR');
CREATE POLICY hu002_kits_actualizacion ON public.kits FOR UPDATE TO authenticated USING (public.sitra_rol_actual() = 'ADMINISTRADOR') WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR');
CREATE POLICY hu002_kit_items_lectura ON public.kit_items FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.kits k WHERE k.id = kit_id));
CREATE POLICY hu002_kit_items_creacion ON public.kit_items FOR INSERT TO authenticated WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR');
CREATE POLICY hu002_kit_items_actualizacion ON public.kit_items FOR UPDATE TO authenticated USING (public.sitra_rol_actual() = 'ADMINISTRADOR') WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR');

CREATE POLICY hu002_fichas_lectura ON public.dispensaciones FOR SELECT TO authenticated USING (
  public.sitra_rol_actual() IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA')
  OR (public.sitra_rol_actual() = 'ENFERMERIA' AND public.sitra_tiene_area(area_origen))
);
CREATE POLICY hu002_fichas_creacion ON public.dispensaciones FOR INSERT TO authenticated WITH CHECK (
  solicitado_por = auth.uid() AND estado = 'SOLICITADO' AND entregado_por IS NULL AND fecha_entrega IS NULL
  AND (public.sitra_rol_actual() = 'ADMINISTRADOR'
       OR (public.sitra_rol_actual() = 'ENFERMERIA' AND public.sitra_tiene_area(area_origen)))
);
CREATE POLICY hu002_ficha_items_lectura ON public.dispensacion_items FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.dispensaciones d WHERE d.id = dispensacion_id));
CREATE POLICY hu002_ficha_items_creacion ON public.dispensacion_items FOR INSERT TO authenticated WITH CHECK (
  cantidad_entregada = 0 AND public.sitra_rol_actual() IN ('ADMINISTRADOR', 'ENFERMERIA')
  AND EXISTS (SELECT 1 FROM public.dispensaciones d WHERE d.id = dispensacion_id
              AND d.solicitado_por = auth.uid() AND d.estado = 'SOLICITADO')
);
-- La preparación, entrega y anulación de fichas se incorporarán con RPC en sus HU.

CREATE POLICY hu002_auditoria_lectura ON public.auditoria_trazabilidad FOR SELECT TO authenticated USING (
  public.sitra_rol_actual() IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA')
  OR (public.sitra_rol_actual() = 'ALMACEN' AND (
    usuario_id = auth.uid() OR area_origen = 'ALMACEN' OR area_destino = 'ALMACEN'
    OR (tabla_referencia = 'pedidos_abastecimiento' AND EXISTS (
      SELECT 1 FROM public.pedidos_abastecimiento p WHERE p.id = entidad_referencia_id))
  ))
  OR (public.sitra_rol_actual() = 'ENFERMERIA' AND (
    usuario_id = auth.uid() OR public.sitra_tiene_area(area_origen) OR public.sitra_tiene_area(area_destino)
  ))
);
CREATE POLICY hu002_auditoria_creacion ON public.auditoria_trazabilidad FOR INSERT TO authenticated WITH CHECK (
  usuario_id = auth.uid() AND public.sitra_rol_actual() IN ('ADMINISTRADOR', 'FARMACIA', 'ALMACEN')
);
-- Ningún rol de la aplicación recibe UPDATE/DELETE sobre auditoría.

-- Extiende únicamente el control de rol de la RPC existente: Administración
-- puede operar los módulos, pero conserva las mismas reglas de estado y stock.
DO $$
DECLARE v_funcion TEXT;
  v_anterior TEXT := $viejo$IF p_accion IN ('CANCELAR', 'RECIBIR') AND v_rol <> 'FARMACIA'
     OR p_accion IN ('TOMAR', 'RECHAZAR', 'DESPACHAR') AND v_rol <> 'ALMACEN' THEN$viejo$;
  v_nuevo TEXT := $nuevo$IF v_rol <> 'ADMINISTRADOR' AND (
     p_accion IN ('CANCELAR', 'RECIBIR') AND v_rol <> 'FARMACIA'
     OR p_accion IN ('TOMAR', 'RECHAZAR', 'DESPACHAR') AND v_rol <> 'ALMACEN') THEN$nuevo$;
BEGIN
  SELECT pg_get_functiondef(to_regprocedure('public.procesar_pedido_abastecimiento(uuid,text,text,jsonb,text,text)')) INTO v_funcion;
  IF v_funcion IS NULL THEN RAISE EXCEPTION 'Falta la función de pedidos. Ejecuta primero la migración de recepción.'; END IF;
  IF position(v_anterior IN v_funcion) > 0 THEN
    EXECUTE replace(v_funcion, v_anterior, v_nuevo);
  ELSIF position(v_nuevo IN v_funcion) = 0 THEN
    RAISE EXCEPTION 'La función de pedidos tiene otra versión. Revísala antes de aplicar HU-002.';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;

-- ============================================================================
-- 18. HU-012: CATÁLOGOS ADMINISTRATIVOS Y CONTRATO PARA HU-020
-- Sincronizado con migracion_hu012_catalogos_2026_10_15.sql.
-- ============================================================================
-- HU-012: Áreas, seguros y convenios. Ejecutar DESPUÉS de HU-002.
-- No modifica importes de fichas históricas ni implementa HU-020/021/022.
-- El código visible AREA-001 es editable. areas.codigo se conserva como alias
-- operativo para no romper el flujo existente FARMACIA/ALMACEN.
BEGIN;

CREATE SEQUENCE IF NOT EXISTS public.areas_codigo_interno_seq;
ALTER TABLE public.areas
  ADD COLUMN IF NOT EXISTS codigo_interno TEXT,
  ADD COLUMN IF NOT EXISTS administra_stock BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
DO $$
DECLARE v_id UUID; v_numero TEXT; v_codigo TEXT;
BEGIN
  FOR v_id IN SELECT id FROM public.areas WHERE codigo_interno IS NULL ORDER BY created_at,id LOOP
    LOOP
      v_numero:=nextval('public.areas_codigo_interno_seq')::TEXT;
      v_codigo:='AREA-'||lpad(v_numero,greatest(3,length(v_numero)),'0');
      EXIT WHEN NOT EXISTS (SELECT 1 FROM public.areas WHERE upper(codigo_interno)=v_codigo);
    END LOOP;
    UPDATE public.areas SET codigo_interno=v_codigo WHERE id=v_id;
  END LOOP;
END;
$$;
ALTER TABLE public.areas ALTER COLUMN codigo_interno SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_areas_codigo_interno ON public.areas (upper(btrim(codigo_interno)));
UPDATE public.areas a SET administra_stock = true
WHERE a.codigo IN ('ALMACEN','FARMACIA') OR EXISTS (
  SELECT 1 FROM public.inventario_stock s WHERE s.area_codigo = a.codigo AND s.cantidad > 0);

-- Campos solicitados para la próxima gestión de usuarios. No altera sus roles.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS cargo TEXT,
  ADD COLUMN IF NOT EXISTS correo_drive TEXT;

-- Referencias estables por UUID para nuevas asignaciones. Se conserva el array
-- existente por compatibilidad; el trigger lo sincroniza al guardar perfiles.
CREATE TABLE IF NOT EXISTS public.profile_areas (
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  area_id UUID NOT NULL REFERENCES public.areas(id) ON DELETE RESTRICT,
  PRIMARY KEY (profile_id, area_id)
);
INSERT INTO public.profile_areas(profile_id, area_id)
SELECT DISTINCT p.id, a.id FROM public.profiles p
CROSS JOIN LATERAL unnest(p.areas_asignadas) x(valor)
JOIN public.areas a ON upper(btrim(x.valor)) = upper(a.codigo)
  OR lower(btrim(x.valor)) = lower(btrim(a.nombre))
  OR upper(btrim(x.valor)) = upper(a.codigo_interno)
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS public.financiamientos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL CHECK (length(btrim(nombre)) > 0),
  descripcion TEXT,
  tipo TEXT NOT NULL CHECK (tipo IN ('SEGURO','CONVENIO')),
  porcentaje_descuento NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (porcentaje_descuento BETWEEN 0 AND 100),
  activo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_financiamientos_tipo_nombre
  ON public.financiamientos(tipo, lower(btrim(nombre)));
CREATE TABLE IF NOT EXISTS public.financiamiento_medicamentos (
  financiamiento_id UUID NOT NULL REFERENCES public.financiamientos(id) ON DELETE CASCADE,
  medicamento_id UUID NOT NULL REFERENCES public.medicamentos(id) ON DELETE RESTRICT,
  PRIMARY KEY (financiamiento_id, medicamento_id)
);

-- Preparación de la ficha para HU-003: Particular no es una tercera fila del catálogo.
ALTER TABLE public.dispensaciones
  ADD COLUMN IF NOT EXISTS tipo_atencion TEXT NOT NULL DEFAULT 'PARTICULAR'
    CHECK (tipo_atencion IN ('PARTICULAR','SEGURO','CONVENIO')),
  ADD COLUMN IF NOT EXISTS financiamiento_id UUID REFERENCES public.financiamientos(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS financiamiento_nombre_aplicado TEXT;
-- Se completarán al registrar/entregar ítems en HU-003/HU-010; NULL significa
-- histórico sin valoración registrada, nunca costo o precio cero.
ALTER TABLE public.dispensacion_items
  ADD COLUMN IF NOT EXISTS precio_kairos_aplicado NUMERIC(10,2) CHECK (precio_kairos_aplicado >= 0),
  ADD COLUMN IF NOT EXISTS porcentaje_descuento_aplicado NUMERIC(5,2) CHECK (porcentaje_descuento_aplicado BETWEEN 0 AND 100),
  ADD COLUMN IF NOT EXISTS precio_unitario_aplicado NUMERIC(10,2) CHECK (precio_unitario_aplicado >= 0);
ALTER TABLE public.dispensaciones DROP CONSTRAINT IF EXISTS hu012_ficha_financiamiento_check;
ALTER TABLE public.dispensaciones ADD CONSTRAINT hu012_ficha_financiamiento_check CHECK (
  (tipo_atencion = 'PARTICULAR' AND financiamiento_id IS NULL)
  OR (tipo_atencion IN ('SEGURO','CONVENIO') AND financiamiento_id IS NOT NULL));

-- Trigger de fichas: valida un área habilitada al crear/cambiar el área y un
-- seguro/convenio habilitado del tipo seleccionado al crear/cambiar cobertura.
-- Guarda el nombre aplicado; no vuelve a validar una selección histórica sin cambios.
CREATE OR REPLACE FUNCTION public.hu012_validar_ficha()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_area public.areas%ROWTYPE; v_fin public.financiamientos%ROWTYPE;
BEGIN
  IF TG_OP = 'INSERT' OR NEW.area_origen IS DISTINCT FROM OLD.area_origen THEN
    SELECT * INTO v_area FROM public.areas WHERE codigo = NEW.area_origen FOR SHARE;
    IF NOT FOUND OR NOT v_area.activo THEN RAISE EXCEPTION 'Selecciona un área habilitada.'; END IF;
  END IF;
  IF NEW.financiamiento_id IS NOT NULL AND (TG_OP = 'INSERT'
     OR NEW.financiamiento_id IS DISTINCT FROM OLD.financiamiento_id
     OR NEW.tipo_atencion IS DISTINCT FROM OLD.tipo_atencion) THEN
    SELECT * INTO v_fin FROM public.financiamientos WHERE id = NEW.financiamiento_id FOR SHARE;
    IF NOT FOUND OR NOT v_fin.activo OR v_fin.tipo <> NEW.tipo_atencion THEN
      RAISE EXCEPTION 'El seguro/convenio debe estar habilitado y coincidir con el tipo de atención.';
    END IF;
    NEW.financiamiento_nombre_aplicado:=v_fin.nombre;
  ELSIF NEW.financiamiento_id IS NULL THEN
    NEW.financiamiento_nombre_aplicado:=NULL;
  END IF;
  RETURN NEW;
END;
$$;

-- Contrato para futuras fichas: calcula Kairos sin descuento si no hay cobertura.
-- No factura ni escribe ítems; HU-003/HU-010 guardarán el resultado como snapshot.
-- Consulta de valoración para futuras fichas: recibe medicamento y financiamiento
-- opcional, lee Kairos y verifica si ese medicamento pertenece a la cobertura.
-- Devuelve un JSON con base, porcentaje efectivo y precio redondeado, sin escribir
-- ni cobrar. Sin cobertura/Particular el porcentaje es cero; Kairos ausente se rechaza.
CREATE OR REPLACE FUNCTION public.cotizar_medicamento_hu012(p_medicamento_id UUID,p_financiamiento_id UUID DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_base NUMERIC; v_porcentaje NUMERIC:=0; v_fin public.financiamientos%ROWTYPE;
BEGIN
  IF public.sitra_rol_actual() IS NULL THEN RAISE EXCEPTION 'Inicia sesión para consultar precios.' USING ERRCODE='42501'; END IF;
  SELECT precio_kairos INTO v_base FROM public.medicamentos WHERE id=p_medicamento_id AND activo;
  IF NOT FOUND THEN RAISE EXCEPTION 'El medicamento no está disponible.'; END IF;
  IF v_base IS NULL OR v_base<0 THEN RAISE EXCEPTION 'Registra un precio Kairos válido antes de valorizar el medicamento.'; END IF;
  IF p_financiamiento_id IS NOT NULL THEN
    SELECT * INTO v_fin FROM public.financiamientos WHERE id=p_financiamiento_id AND activo;
    IF NOT FOUND THEN RAISE EXCEPTION 'Selecciona un seguro/convenio habilitado.'; END IF;
    IF EXISTS (SELECT 1 FROM public.financiamiento_medicamentos WHERE financiamiento_id=p_financiamiento_id AND medicamento_id=p_medicamento_id) THEN
      v_porcentaje:=v_fin.porcentaje_descuento;
    END IF;
  END IF;
  RETURN jsonb_build_object('precio_kairos_aplicado',v_base,'porcentaje_descuento_aplicado',v_porcentaje,
    'precio_unitario_aplicado',round(v_base*(1-v_porcentaje/100),2));
END;
$$;
DROP TRIGGER IF EXISTS hu012_validar_ficha ON public.dispensaciones;
CREATE TRIGGER hu012_validar_ficha BEFORE INSERT OR UPDATE ON public.dispensaciones
FOR EACH ROW EXECUTE FUNCTION public.hu012_validar_ficha();

-- Trigger de pedidos/kits: consulta las áreas y bloquea nuevas selecciones de
-- áreas deshabilitadas. Actualizaciones sin cambio de área pueden continuar,
-- para que deshabilitar no interrumpa pedidos anteriores.
CREATE OR REPLACE FUNCTION public.hu012_validar_area_nueva()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_codigo TEXT; v_anterior TEXT;
BEGIN
  IF TG_TABLE_NAME = 'pedidos_abastecimiento' THEN
    IF TG_OP = 'INSERT' OR NEW.area_origen IS DISTINCT FROM OLD.area_origen
      OR NEW.area_destino IS DISTINCT FROM OLD.area_destino THEN
      PERFORM id FROM public.areas WHERE codigo IN (NEW.area_origen,NEW.area_destino) ORDER BY id FOR SHARE;
      IF (SELECT count(*) FROM public.areas WHERE codigo IN (NEW.area_origen,NEW.area_destino) AND activo) <> 2 THEN
        RAISE EXCEPTION 'Las áreas del nuevo pedido deben estar habilitadas.';
      END IF;
    END IF;
  ELSE
    v_codigo := NEW.area_destino;
    IF TG_OP = 'UPDATE' THEN v_anterior := OLD.area_destino; END IF;
    IF TG_OP = 'INSERT' OR v_codigo IS DISTINCT FROM v_anterior THEN
      PERFORM id FROM public.areas WHERE codigo = v_codigo AND activo FOR SHARE;
      IF NOT FOUND THEN RAISE EXCEPTION 'El área destino debe estar habilitada.'; END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS hu012_area_pedido ON public.pedidos_abastecimiento;
CREATE TRIGGER hu012_area_pedido BEFORE INSERT OR UPDATE ON public.pedidos_abastecimiento
FOR EACH ROW EXECUTE FUNCTION public.hu012_validar_area_nueva();
DROP TRIGGER IF EXISTS hu012_area_kit ON public.kits;
CREATE TRIGGER hu012_area_kit BEFORE INSERT OR UPDATE ON public.kits
FOR EACH ROW EXECUTE FUNCTION public.hu012_validar_area_nueva();

-- Un ingreso directo nuevo no utiliza un área deshabilitada. Las RPC de
-- pedidos, que ya validan su transición, pueden cerrar operaciones anteriores.
-- Trigger de inventario: comprueba el área en ingresos/asignaciones directas de
-- usuarios autenticados. Las RPC autorizadas pueden finalizar operaciones previas.
-- No borra stock ni modifica cantidades; devuelve NEW o rechaza la operación.
CREATE OR REPLACE FUNCTION public.hu012_validar_stock_area()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF current_user = 'authenticated' AND (TG_OP='INSERT'
    OR NEW.area_codigo IS DISTINCT FROM OLD.area_codigo OR NEW.cantidad>OLD.cantidad) THEN
    PERFORM id FROM public.areas WHERE codigo=NEW.area_codigo AND activo;
    IF NOT FOUND THEN RAISE EXCEPTION 'No se admiten ingresos nuevos en un área deshabilitada.'; END IF;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS hu012_stock_area ON public.inventario_stock;
CREATE TRIGGER hu012_stock_area BEFORE INSERT OR UPDATE ON public.inventario_stock
FOR EACH ROW EXECUTE FUNCTION public.hu012_validar_stock_area();

-- Trigger de perfiles: resuelve áreas por alias, código visible o nombre;
-- rechaza nuevas asignaciones desconocidas/deshabilitadas y sincroniza la tabla
-- profile_areas por UUID. Conserva asignaciones anteriores para no perder historial.
CREATE OR REPLACE FUNCTION public.hu012_sincronizar_areas_perfil()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_token TEXT; v_area public.areas%ROWTYPE; v_previas TEXT[] := '{}';
BEGIN
  IF TG_OP = 'UPDATE' THEN v_previas := COALESCE(OLD.areas_asignadas,'{}'); END IF;
  FOR v_token IN SELECT unnest(COALESCE(NEW.areas_asignadas,'{}')) LOOP
    SELECT * INTO v_area FROM public.areas
      WHERE upper(codigo) = upper(btrim(v_token)) OR upper(codigo_interno) = upper(btrim(v_token))
        OR lower(nombre) = lower(btrim(v_token)) ORDER BY id LIMIT 1 FOR SHARE;
    IF NOT FOUND THEN
      IF NOT (v_token = ANY(v_previas)) THEN RAISE EXCEPTION 'Área desconocida: %', v_token; END IF;
    ELSE
      IF NOT v_area.activo AND NOT EXISTS (
        SELECT 1 FROM public.profile_areas WHERE profile_id = NEW.id AND area_id = v_area.id)
        AND NOT (v_token = ANY(v_previas)) THEN
        RAISE EXCEPTION 'No se puede asignar un área deshabilitada: %', v_area.nombre;
      END IF;
    END IF;
  END LOOP;
  DELETE FROM public.profile_areas WHERE profile_id = NEW.id;
  INSERT INTO public.profile_areas(profile_id,area_id)
  SELECT DISTINCT NEW.id,a.id FROM unnest(COALESCE(NEW.areas_asignadas,'{}')) x(valor)
  JOIN public.areas a ON upper(btrim(x.valor)) = upper(a.codigo)
    OR upper(btrim(x.valor)) = upper(a.codigo_interno) OR lower(btrim(x.valor)) = lower(a.nombre)
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS hu012_areas_perfil ON public.profiles;
CREATE TRIGGER hu012_areas_perfil AFTER INSERT OR UPDATE OF areas_asignadas ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.hu012_sincronizar_areas_perfil();

-- Consulta auxiliar de RLS: devuelve si el perfil autenticado y activo tiene
-- asignada el área consultada. No exige que el área siga habilitada, porque
-- las asignaciones anteriores deben conservar acceso a su información histórica.
CREATE OR REPLACE FUNCTION public.sitra_tiene_area(p_area TEXT)
RETURNS BOOLEAN LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (SELECT 1 FROM public.profiles p JOIN public.profile_areas pa ON pa.profile_id=p.id
    JOIN public.areas a ON a.id=pa.area_id WHERE p.id=auth.uid() AND p.activo
    AND (a.codigo=p_area OR a.codigo_interno=p_area OR lower(a.nombre)=lower(btrim(p_area))))
  OR EXISTS (SELECT 1 FROM public.profiles p CROSS JOIN LATERAL unnest(p.areas_asignadas) x(valor)
    WHERE p.id=auth.uid() AND p.activo AND lower(btrim(x.valor))=lower(btrim(p_area)));
$$;

-- Todas las escrituras de HU-012 pasan por esta operación atómica y auditada.
-- RPC de escritura: recibe entidad (AREA/FINANCIAMIENTO), acción, ID opcional y
-- JSON de campos. Exige Administrador activo, serializa cambios, valida unicidad
-- y comprueba asociaciones antes de eliminar. Guarda cobertura y auditoría en la
-- misma transacción; devuelve el UUID afectado o lanza una excepción.
CREATE OR REPLACE FUNCTION public.administrar_catalogo_hu012(
  p_entidad TEXT, p_accion TEXT, p_id UUID DEFAULT NULL, p_datos JSONB DEFAULT '{}'::JSONB
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_id UUID := p_id; v_area public.areas%ROWTYPE; v_fin public.financiamientos%ROWTYPE;
  v_antes JSONB; v_despues JSONB; v_codigo TEXT; v_nombre TEXT; v_tipo TEXT;
  v_porcentaje NUMERIC; v_meds JSONB; v_cobertura JSONB; v_numero TEXT;
BEGIN
  IF public.sitra_rol_actual() IS DISTINCT FROM 'ADMINISTRADOR' THEN
    RAISE EXCEPTION 'Solo Administrador puede gestionar estos catálogos.' USING ERRCODE='42501';
  END IF;
  IF p_entidad NOT IN ('AREA','FINANCIAMIENTO') OR p_entidad IS NULL
    OR p_accion NOT IN ('GUARDAR','ESTADO','ELIMINAR') OR p_accion IS NULL THEN
    RAISE EXCEPTION 'Operación de catálogo inválida.';
  END IF;
  -- Serializa cambios del catálogo y evita renombres duplicados concurrentes.
  PERFORM pg_advisory_xact_lock(12012,1);
  IF p_entidad='AREA' THEN
    IF p_id IS NOT NULL THEN
      SELECT * INTO v_area FROM public.areas WHERE id=p_id FOR UPDATE;
      IF NOT FOUND THEN RAISE EXCEPTION 'El área ya no existe.'; END IF;
      v_antes:=to_jsonb(v_area);
    ELSIF p_accion<>'GUARDAR' THEN RAISE EXCEPTION 'Selecciona un área.';
    END IF;
    IF p_accion='ELIMINAR' THEN
      IF v_area.codigo IN ('FARMACIA','ALMACEN')
        OR EXISTS (SELECT 1 FROM public.inventario_stock WHERE area_codigo=v_area.codigo)
        OR EXISTS (SELECT 1 FROM public.pedidos_abastecimiento WHERE area_origen=v_area.codigo OR area_destino=v_area.codigo)
        OR EXISTS (SELECT 1 FROM public.dispensaciones WHERE area_origen=v_area.codigo)
        OR EXISTS (SELECT 1 FROM public.kits WHERE area_destino=v_area.codigo)
        OR EXISTS (SELECT 1 FROM public.auditoria_trazabilidad WHERE area_origen=v_area.codigo OR area_destino=v_area.codigo)
        OR EXISTS (SELECT 1 FROM public.profile_areas WHERE area_id=p_id)
        OR EXISTS (SELECT 1 FROM public.profiles p, unnest(p.areas_asignadas) x(valor)
          WHERE lower(btrim(x.valor)) IN (lower(v_area.codigo),lower(v_area.codigo_interno),lower(v_area.nombre))) THEN
        RAISE EXCEPTION 'El área tiene asociaciones o es necesaria para abastecimiento. Puedes deshabilitarla conservando su historial.';
      END IF;
      DELETE FROM public.areas WHERE id=p_id;
    ELSIF p_accion='ESTADO' THEN
      IF jsonb_typeof(p_datos->'activo') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Estado inválido.'; END IF;
      UPDATE public.areas SET activo=(p_datos->>'activo')::BOOLEAN, updated_at=now() WHERE id=p_id RETURNING to_jsonb(areas.*) INTO v_despues;
    ELSE
      v_nombre:=btrim(p_datos->>'nombre');
      IF v_nombre IS NULL OR v_nombre='' THEN RAISE EXCEPTION 'Escribe el nombre del área.'; END IF;
      v_codigo:=upper(btrim(COALESCE(p_datos->>'codigo_interno','')));
      IF v_codigo='' AND p_id IS NULL THEN
        LOOP
          v_numero:=nextval('public.areas_codigo_interno_seq')::TEXT;
          v_codigo:='AREA-'||lpad(v_numero,greatest(3,length(v_numero)),'0');
          EXIT WHEN NOT EXISTS (SELECT 1 FROM public.areas WHERE upper(codigo_interno)=v_codigo);
        END LOOP;
      END IF;
      IF v_codigo !~ '^AREA-[0-9]{3,}$' THEN RAISE EXCEPTION 'Usa un código como AREA-001.'; END IF;
      IF EXISTS (SELECT 1 FROM public.areas WHERE upper(codigo_interno)=v_codigo AND id IS DISTINCT FROM p_id) THEN
        RAISE EXCEPTION 'Ese código interno ya está registrado.';
      END IF;
      IF EXISTS (SELECT 1 FROM public.areas WHERE lower(btrim(nombre))=lower(v_nombre) AND id IS DISTINCT FROM p_id) THEN
        RAISE EXCEPTION 'Ya existe un área con ese nombre.';
      END IF;
      IF p_id IS NULL THEN
        v_id:=gen_random_uuid();
        INSERT INTO public.areas(id,codigo,codigo_interno,nombre,descripcion,administra_stock)
          VALUES(v_id,'AREA_'||replace(v_id::TEXT,'-',''),v_codigo,v_nombre,NULLIF(btrim(p_datos->>'descripcion'),''),COALESCE((p_datos->>'administra_stock')::BOOLEAN,false))
          RETURNING to_jsonb(areas.*) INTO v_despues;
      ELSE
        UPDATE public.areas SET codigo_interno=v_codigo,nombre=v_nombre,
          descripcion=NULLIF(btrim(p_datos->>'descripcion'),''),
          administra_stock=COALESCE((p_datos->>'administra_stock')::BOOLEAN,administra_stock),updated_at=now()
          WHERE id=p_id RETURNING to_jsonb(areas.*) INTO v_despues;
        -- Cambiar el nombre/código visible no pierde asignaciones históricas.
        UPDATE public.profiles p SET areas_asignadas=ARRAY(
          SELECT CASE WHEN lower(btrim(x)) IN (lower(v_area.nombre),lower(v_area.codigo_interno)) THEN v_area.codigo ELSE x END
          FROM unnest(p.areas_asignadas) x)
        WHERE EXISTS (SELECT 1 FROM unnest(p.areas_asignadas) x WHERE lower(btrim(x)) IN (lower(v_area.nombre),lower(v_area.codigo_interno)));
      END IF;
    END IF;
  ELSE
    IF p_id IS NOT NULL THEN
      SELECT * INTO v_fin FROM public.financiamientos WHERE id=p_id FOR UPDATE;
      IF NOT FOUND THEN RAISE EXCEPTION 'El seguro/convenio ya no existe.'; END IF;
      SELECT COALESCE(jsonb_agg(medicamento_id ORDER BY medicamento_id),'[]'::JSONB) INTO v_cobertura
        FROM public.financiamiento_medicamentos WHERE financiamiento_id=p_id;
      v_antes:=to_jsonb(v_fin)||jsonb_build_object('medicamentos',v_cobertura);
    ELSIF p_accion<>'GUARDAR' THEN RAISE EXCEPTION 'Selecciona un seguro/convenio.';
    END IF;
    IF p_accion='ELIMINAR' THEN
      IF EXISTS (SELECT 1 FROM public.dispensaciones WHERE financiamiento_id=p_id) THEN
        RAISE EXCEPTION 'Tiene fichas asociadas. Deshabilítalo para conservar el historial.';
      END IF;
      DELETE FROM public.financiamientos WHERE id=p_id;
    ELSIF p_accion='ESTADO' THEN
      IF jsonb_typeof(p_datos->'activo') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Estado inválido.'; END IF;
      UPDATE public.financiamientos SET activo=(p_datos->>'activo')::BOOLEAN,updated_at=now() WHERE id=p_id
        RETURNING to_jsonb(financiamientos.*) INTO v_despues;
      v_despues:=v_despues||jsonb_build_object('medicamentos',v_cobertura);
    ELSE
      v_nombre:=btrim(p_datos->>'nombre'); v_tipo:=p_datos->>'tipo';
      v_porcentaje:=(p_datos->>'porcentaje_descuento')::NUMERIC;
      v_meds:=p_datos->'medicamentos';
      IF v_nombre IS NULL OR v_nombre='' OR v_tipo IS NULL OR v_tipo NOT IN ('SEGURO','CONVENIO')
        OR v_porcentaje IS NULL OR v_porcentaje<0 OR v_porcentaje>100
        OR jsonb_typeof(v_meds) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Revisa nombre, tipo, descuento y cobertura.'; END IF;
      IF EXISTS (SELECT 1 FROM public.financiamientos WHERE tipo=v_tipo AND lower(btrim(nombre))=lower(v_nombre) AND id IS DISTINCT FROM p_id) THEN
        RAISE EXCEPTION 'Ya existe ese nombre en el tipo seleccionado.';
      END IF;
      IF EXISTS (SELECT 1 FROM jsonb_array_elements_text(v_meds) x(id)
        WHERE NOT EXISTS (SELECT 1 FROM public.medicamentos m WHERE m.id=x.id::UUID)) THEN RAISE EXCEPTION 'Hay medicamentos que ya no existen.'; END IF;
      IF p_id IS NULL THEN
        INSERT INTO public.financiamientos(nombre,descripcion,tipo,porcentaje_descuento)
        VALUES(v_nombre,NULLIF(btrim(p_datos->>'descripcion'),''),v_tipo,round(v_porcentaje,2)) RETURNING id INTO v_id;
      ELSE
        UPDATE public.financiamientos SET nombre=v_nombre,descripcion=NULLIF(btrim(p_datos->>'descripcion'),''),
          tipo=v_tipo,porcentaje_descuento=round(v_porcentaje,2),updated_at=now() WHERE id=p_id;
      END IF;
      DELETE FROM public.financiamiento_medicamentos WHERE financiamiento_id=v_id;
      INSERT INTO public.financiamiento_medicamentos(financiamiento_id,medicamento_id)
        SELECT DISTINCT v_id,x.id::UUID FROM jsonb_array_elements_text(v_meds) x(id);
      SELECT to_jsonb(f.*)||jsonb_build_object('medicamentos',v_meds) INTO v_despues FROM public.financiamientos f WHERE id=v_id;
    END IF;
  END IF;
  INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,usuario_id,estado_anterior,estado_nuevo,descripcion)
    VALUES('CATALOGO_'||p_accion,v_id,CASE WHEN p_entidad='AREA' THEN 'areas' ELSE 'financiamientos' END,
      auth.uid(),v_antes,v_despues,'Administración de catálogo: '||p_entidad);
  RETURN v_id;
END;
$$;

ALTER TABLE public.profile_areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financiamientos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financiamiento_medicamentos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS hu012_asignaciones_lectura ON public.profile_areas;
CREATE POLICY hu012_asignaciones_lectura ON public.profile_areas FOR SELECT TO authenticated
  USING (profile_id=auth.uid() OR public.sitra_rol_actual()='ADMINISTRADOR');
DROP POLICY IF EXISTS hu012_financiamientos_lectura ON public.financiamientos;
CREATE POLICY hu012_financiamientos_lectura ON public.financiamientos FOR SELECT TO authenticated
  USING (public.sitra_rol_actual() IS NOT NULL);
DROP POLICY IF EXISTS hu012_cobertura_lectura ON public.financiamiento_medicamentos;
CREATE POLICY hu012_cobertura_lectura ON public.financiamiento_medicamentos FOR SELECT TO authenticated
  USING (public.sitra_rol_actual() IS NOT NULL);
REVOKE ALL ON public.profile_areas,public.financiamientos,public.financiamiento_medicamentos FROM anon,authenticated;
GRANT SELECT ON public.profile_areas,public.financiamientos,public.financiamiento_medicamentos TO authenticated;
REVOKE INSERT,UPDATE,DELETE ON public.areas FROM authenticated;
REVOKE ALL ON SEQUENCE public.areas_codigo_interno_seq FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.administrar_catalogo_hu012(TEXT,TEXT,UUID,JSONB) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.administrar_catalogo_hu012(TEXT,TEXT,UUID,JSONB) TO authenticated;
REVOKE ALL ON FUNCTION public.cotizar_medicamento_hu012(UUID,UUID) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.cotizar_medicamento_hu012(UUID,UUID) TO authenticated;
REVOKE ALL ON FUNCTION public.hu012_validar_ficha(), public.hu012_validar_area_nueva(),public.hu012_sincronizar_areas_perfil() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.hu012_validar_stock_area() FROM PUBLIC,anon,authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;

-- ============================================================================
-- 19. HU-020: ESTRUCTURA Y CONSULTA DE USUARIOS (la habilitacion, alta y edicion estan en la seccion 20)
-- Sincronizado con migracion_hu020_estructura_usuarios_2026_10_15.sql.
-- ============================================================================
-- HU-020: estructura y consulta administrativa de usuarios.
-- Ejecutar después de migracion_hu012_catalogos_2026_10_15.sql.
-- No crea cuentas ni cambia credenciales. Supabase Auth conserva las contraseñas.
BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS nombre_usuario TEXT,
  ADD COLUMN IF NOT EXISTS nombres TEXT,
  ADD COLUMN IF NOT EXISTS apellidos TEXT;

-- Conserva nombre (nombre completo actual) sin intentar adivinar apellidos.
-- Asigna identificadores únicos a perfiles anteriores a esta estructura.
DO $$
DECLARE v_perfil RECORD; v_base TEXT; v_candidato TEXT; v_intento INTEGER;
BEGIN
  FOR v_perfil IN SELECT id,email FROM public.profiles WHERE nombre_usuario IS NULL ORDER BY created_at,id LOOP
    v_base:=left(regexp_replace(lower(split_part(COALESCE(v_perfil.email,''),'@',1)), '[^a-z0-9_.-]','','g'),24);
    IF length(v_base)<3 THEN v_base:='usuario'; END IF;
    v_candidato:=v_base; v_intento:=0;
    WHILE EXISTS (SELECT 1 FROM public.profiles WHERE lower(nombre_usuario)=v_candidato AND id<>v_perfil.id) LOOP
      v_intento:=v_intento+1;
      v_candidato:=left(v_base,24)||'_'||v_intento::TEXT;
    END LOOP;
    UPDATE public.profiles SET nombre_usuario=v_candidato WHERE id=v_perfil.id;
  END LOOP;
END;
$$;
CREATE UNIQUE INDEX IF NOT EXISTS uq_profiles_nombre_usuario
  ON public.profiles(lower(btrim(nombre_usuario))) WHERE nombre_usuario IS NOT NULL;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS hu020_nombre_usuario_check;
ALTER TABLE public.profiles ADD CONSTRAINT hu020_nombre_usuario_check
  CHECK (nombre_usuario IS NULL OR nombre_usuario ~ '^[a-z0-9][a-z0-9_.-]{2,31}$');

-- Selección explícita: nunca devuelve fcm_token, auth.users ni contraseñas.
-- RPC de solo lectura para Administrador activo: recibe desplazamiento y tamaño
-- de página, valida sus límites y devuelve los campos públicos del perfil.
-- Ordena por nombre/UUID para paginar de forma estable; no devuelve contraseñas,
-- tokens FCM ni información de auth.users.
CREATE OR REPLACE FUNCTION public.listar_usuarios_hu020(p_desde INTEGER DEFAULT 0,p_limite INTEGER DEFAULT 200)
RETURNS TABLE(id UUID,nombre_usuario TEXT,nombres TEXT,apellidos TEXT,nombre TEXT,email TEXT,
  cargo TEXT,correo_drive TEXT,rol TEXT,areas_asignadas TEXT[],activo BOOLEAN,
  created_at TIMESTAMPTZ,updated_at TIMESTAMPTZ)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF public.sitra_rol_actual() IS DISTINCT FROM 'ADMINISTRADOR' THEN
    RAISE EXCEPTION 'Solo Administrador puede consultar la gestión de usuarios.' USING ERRCODE='42501';
  END IF;
  IF p_desde IS NULL OR p_desde<0 OR p_limite IS NULL OR p_limite<1 OR p_limite>500 THEN
    RAISE EXCEPTION 'Paginación inválida.';
  END IF;
  RETURN QUERY SELECT p.id,p.nombre_usuario,p.nombres,p.apellidos,p.nombre,p.email,
    p.cargo,p.correo_drive,p.rol,p.areas_asignadas,p.activo,p.created_at,p.updated_at
    FROM public.profiles p ORDER BY lower(p.nombre),p.id OFFSET p_desde LIMIT p_limite;
END;
$$;
REVOKE ALL ON FUNCTION public.listar_usuarios_hu020(INTEGER,INTEGER) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.listar_usuarios_hu020(INTEGER,INTEGER) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;



-- ============================================================================
-- 20. HU-020/HU-021/HU-022: HABILITACION, ALTA Y EDICION DE USUARIOS
-- Sincronizado con migracion_hu021_hu022_gestion_usuarios_2026_10_22.sql.
-- La Edge Function crear-usuario (supabase/functions) se despliega aparte.
-- ============================================================================
-- HU-020 (habilitación), HU-021 (crear usuario) y HU-022 (editar usuario).
-- Ejecutar después de migracion_hu020_estructura_usuarios_2026_10_15.sql.
-- No crea cuentas de Supabase Auth: eso lo hace la Edge Function `crear-usuario`,
-- que usa la clave service-role en el servidor (nunca dentro de Flutter).
BEGIN;

-- Validación y normalización ÚNICA de los datos de perfil. La reutilizan la
-- edición (administrar_usuario_hu020) y el alta (registrar_perfil_usuario_hu021),
-- de modo que ambas operaciones aplican exactamente las mismas reglas.
-- Recibe el JSON enviado por la app y, opcionalmente, el UUID del perfil que se
-- edita (para excluirlo de las comprobaciones de unicidad). Devuelve el JSON
-- normalizado o lanza una excepción con un mensaje apto para mostrar al usuario.
CREATE OR REPLACE FUNCTION public.hu021_normalizar_perfil(p_datos JSONB, p_id UUID DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql STABLE SET search_path = '' AS $$
DECLARE
  v_nombres TEXT; v_apellidos TEXT; v_usuario TEXT; v_cargo TEXT; v_drive TEXT; v_rol TEXT;
  v_token TEXT; v_codigo TEXT; v_areas TEXT[] := '{}';
BEGIN
  IF p_datos IS NULL OR jsonb_typeof(p_datos) <> 'object' THEN
    RAISE EXCEPTION 'Datos de usuario inválidos.';
  END IF;

  v_nombres   := regexp_replace(btrim(COALESCE(p_datos->>'nombres', '')), '\s+', ' ', 'g');
  v_apellidos := regexp_replace(btrim(COALESCE(p_datos->>'apellidos', '')), '\s+', ' ', 'g');
  IF length(v_nombres) < 2 OR length(v_nombres) > 80 THEN
    RAISE EXCEPTION 'Escribe los nombres (2 a 80 caracteres).';
  END IF;
  IF length(v_apellidos) < 2 OR length(v_apellidos) > 80 THEN
    RAISE EXCEPTION 'Escribe los apellidos (2 a 80 caracteres).';
  END IF;

  v_usuario := lower(btrim(COALESCE(p_datos->>'nombre_usuario', '')));
  IF v_usuario !~ '^[a-z0-9][a-z0-9_.-]{2,31}$' THEN
    RAISE EXCEPTION 'El nombre de usuario debe tener 3 a 32 caracteres: minúsculas, números, punto, guion o guion bajo.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.profiles
             WHERE lower(btrim(nombre_usuario)) = v_usuario AND id IS DISTINCT FROM p_id) THEN
    RAISE EXCEPTION 'Ese nombre de usuario ya está registrado.';
  END IF;

  v_cargo := NULLIF(btrim(COALESCE(p_datos->>'cargo', '')), '');
  IF v_cargo IS NOT NULL AND length(v_cargo) > 80 THEN
    RAISE EXCEPTION 'El cargo no puede superar 80 caracteres.';
  END IF;

  v_drive := NULLIF(lower(btrim(COALESCE(p_datos->>'correo_drive', ''))), '');
  IF v_drive IS NOT NULL AND v_drive !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
    RAISE EXCEPTION 'El correo de Drive no tiene un formato válido.';
  END IF;

  v_rol := p_datos->>'rol';
  IF v_rol IS NULL OR v_rol NOT IN ('ADMINISTRADOR','JEFATURA_FARMACIA','FARMACIA','ALMACEN','ENFERMERIA') THEN
    RAISE EXCEPTION 'Selecciona un rol válido.';
  END IF;

  IF jsonb_typeof(p_datos->'areas') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Las áreas asignadas deben enviarse como una lista.';
  END IF;
  -- Cada área se guarda con su alias operativo (areas.codigo). Una asignación
  -- histórica desconocida solo se conserva si el usuario ya la tenía.
  FOR v_token IN SELECT DISTINCT btrim(x) FROM jsonb_array_elements_text(p_datos->'areas') AS t(x) LOOP
    v_codigo := NULL;
    SELECT a.codigo INTO v_codigo FROM public.areas a
      WHERE upper(a.codigo) = upper(v_token) OR upper(a.codigo_interno) = upper(v_token)
         OR lower(a.nombre) = lower(v_token)
      ORDER BY a.id LIMIT 1;
    IF v_codigo IS NOT NULL THEN
      v_areas := v_areas || v_codigo;
    ELSIF EXISTS (SELECT 1 FROM public.profiles WHERE id = p_id AND v_token = ANY(areas_asignadas)) THEN
      v_areas := v_areas || v_token;
    ELSE
      RAISE EXCEPTION 'Área desconocida: %', v_token;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'nombres', v_nombres, 'apellidos', v_apellidos,
    'nombre', v_nombres || ' ' || v_apellidos,
    'nombre_usuario', v_usuario, 'cargo', v_cargo, 'correo_drive', v_drive,
    'rol', v_rol, 'areas', to_jsonb(ARRAY(SELECT DISTINCT unnest(v_areas) ORDER BY 1)));
END;
$$;
REVOKE ALL ON FUNCTION public.hu021_normalizar_perfil(JSONB, UUID) FROM PUBLIC, anon, authenticated;

-- Edición y habilitación de usuarios (HU-020 / HU-022). Solo Administrador activo.
-- p_accion: EDITAR (usa p_datos con los campos del perfil) o ESTADO (p_datos.activo).
-- Reglas de seguridad: no se puede deshabilitar ni quitar el rol a la propia cuenta
-- y siempre debe quedar al menos un Administrador activo. El correo no se edita aquí
-- porque pertenece a Supabase Auth. Registra el antes/después sin tokens FCM.
CREATE OR REPLACE FUNCTION public.administrar_usuario_hu020(
  p_accion TEXT, p_id UUID, p_datos JSONB DEFAULT '{}'::JSONB
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_antes public.profiles%ROWTYPE; v_normal JSONB; v_despues JSONB; v_activo BOOLEAN;
  v_pierde_admin BOOLEAN;
BEGIN
  IF public.sitra_rol_actual() IS DISTINCT FROM 'ADMINISTRADOR' THEN
    RAISE EXCEPTION 'Solo Administrador puede gestionar usuarios.' USING ERRCODE = '42501';
  END IF;
  IF p_accion IS NULL OR p_accion NOT IN ('EDITAR','ESTADO') OR p_id IS NULL THEN
    RAISE EXCEPTION 'Operación de usuario inválida.';
  END IF;
  -- Serializa los cambios para que dos administradores no dejen el sistema sin ninguno activo.
  PERFORM pg_advisory_xact_lock(12020, 2);
  SELECT * INTO v_antes FROM public.profiles WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'El usuario ya no existe.'; END IF;

  IF p_accion = 'ESTADO' THEN
    IF jsonb_typeof(p_datos->'activo') IS DISTINCT FROM 'boolean' THEN
      RAISE EXCEPTION 'Estado inválido.';
    END IF;
    v_activo := (p_datos->>'activo')::BOOLEAN;
    v_pierde_admin := NOT v_activo;
  ELSE
    v_normal := public.hu021_normalizar_perfil(p_datos, p_id);
    v_pierde_admin := (v_normal->>'rol') <> 'ADMINISTRADOR';
    IF p_id = auth.uid() AND (v_normal->>'rol') <> v_antes.rol THEN
      RAISE EXCEPTION 'No puedes cambiar el rol de tu propia cuenta.';
    END IF;
  END IF;

  IF p_accion = 'ESTADO' AND NOT v_activo AND p_id = auth.uid() THEN
    RAISE EXCEPTION 'No puedes deshabilitar tu propia cuenta.';
  END IF;
  IF v_pierde_admin AND v_antes.rol = 'ADMINISTRADOR' AND v_antes.activo AND NOT EXISTS (
       SELECT 1 FROM public.profiles WHERE rol = 'ADMINISTRADOR' AND activo AND id <> p_id) THEN
    RAISE EXCEPTION 'Debe quedar al menos un Administrador activo.';
  END IF;

  BEGIN
    IF p_accion = 'ESTADO' THEN
      UPDATE public.profiles SET activo = v_activo, updated_at = now() WHERE id = p_id;
    ELSE
      UPDATE public.profiles SET
        nombres = v_normal->>'nombres', apellidos = v_normal->>'apellidos',
        nombre = v_normal->>'nombre', nombre_usuario = v_normal->>'nombre_usuario',
        cargo = v_normal->>'cargo', correo_drive = v_normal->>'correo_drive',
        rol = v_normal->>'rol',
        areas_asignadas = ARRAY(SELECT jsonb_array_elements_text(v_normal->'areas')),
        updated_at = now()
      WHERE id = p_id;
    END IF;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Ese nombre de usuario ya está registrado.';
  END;

  SELECT to_jsonb(p.*) - 'fcm_token' INTO v_despues FROM public.profiles p WHERE p.id = p_id;
  INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
    usuario_id, estado_anterior, estado_nuevo, descripcion)
  VALUES('USUARIO_' || p_accion, p_id, 'profiles', auth.uid(),
    to_jsonb(v_antes) - 'fcm_token', v_despues, 'Administración de usuario: ' || p_accion);
  RETURN p_id;
END;
$$;
REVOKE ALL ON FUNCTION public.administrar_usuario_hu020(TEXT, UUID, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.administrar_usuario_hu020(TEXT, UUID, JSONB) TO authenticated;

-- Completa y activa el perfil de una cuenta recién creada en Supabase Auth (HU-021).
-- SOLO la Edge Function `crear-usuario` puede llamarla (rol service_role): la función
-- recibe el UUID del administrador que solicita el alta y lo vuelve a validar.
-- El perfil lo crea handle_new_user con activo = false; esta función solo acepta
-- perfiles en ese estado para que no pueda reutilizarse sobre usuarios existentes.
CREATE OR REPLACE FUNCTION public.registrar_perfil_usuario_hu021(
  p_admin_id UUID, p_id UUID, p_datos JSONB
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_normal JSONB; v_despues JSONB;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles
                 WHERE id = p_admin_id AND rol = 'ADMINISTRADOR' AND activo) THEN
    RAISE EXCEPTION 'Solo Administrador puede crear usuarios.' USING ERRCODE = '42501';
  END IF;
  PERFORM pg_advisory_xact_lock(12020, 2);
  v_normal := public.hu021_normalizar_perfil(p_datos, p_id);
  BEGIN
    UPDATE public.profiles SET
      nombres = v_normal->>'nombres', apellidos = v_normal->>'apellidos',
      nombre = v_normal->>'nombre', nombre_usuario = v_normal->>'nombre_usuario',
      cargo = v_normal->>'cargo', correo_drive = v_normal->>'correo_drive',
      rol = v_normal->>'rol',
      areas_asignadas = ARRAY(SELECT jsonb_array_elements_text(v_normal->'areas')),
      activo = true, updated_at = now()
    WHERE id = p_id AND activo = false;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Ese nombre de usuario ya está registrado.';
  END;
  IF NOT FOUND THEN RAISE EXCEPTION 'No se encontró el perfil pendiente de la nueva cuenta.'; END IF;

  SELECT to_jsonb(p.*) - 'fcm_token' INTO v_despues FROM public.profiles p WHERE p.id = p_id;
  INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
    usuario_id, estado_nuevo, descripcion)
  VALUES('USUARIO_CREAR', p_id, 'profiles', p_admin_id, v_despues, 'Alta de usuario');
  RETURN p_id;
END;
$$;
REVOKE ALL ON FUNCTION public.registrar_perfil_usuario_hu021(UUID, UUID, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_perfil_usuario_hu021(UUID, UUID, JSONB) TO service_role;

-- ============================================================================
-- SPRINT 5 · SEMANA 2: KITS QUIRÚRGICOS Y PLANTILLAS CLÍNICAS (HU-017, HU-018, HU-019)
-- Responsable: David Anampa
-- ============================================================================
ALTER TABLE public.kits 
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now());

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'uq_kit_medicamento' AND conrelid = 'public.kit_items'::regclass
    ) THEN
        ALTER TABLE public.kit_items 
            ADD CONSTRAINT uq_kit_medicamento UNIQUE (kit_id, medicamento_id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_kits_area_destino ON public.kits(area_destino);
CREATE INDEX IF NOT EXISTS idx_kits_activo ON public.kits(activo);
CREATE INDEX IF NOT EXISTS idx_kit_items_kit_id ON public.kit_items(kit_id);
CREATE INDEX IF NOT EXISTS idx_kit_items_medicamento_id ON public.kit_items(medicamento_id);

CREATE OR REPLACE FUNCTION public.listar_kits_hu017(
    p_area TEXT DEFAULT NULL,
    p_solo_activos BOOLEAN DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    nombre TEXT,
    descripcion TEXT,
    area_destino TEXT,
    area_nombre TEXT,
    area_codigo_interno TEXT,
    activo BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    total_items BIGINT,
    items JSONB
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_rol TEXT;
    v_areas_usuario TEXT[];
BEGIN
    v_rol := public.sitra_rol_actual();
    IF v_rol IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado o sin rol asignado.' USING ERRCODE = '42501';
    END IF;

    IF v_rol = 'ENFERMERIA' THEN
        SELECT COALESCE(p.areas_asignadas, '{}') INTO v_areas_usuario
        FROM public.profiles p WHERE p.id = auth.uid();
    END IF;

    RETURN QUERY
    SELECT 
        k.id,
        k.nombre,
        k.descripcion,
        k.area_destino,
        COALESCE(a.nombre, k.area_destino) AS area_nombre,
        COALESCE(a.codigo_interno, k.area_destino) AS area_codigo_interno,
        k.activo,
        k.created_at,
        k.updated_at,
        COUNT(ki.id)::BIGINT AS total_items,
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', ki.id,
                    'medicamento_id', ki.medicamento_id,
                    'nombre_comercial', m.nombre_comercial,
                    'principio_activo', m.principio_activo,
                    'presentacion', m.presentacion,
                    'laboratorio', m.laboratorio,
                    'cantidad', ki.cantidad
                ) ORDER BY m.nombre_comercial ASC
            ) FILTER (WHERE ki.id IS NOT NULL),
            '[]'::JSONB
        ) AS items
    FROM public.kits k
    LEFT JOIN public.areas a ON (a.codigo = k.area_destino)
    LEFT JOIN public.kit_items ki ON (ki.kit_id = k.id)
    LEFT JOIN public.medicamentos m ON (m.id = ki.medicamento_id)
    WHERE 
        (p_area IS NULL OR k.area_destino = p_area OR a.codigo_interno = p_area)
        AND (p_solo_activos IS NULL OR k.activo = p_solo_activos)
        AND (
            v_rol IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA', 'ALMACEN')
            OR (v_rol = 'ENFERMERIA' AND k.area_destino = ANY(v_areas_usuario))
        )
    GROUP BY k.id, k.nombre, k.descripcion, k.area_destino, a.nombre, a.codigo_interno, k.activo, k.created_at, k.updated_at
    ORDER BY k.activo DESC, k.nombre ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.listar_kits_hu017(TEXT, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.listar_kits_hu017(TEXT, BOOLEAN) TO authenticated;

CREATE OR REPLACE FUNCTION public.administrar_kit_hu018(
    p_accion TEXT,
    p_id UUID DEFAULT NULL,
    p_datos JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_rol TEXT;
    v_uid UUID;
    v_id UUID := p_id;
    v_nombre TEXT;
    v_descripcion TEXT;
    v_area TEXT;
    v_activo BOOLEAN;
    v_items JSONB;
    v_item JSONB;
    v_med_id UUID;
    v_cantidad INT;
    v_med_ids UUID[] := '{}';
    v_antes JSONB := NULL;
    v_despues JSONB := NULL;
    v_kit_actual public.kits%ROWTYPE;
BEGIN
    v_rol := public.sitra_rol_actual();
    v_uid := auth.uid();

    IF v_rol NOT IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA') THEN
        RAISE EXCEPTION 'No tienes permisos para administrar plantillas de kits (Rol: %).', COALESCE(v_rol, 'Sin Rol')
            USING ERRCODE = '42501';
    END IF;

    IF p_accion IS NULL OR p_accion NOT IN ('GUARDAR', 'ESTADO', 'ELIMINAR') THEN
        RAISE EXCEPTION 'Acción no válida: %. Use GUARDAR, ESTADO o ELIMINAR.', p_accion;
    END IF;

    IF p_accion = 'ESTADO' THEN
        IF p_id IS NULL THEN
            RAISE EXCEPTION 'Se requiere el ID del kit para cambiar su estado.';
        END IF;

        IF jsonb_typeof(p_datos->'activo') IS DISTINCT FROM 'boolean' THEN
            RAISE EXCEPTION 'El estado activo debe ser un valor booleano.';
        END IF;

        v_activo := (p_datos->>'activo')::BOOLEAN;

        SELECT * INTO v_kit_actual FROM public.kits WHERE id = p_id FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'El kit indicado no existe.';
        END IF;

        v_antes := to_jsonb(v_kit_actual);

        UPDATE public.kits
        SET activo = v_activo,
            updated_at = timezone('utc'::text, now())
        WHERE id = p_id
        RETURNING to_jsonb(kits.*) INTO v_despues;

        INSERT INTO public.auditoria_trazabilidad(
            tipo_evento, entidad_referencia_id, tabla_referencia, usuario_id,
            estado_anterior, estado_nuevo, descripcion
        ) VALUES (
            'KIT_ESTADO', p_id, 'kits', v_uid,
            v_antes, v_despues,
            CASE WHEN v_activo THEN 'Kit habilitado para dispensación: ' || v_kit_actual.nombre
                 ELSE 'Kit deshabilitado para dispensación (conserva historial): ' || v_kit_actual.nombre
            END
        );

        RETURN p_id;
    END IF;

    IF p_accion = 'ELIMINAR' THEN
        IF p_id IS NULL THEN
            RAISE EXCEPTION 'Se requiere el ID del kit para eliminar.';
        END IF;

        SELECT * INTO v_kit_actual FROM public.kits WHERE id = p_id FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'El kit indicado no existe.';
        END IF;

        IF EXISTS (SELECT 1 FROM public.dispensaciones WHERE kit_id = p_id) THEN
            RAISE EXCEPTION 'El kit tiene fichas y dispensaciones históricas asociadas. No se puede eliminar físicamente; desactívalo para conservarlo en el historial clínico.';
        END IF;

        v_antes := to_jsonb(v_kit_actual);

        DELETE FROM public.kits WHERE id = p_id;

        INSERT INTO public.auditoria_trazabilidad(
            tipo_evento, entidad_referencia_id, tabla_referencia, usuario_id,
            estado_anterior, estado_nuevo, descripcion
        ) VALUES (
            'KIT_ELIMINADO', p_id, 'kits', v_uid,
            v_antes, NULL,
            'Kit borrador eliminado sin usos históricos: ' || v_kit_actual.nombre
        );

        RETURN p_id;
    END IF;

    IF p_accion = 'GUARDAR' THEN
        v_nombre := regexp_replace(btrim(COALESCE(p_datos->>'nombre', '')), '\s+', ' ', 'g');
        IF length(v_nombre) < 3 OR length(v_nombre) > 120 THEN
            RAISE EXCEPTION 'El nombre del kit debe tener entre 3 y 120 caracteres.';
        END IF;

        v_descripcion := NULLIF(btrim(COALESCE(p_datos->>'descripcion', '')), '');
        IF v_descripcion IS NOT NULL AND length(v_descripcion) > 300 THEN
            RAISE EXCEPTION 'La descripción no puede exceder los 300 caracteres.';
        END IF;

        v_area := upper(btrim(COALESCE(p_datos->>'area_destino', '')));
        IF v_area = '' THEN
            RAISE EXCEPTION 'Debe seleccionar el área de destino para el kit.';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM public.areas 
            WHERE (codigo = v_area OR codigo_interno = v_area) AND activo = true
        ) THEN
            RAISE EXCEPTION 'El área destino % no existe o se encuentra inactiva.', v_area;
        END IF;

        SELECT codigo INTO v_area FROM public.areas 
        WHERE (codigo = v_area OR codigo_interno = v_area) LIMIT 1;

        IF EXISTS (
            SELECT 1 FROM public.kits 
            WHERE lower(btrim(nombre)) = lower(v_nombre)
              AND area_destino = v_area
              AND id IS DISTINCT FROM p_id
        ) THEN
            RAISE EXCEPTION 'Ya existe un kit con el nombre "%" registrado para el área %.', v_nombre, v_area;
        END IF;

        v_items := p_datos->'items';
        IF v_items IS NULL OR jsonb_typeof(v_items) IS DISTINCT FROM 'array' OR jsonb_array_length(v_items) = 0 THEN
            RAISE EXCEPTION 'El kit debe contener al menos un medicamento o insumo con su cantidad.';
        END IF;

        FOR v_item IN SELECT * FROM jsonb_array_elements(v_items) LOOP
            v_med_id := (v_item->>'medicamento_id')::UUID;
            v_cantidad := COALESCE((v_item->>'cantidad')::INT, 0);

            IF v_med_id IS NULL THEN
                RAISE EXCEPTION 'Cada ítem del kit debe especificar un medicamento válido.';
            END IF;

            IF v_cantidad <= 0 THEN
                RAISE EXCEPTION 'La cantidad para cada insumo del kit debe ser mayor a 0.';
            END IF;

            IF NOT EXISTS (SELECT 1 FROM public.medicamentos WHERE id = v_med_id AND activo = true) THEN
                RAISE EXCEPTION 'Uno de los medicamentos seleccionados no existe o está inactivo en el catálogo maestro.';
            END IF;

            IF v_med_id = ANY(v_med_ids) THEN
                RAISE EXCEPTION 'No se puede repetir el mismo medicamento más de una vez en el kit. Ajuste la cantidad en una sola fila.';
            END IF;

            v_med_ids := v_med_ids || v_med_id;
        END LOOP;

        IF p_id IS NULL THEN
            v_id := gen_random_uuid();
            INSERT INTO public.kits (id, nombre, descripcion, area_destino, activo, created_at, updated_at)
            VALUES (v_id, v_nombre, v_descripcion, v_area, true, timezone('utc'::text, now()), timezone('utc'::text, now()))
            RETURNING to_jsonb(kits.*) INTO v_despues;

            FOR v_item IN SELECT * FROM jsonb_array_elements(v_items) LOOP
                INSERT INTO public.kit_items (kit_id, medicamento_id, cantidad)
                VALUES (v_id, (v_item->>'medicamento_id')::UUID, (v_item->>'cantidad')::INT);
            END LOOP;

            INSERT INTO public.auditoria_trazabilidad(
                tipo_evento, entidad_referencia_id, tabla_referencia, usuario_id,
                estado_anterior, estado_nuevo, descripcion
            ) VALUES (
                'KIT_CREADO', v_id, 'kits', v_uid,
                NULL, v_despues || jsonb_build_object('items', v_items),
                'Creación de kit prearmado: ' || v_nombre || ' para ' || v_area
            );

        ELSE
            SELECT * INTO v_kit_actual FROM public.kits WHERE id = p_id FOR UPDATE;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'El kit que intenta editar no existe.';
            END IF;

            SELECT to_jsonb(v_kit_actual) || jsonb_build_object(
                'items', (SELECT COALESCE(jsonb_agg(to_jsonb(ki.*)), '[]'::JSONB) FROM public.kit_items ki WHERE ki.kit_id = p_id)
            ) INTO v_antes;

            UPDATE public.kits
            SET nombre = v_nombre,
                descripcion = v_descripcion,
                area_destino = v_area,
                updated_at = timezone('utc'::text, now())
            WHERE id = p_id
            RETURNING to_jsonb(kits.*) INTO v_despues;

            DELETE FROM public.kit_items WHERE kit_id = p_id;

            FOR v_item IN SELECT * FROM jsonb_array_elements(v_items) LOOP
                INSERT INTO public.kit_items (kit_id, medicamento_id, cantidad)
                VALUES (p_id, (v_item->>'medicamento_id')::UUID, (v_item->>'cantidad')::INT);
            END LOOP;

            INSERT INTO public.auditoria_trazabilidad(
                tipo_evento, entidad_referencia_id, tabla_referencia, usuario_id,
                estado_anterior, estado_nuevo, descripcion
            ) VALUES (
                'KIT_ACTUALIZADO', p_id, 'kits', v_uid,
                v_antes, v_despues || jsonb_build_object('items', v_items),
                'Actualización de plantilla de kit: ' || v_nombre || ' (preserva historial de fichas)'
            );
        END IF;

        RETURN v_id;
    END IF;

    RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.administrar_kit_hu018(TEXT, UUID, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.administrar_kit_hu018(TEXT, UUID, JSONB) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;

-- 22. Correo único de usuarios (25 de octubre de 2026).
-- HU-020/HU-021/HU-022: un único correo para acceso y futura vinculación con Drive.
-- Aplicar DESPUÉS de las migraciones HU-020 y HU-021/HU-022 del 15 y 22 de octubre.
-- No modifica correos de Auth. Conserva correo_drive como columna heredada sin
-- utilizarla ni borrar sus valores; la aplicación usa exclusivamente profiles.email.
-- La autorización de Google y la carpeta de destino corresponden a HU-027.
-- HU-020 (habilitación), HU-021 (crear usuario) y HU-022 (editar usuario).
-- Ejecutar después de migracion_hu020_estructura_usuarios_2026_10_15.sql.
-- No crea cuentas de Supabase Auth: eso lo hace la Edge Function `crear-usuario`,
-- que usa la clave service-role en el servidor (nunca dentro de Flutter).
BEGIN;

-- Cambia el contrato de lectura; DROP sin CASCADE conserva la seguridad ante dependencias.
DROP FUNCTION IF EXISTS public.listar_usuarios_hu020(INTEGER,INTEGER);
CREATE OR REPLACE FUNCTION public.listar_usuarios_hu020(p_desde INTEGER DEFAULT 0,p_limite INTEGER DEFAULT 200)
RETURNS TABLE(id UUID,nombre_usuario TEXT,nombres TEXT,apellidos TEXT,nombre TEXT,email TEXT,
  cargo TEXT,rol TEXT,areas_asignadas TEXT[],activo BOOLEAN,
  created_at TIMESTAMPTZ,updated_at TIMESTAMPTZ)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF public.sitra_rol_actual() IS DISTINCT FROM 'ADMINISTRADOR' THEN
    RAISE EXCEPTION 'Solo Administrador puede consultar la gestión de usuarios.' USING ERRCODE='42501';
  END IF;
  IF p_desde IS NULL OR p_desde<0 OR p_limite IS NULL OR p_limite<1 OR p_limite>500 THEN
    RAISE EXCEPTION 'Paginación inválida.';
  END IF;
  RETURN QUERY SELECT p.id,p.nombre_usuario,p.nombres,p.apellidos,p.nombre,p.email,
    p.cargo,p.rol,p.areas_asignadas,p.activo,p.created_at,p.updated_at
    FROM public.profiles p ORDER BY lower(p.nombre),p.id OFFSET p_desde LIMIT p_limite;
END;
$$;
REVOKE ALL ON FUNCTION public.listar_usuarios_hu020(INTEGER,INTEGER) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.listar_usuarios_hu020(INTEGER,INTEGER) TO authenticated;



-- Validación y normalización ÚNICA de los datos de perfil. La reutilizan la
-- edición (administrar_usuario_hu020) y el alta (registrar_perfil_usuario_hu021),
-- de modo que ambas operaciones aplican exactamente las mismas reglas.
-- Recibe el JSON enviado por la app y, opcionalmente, el UUID del perfil que se
-- edita (para excluirlo de las comprobaciones de unicidad). Devuelve el JSON
-- normalizado o lanza una excepción con un mensaje apto para mostrar al usuario.
CREATE OR REPLACE FUNCTION public.hu021_normalizar_perfil(p_datos JSONB, p_id UUID DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql STABLE SET search_path = '' AS $$
DECLARE
  v_nombres TEXT; v_apellidos TEXT; v_usuario TEXT; v_cargo TEXT; v_rol TEXT;
  v_token TEXT; v_codigo TEXT; v_areas TEXT[] := '{}';
BEGIN
  IF p_datos IS NULL OR jsonb_typeof(p_datos) <> 'object' THEN
    RAISE EXCEPTION 'Datos de usuario inválidos.';
  END IF;

  v_nombres   := regexp_replace(btrim(COALESCE(p_datos->>'nombres', '')), '\s+', ' ', 'g');
  v_apellidos := regexp_replace(btrim(COALESCE(p_datos->>'apellidos', '')), '\s+', ' ', 'g');
  IF length(v_nombres) < 2 OR length(v_nombres) > 80 THEN
    RAISE EXCEPTION 'Escribe los nombres (2 a 80 caracteres).';
  END IF;
  IF length(v_apellidos) < 2 OR length(v_apellidos) > 80 THEN
    RAISE EXCEPTION 'Escribe los apellidos (2 a 80 caracteres).';
  END IF;

  v_usuario := lower(btrim(COALESCE(p_datos->>'nombre_usuario', '')));
  IF v_usuario !~ '^[a-z0-9][a-z0-9_.-]{2,31}$' THEN
    RAISE EXCEPTION 'El nombre de usuario debe tener 3 a 32 caracteres: minúsculas, números, punto, guion o guion bajo.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.profiles
             WHERE lower(btrim(nombre_usuario)) = v_usuario AND id IS DISTINCT FROM p_id) THEN
    RAISE EXCEPTION 'Ese nombre de usuario ya está registrado.';
  END IF;

  v_cargo := NULLIF(btrim(COALESCE(p_datos->>'cargo', '')), '');
  IF v_cargo IS NOT NULL AND length(v_cargo) > 80 THEN
    RAISE EXCEPTION 'El cargo no puede superar 80 caracteres.';
  END IF;

  v_rol := p_datos->>'rol';
  IF v_rol IS NULL OR v_rol NOT IN ('ADMINISTRADOR','JEFATURA_FARMACIA','FARMACIA','ALMACEN','ENFERMERIA') THEN
    RAISE EXCEPTION 'Selecciona un rol válido.';
  END IF;

  IF jsonb_typeof(p_datos->'areas') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Las áreas asignadas deben enviarse como una lista.';
  END IF;
  -- Cada área se guarda con su alias operativo (areas.codigo). Una asignación
  -- histórica desconocida solo se conserva si el usuario ya la tenía.
  FOR v_token IN SELECT DISTINCT btrim(x) FROM jsonb_array_elements_text(p_datos->'areas') AS t(x) LOOP
    v_codigo := NULL;
    SELECT a.codigo INTO v_codigo FROM public.areas a
      WHERE upper(a.codigo) = upper(v_token) OR upper(a.codigo_interno) = upper(v_token)
         OR lower(a.nombre) = lower(v_token)
      ORDER BY a.id LIMIT 1;
    IF v_codigo IS NOT NULL THEN
      v_areas := v_areas || v_codigo;
    ELSIF EXISTS (SELECT 1 FROM public.profiles WHERE id = p_id AND v_token = ANY(areas_asignadas)) THEN
      v_areas := v_areas || v_token;
    ELSE
      RAISE EXCEPTION 'Área desconocida: %', v_token;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'nombres', v_nombres, 'apellidos', v_apellidos,
    'nombre', v_nombres || ' ' || v_apellidos,
    'nombre_usuario', v_usuario, 'cargo', v_cargo,
    'rol', v_rol, 'areas', to_jsonb(ARRAY(SELECT DISTINCT unnest(v_areas) ORDER BY 1)));
END;
$$;
REVOKE ALL ON FUNCTION public.hu021_normalizar_perfil(JSONB, UUID) FROM PUBLIC, anon, authenticated;

-- Edición y habilitación de usuarios (HU-020 / HU-022). Solo Administrador activo.
-- p_accion: EDITAR (usa p_datos con los campos del perfil) o ESTADO (p_datos.activo).
-- Reglas de seguridad: no se puede deshabilitar ni quitar el rol a la propia cuenta
-- y siempre debe quedar al menos un Administrador activo. El correo no se edita aquí
-- porque pertenece a Supabase Auth. Registra el antes/después sin tokens FCM.
CREATE OR REPLACE FUNCTION public.administrar_usuario_hu020(
  p_accion TEXT, p_id UUID, p_datos JSONB DEFAULT '{}'::JSONB
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_antes public.profiles%ROWTYPE; v_normal JSONB; v_despues JSONB; v_activo BOOLEAN;
  v_pierde_admin BOOLEAN;
BEGIN
  IF public.sitra_rol_actual() IS DISTINCT FROM 'ADMINISTRADOR' THEN
    RAISE EXCEPTION 'Solo Administrador puede gestionar usuarios.' USING ERRCODE = '42501';
  END IF;
  IF p_accion IS NULL OR p_accion NOT IN ('EDITAR','ESTADO') OR p_id IS NULL THEN
    RAISE EXCEPTION 'Operación de usuario inválida.';
  END IF;
  -- Serializa los cambios para que dos administradores no dejen el sistema sin ninguno activo.
  PERFORM pg_advisory_xact_lock(12020, 2);
  SELECT * INTO v_antes FROM public.profiles WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'El usuario ya no existe.'; END IF;

  IF p_accion = 'ESTADO' THEN
    IF jsonb_typeof(p_datos->'activo') IS DISTINCT FROM 'boolean' THEN
      RAISE EXCEPTION 'Estado inválido.';
    END IF;
    v_activo := (p_datos->>'activo')::BOOLEAN;
    v_pierde_admin := NOT v_activo;
  ELSE
    v_normal := public.hu021_normalizar_perfil(p_datos, p_id);
    v_pierde_admin := (v_normal->>'rol') <> 'ADMINISTRADOR';
    IF p_id = auth.uid() AND (v_normal->>'rol') <> v_antes.rol THEN
      RAISE EXCEPTION 'No puedes cambiar el rol de tu propia cuenta.';
    END IF;
  END IF;

  IF p_accion = 'ESTADO' AND NOT v_activo AND p_id = auth.uid() THEN
    RAISE EXCEPTION 'No puedes deshabilitar tu propia cuenta.';
  END IF;
  IF v_pierde_admin AND v_antes.rol = 'ADMINISTRADOR' AND v_antes.activo AND NOT EXISTS (
       SELECT 1 FROM public.profiles WHERE rol = 'ADMINISTRADOR' AND activo AND id <> p_id) THEN
    RAISE EXCEPTION 'Debe quedar al menos un Administrador activo.';
  END IF;

  BEGIN
    IF p_accion = 'ESTADO' THEN
      UPDATE public.profiles SET activo = v_activo, updated_at = now() WHERE id = p_id;
    ELSE
      UPDATE public.profiles SET
        nombres = v_normal->>'nombres', apellidos = v_normal->>'apellidos',
        nombre = v_normal->>'nombre', nombre_usuario = v_normal->>'nombre_usuario',
        cargo = v_normal->>'cargo',
        rol = v_normal->>'rol',
        areas_asignadas = ARRAY(SELECT jsonb_array_elements_text(v_normal->'areas')),
        updated_at = now()
      WHERE id = p_id;
    END IF;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Ese nombre de usuario ya está registrado.';
  END;

  SELECT to_jsonb(p.*) - 'fcm_token' - 'correo_drive' INTO v_despues FROM public.profiles p WHERE p.id = p_id;
  INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
    usuario_id, estado_anterior, estado_nuevo, descripcion)
  VALUES('USUARIO_' || p_accion, p_id, 'profiles', auth.uid(),
    to_jsonb(v_antes) - 'fcm_token' - 'correo_drive', v_despues, 'Administración de usuario: ' || p_accion);
  RETURN p_id;
END;
$$;
REVOKE ALL ON FUNCTION public.administrar_usuario_hu020(TEXT, UUID, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.administrar_usuario_hu020(TEXT, UUID, JSONB) TO authenticated;

-- Completa y activa el perfil de una cuenta recién creada en Supabase Auth (HU-021).
-- SOLO la Edge Function `crear-usuario` puede llamarla (rol service_role): la función
-- recibe el UUID del administrador que solicita el alta y lo vuelve a validar.
-- El perfil lo crea handle_new_user con activo = false; esta función solo acepta
-- perfiles en ese estado para que no pueda reutilizarse sobre usuarios existentes.
CREATE OR REPLACE FUNCTION public.registrar_perfil_usuario_hu021(
  p_admin_id UUID, p_id UUID, p_datos JSONB
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_normal JSONB; v_despues JSONB;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles
                 WHERE id = p_admin_id AND rol = 'ADMINISTRADOR' AND activo) THEN
    RAISE EXCEPTION 'Solo Administrador puede crear usuarios.' USING ERRCODE = '42501';
  END IF;
  PERFORM pg_advisory_xact_lock(12020, 2);
  v_normal := public.hu021_normalizar_perfil(p_datos, p_id);
  BEGIN
    UPDATE public.profiles SET
      nombres = v_normal->>'nombres', apellidos = v_normal->>'apellidos',
      nombre = v_normal->>'nombre', nombre_usuario = v_normal->>'nombre_usuario',
      cargo = v_normal->>'cargo',
      rol = v_normal->>'rol',
      areas_asignadas = ARRAY(SELECT jsonb_array_elements_text(v_normal->'areas')),
      activo = true, updated_at = now()
    WHERE id = p_id AND activo = false;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Ese nombre de usuario ya está registrado.';
  END;
  IF NOT FOUND THEN RAISE EXCEPTION 'No se encontró el perfil pendiente de la nueva cuenta.'; END IF;

  SELECT to_jsonb(p.*) - 'fcm_token' - 'correo_drive' INTO v_despues FROM public.profiles p WHERE p.id = p_id;
  INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
    usuario_id, estado_nuevo, descripcion)
  VALUES('USUARIO_CREAR', p_id, 'profiles', p_admin_id, v_despues, 'Alta de usuario');
  RETURN p_id;
END;
$$;
REVOKE ALL ON FUNCTION public.registrar_perfil_usuario_hu021(UUID, UUID, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_perfil_usuario_hu021(UUID, UUID, JSONB) TO service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;


-- 23. Catálogos profesionales peruanos (25 de octubre de 2026).
-- Catálogos profesionales peruanos y datos opcionales del perfil.
-- 25/10/2026. Independiente de las migraciones HU-020/HU-021 aún pendientes.
-- No crea cuentas, no cambia roles, no agrega profesión ni consejos regionales.
-- Fuentes por fila. Selección de cobertura hospitalaria; no es un padrón de
-- profesionales habilitados ni una certificación de especialidad/colegiatura.
BEGIN;

CREATE TABLE IF NOT EXISTS public.colegios_profesionales (
  codigo TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  fuente_url TEXT NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS public.especialidades_profesionales (
  codigo TEXT PRIMARY KEY,
  colegio_codigo TEXT NOT NULL REFERENCES public.colegios_profesionales(codigo) ON DELETE RESTRICT,
  nombre TEXT NOT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN ('ESPECIALIDAD','SUBESPECIALIDAD','AREA_PROFESIONAL')),
  fuente_url TEXT NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT true,
  UNIQUE(codigo,colegio_codigo),
  UNIQUE(colegio_codigo,nombre)
);

INSERT INTO public.colegios_profesionales(codigo,nombre,fuente_url) VALUES
('CMP','Colegio Médico del Perú','https://portal.cmp.org.pe/'),
('CEP','Colegio de Enfermeros del Perú','https://www.cep.org.pe/'),
('CQFP','Colegio Químico Farmacéutico del Perú','https://cqfp.pe/transparencia/'),
('CTMP','Colegio de Tecnólogos Médicos del Perú','https://ctmperu.org.pe/')
ON CONFLICT(codigo) DO NOTHING;

INSERT INTO public.especialidades_profesionales(codigo,colegio_codigo,nombre,tipo,fuente_url) VALUES
('MED-001','CMP','Anestesiología','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-002','CMP','Cardiología','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-003','CMP','Cirugía de Cabeza, Cuello y Maxilofacial','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-004','CMP','Cirugía General','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-005','CMP','Cirugía Oncológica','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-006','CMP','Cirugía Pediátrica','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-007','CMP','Cirugía Plástica','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-008','CMP','Dermatología','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-009','CMP','Endocrinología','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-010','CMP','Gastroenterología','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-011','CMP','Geriatría','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-012','CMP','Ginecología y Obstetricia','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-013','CMP','Hematología','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-014','CMP','Medicina de Emergencias y Desastres','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-015','CMP','Medicina de Enfermedades Infecciosas y Tropicales','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-016','CMP','Medicina Familiar y Comunitaria','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-017','CMP','Medicina Física y de Rehabilitación','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-018','CMP','Medicina Intensiva','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-019','CMP','Medicina Interna','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-020','CMP','Medicina Oncológica','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-021','CMP','Nefrología','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-022','CMP','Neonatología','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-023','CMP','Neumología','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-024','CMP','Neurocirugía','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-025','CMP','Neurología','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-026','CMP','Oftalmología','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-027','CMP','Ortopedia y Traumatología','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-028','CMP','Otorrinolaringología','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-029','CMP','Patología Clínica','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-030','CMP','Pediatría','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-031','CMP','Psiquiatría','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-032','CMP','Radiología','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-033','CMP','Reumatología','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-034','CMP','Urología','ESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-SUB-001','CMP','Anestesiología Cardiovascular','SUBESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-SUB-002','CMP','Cirugía de Retina y Vítreo','SUBESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-SUB-003','CMP','Cirugía de Tórax Oncológica','SUBESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-SUB-004','CMP','Cirugía Plástica y Reconstructiva','SUBESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-SUB-005','CMP','Ginecología Oncológica','SUBESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-SUB-006','CMP','Hematología Pediátrica','SUBESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-SUB-007','CMP','Medicina Intensiva Pediátrica','SUBESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-SUB-008','CMP','Neumología Pediátrica','SUBESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-SUB-009','CMP','Neurología Pediátrica','SUBESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-SUB-010','CMP','Oncología Pediátrica','SUBESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-SUB-011','CMP','Radiología Intervencionista','SUBESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('MED-SUB-012','CMP','Urología Oncológica','SUBESPECIALIDAD','https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/'),
('ENF-001','CEP','Enfermería en Centro Quirúrgico','ESPECIALIDAD','https://www.essalud.gob.pe/wp-content/uploads/disp_compl_residet_enfermeria_2023.pdf'),
('ENF-002','CEP','Enfermería en Salud Mental y Psiquiatría','ESPECIALIDAD','https://www.essalud.gob.pe/wp-content/uploads/disp_compl_residet_enfermeria_2023.pdf'),
('ENF-003','CEP','Enfermería en Emergencia y Desastres','ESPECIALIDAD','https://www.essalud.gob.pe/wp-content/uploads/disp_compl_residet_enfermeria_2023.pdf'),
('ENF-004','CEP','Enfermería en Neonatología','ESPECIALIDAD','https://www.essalud.gob.pe/wp-content/uploads/disp_compl_residet_enfermeria_2023.pdf'),
('ENF-005','CEP','Enfermería en Cardiología','ESPECIALIDAD','https://www.essalud.gob.pe/wp-content/uploads/disp_compl_residet_enfermeria_2023.pdf'),
('ENF-006','CEP','Enfermería en Cirugía Cardiovascular','ESPECIALIDAD','https://www.essalud.gob.pe/wp-content/uploads/disp_compl_residet_enfermeria_2023.pdf'),
('ENF-007','CEP','Enfermería en Cuidados Intensivos','ESPECIALIDAD','https://www.essalud.gob.pe/wp-content/uploads/disp_compl_residet_enfermeria_2023.pdf'),
('ENF-008','CEP','Enfermería en Pediatría','ESPECIALIDAD','https://www.essalud.gob.pe/wp-content/uploads/disp_compl_residet_enfermeria_2023.pdf'),
('FAR-001','CQFP','Farmacia Clínica','ESPECIALIDAD','https://farmacia.unmsm.edu.pe/formacion-academica/posgrado'),
('FAR-002','CQFP','Farmacia Hospitalaria','ESPECIALIDAD','https://farmacia.unmsm.edu.pe/formacion-academica/posgrado'),
('TM-001','CTMP','Radiología','AREA_PROFESIONAL','https://ctmperu.org.pe/areas/'),
('TM-002','CTMP','Optometría','AREA_PROFESIONAL','https://ctmperu.org.pe/areas/'),
('TM-003','CTMP','Terapia de Lenguaje','AREA_PROFESIONAL','https://ctmperu.org.pe/areas/'),
('TM-004','CTMP','Terapia Ocupacional','AREA_PROFESIONAL','https://ctmperu.org.pe/areas/'),
('TM-005','CTMP','Terapia Física y Rehabilitación','AREA_PROFESIONAL','https://ctmperu.org.pe/areas/'),
('TM-006','CTMP','Laboratorio Clínico y Anatomía Patológica','AREA_PROFESIONAL','https://ctmperu.org.pe/areas/'),
('MED-035','CMP','Cirugía de Tórax y Cardiovascular','ESPECIALIDAD','https://www.conareme.org.pe/web/proceso-de-admision-2026.php'),
('MED-036','CMP','Cirugía Cardiovascular','ESPECIALIDAD','https://www.conareme.org.pe/web/proceso-de-admision-2026.php')
ON CONFLICT DO NOTHING;

-- Datos adicionales, sin inferir profesiones o colegiaturas de perfiles existentes.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS colegio_codigo TEXT REFERENCES public.colegios_profesionales(codigo) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS numero_colegiatura TEXT,
  ADD COLUMN IF NOT EXISTS especialidad_codigo TEXT;

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS perfil_colegiatura_completa;
ALTER TABLE public.profiles ADD CONSTRAINT perfil_colegiatura_completa CHECK (
  (colegio_codigo IS NULL AND numero_colegiatura IS NULL AND especialidad_codigo IS NULL)
  OR (colegio_codigo IS NOT NULL AND numero_colegiatura IS NOT NULL
      AND numero_colegiatura ~ '^[0-9]{1,20}$')
);
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS perfil_especialidad_colegio_fkey;
ALTER TABLE public.profiles ADD CONSTRAINT perfil_especialidad_colegio_fkey
  FOREIGN KEY(especialidad_codigo,colegio_codigo)
  REFERENCES public.especialidades_profesionales(codigo,colegio_codigo) ON DELETE RESTRICT;

-- Permite conservar una referencia histórica deshabilitada; rechaza nuevas asignaciones.
CREATE OR REPLACE FUNCTION public.validar_referencias_profesionales()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF NEW.colegio_codigo IS NOT NULL AND
     (TG_OP='INSERT' OR NEW.colegio_codigo IS DISTINCT FROM OLD.colegio_codigo) AND NOT EXISTS (
       SELECT 1 FROM public.colegios_profesionales WHERE codigo=NEW.colegio_codigo AND activo
     ) THEN RAISE EXCEPTION 'El colegio profesional no está habilitado.'; END IF;
  IF NEW.especialidad_codigo IS NOT NULL AND
     (TG_OP='INSERT' OR NEW.especialidad_codigo IS DISTINCT FROM OLD.especialidad_codigo
        OR NEW.colegio_codigo IS DISTINCT FROM OLD.colegio_codigo) AND NOT EXISTS (
       SELECT 1 FROM public.especialidades_profesionales
       WHERE codigo=NEW.especialidad_codigo AND colegio_codigo=NEW.colegio_codigo AND activo
     ) THEN RAISE EXCEPTION 'La especialidad no corresponde al colegio o no está habilitada.'; END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.validar_referencias_profesionales() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS perfil_referencias_profesionales ON public.profiles;
CREATE TRIGGER perfil_referencias_profesionales BEFORE INSERT OR UPDATE OF colegio_codigo,numero_colegiatura,especialidad_codigo
ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.validar_referencias_profesionales();

ALTER TABLE public.colegios_profesionales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.especialidades_profesionales ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS colegios_profesionales_lectura ON public.colegios_profesionales;
CREATE POLICY colegios_profesionales_lectura ON public.colegios_profesionales FOR SELECT TO authenticated
USING (public.sitra_rol_actual() IS NOT NULL);
DROP POLICY IF EXISTS especialidades_profesionales_lectura ON public.especialidades_profesionales;
CREATE POLICY especialidades_profesionales_lectura ON public.especialidades_profesionales FOR SELECT TO authenticated
USING (public.sitra_rol_actual() IS NOT NULL);
REVOKE ALL ON public.colegios_profesionales,public.especialidades_profesionales FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.colegios_profesionales,public.especialidades_profesionales TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;

-- 24. Colegiatura y especialidad en gestión de usuarios.
-- Integra colegiatura y especialidad con HU-020/HU-021/HU-022.
-- Aplicar después de HU-020, HU-021/HU-022, correo único y catálogos profesionales.
-- Mantiene roles, permisos, auditoría y protecciones del último Administrador.
BEGIN;

-- Cambia el contrato de lectura; DROP sin CASCADE conserva la seguridad ante dependencias.
DROP FUNCTION IF EXISTS public.listar_usuarios_hu020(INTEGER,INTEGER);
CREATE OR REPLACE FUNCTION public.listar_usuarios_hu020(p_desde INTEGER DEFAULT 0,p_limite INTEGER DEFAULT 200)
RETURNS TABLE(id UUID,nombre_usuario TEXT,nombres TEXT,apellidos TEXT,nombre TEXT,email TEXT,
  cargo TEXT,rol TEXT,areas_asignadas TEXT[],activo BOOLEAN,
  colegio_codigo TEXT,numero_colegiatura TEXT,especialidad_codigo TEXT,
  colegio_nombre TEXT,especialidad_nombre TEXT,
  created_at TIMESTAMPTZ,updated_at TIMESTAMPTZ)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF public.sitra_rol_actual() IS DISTINCT FROM 'ADMINISTRADOR' THEN
    RAISE EXCEPTION 'Solo Administrador puede consultar la gestión de usuarios.' USING ERRCODE='42501';
  END IF;
  IF p_desde IS NULL OR p_desde<0 OR p_limite IS NULL OR p_limite<1 OR p_limite>500 THEN
    RAISE EXCEPTION 'Paginación inválida.';
  END IF;
  RETURN QUERY SELECT p.id,p.nombre_usuario,p.nombres,p.apellidos,p.nombre,p.email,
    p.cargo,p.rol,p.areas_asignadas,p.activo,
    p.colegio_codigo,p.numero_colegiatura,p.especialidad_codigo,c.nombre,e.nombre,
    p.created_at,p.updated_at
    FROM public.profiles p
    LEFT JOIN public.colegios_profesionales c ON c.codigo=p.colegio_codigo
    LEFT JOIN public.especialidades_profesionales e ON e.codigo=p.especialidad_codigo
    ORDER BY lower(p.nombre),p.id OFFSET p_desde LIMIT p_limite;
END;
$$;
REVOKE ALL ON FUNCTION public.listar_usuarios_hu020(INTEGER,INTEGER) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.listar_usuarios_hu020(INTEGER,INTEGER) TO authenticated;



-- Validación y normalización ÚNICA de los datos de perfil. La reutilizan la
-- edición (administrar_usuario_hu020) y el alta (registrar_perfil_usuario_hu021),
-- de modo que ambas operaciones aplican exactamente las mismas reglas.
-- Recibe el JSON enviado por la app y, opcionalmente, el UUID del perfil que se
-- edita (para excluirlo de las comprobaciones de unicidad). Devuelve el JSON
-- normalizado o lanza una excepción con un mensaje apto para mostrar al usuario.
CREATE OR REPLACE FUNCTION public.hu021_normalizar_perfil(p_datos JSONB, p_id UUID DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql STABLE SET search_path = '' AS $$
DECLARE
  v_nombres TEXT; v_apellidos TEXT; v_usuario TEXT; v_cargo TEXT; v_rol TEXT;
  v_colegio TEXT; v_numero TEXT; v_especialidad TEXT;
  v_token TEXT; v_codigo TEXT; v_areas TEXT[] := '{}';
BEGIN
  IF p_datos IS NULL OR jsonb_typeof(p_datos) <> 'object' THEN
    RAISE EXCEPTION 'Datos de usuario inválidos.';
  END IF;

  v_nombres   := regexp_replace(btrim(COALESCE(p_datos->>'nombres', '')), '\s+', ' ', 'g');
  v_apellidos := regexp_replace(btrim(COALESCE(p_datos->>'apellidos', '')), '\s+', ' ', 'g');
  IF length(v_nombres) < 2 OR length(v_nombres) > 80 THEN
    RAISE EXCEPTION 'Escribe los nombres (2 a 80 caracteres).';
  END IF;
  IF length(v_apellidos) < 2 OR length(v_apellidos) > 80 THEN
    RAISE EXCEPTION 'Escribe los apellidos (2 a 80 caracteres).';
  END IF;

  v_usuario := lower(btrim(COALESCE(p_datos->>'nombre_usuario', '')));
  IF v_usuario !~ '^[a-z0-9][a-z0-9_.-]{2,31}$' THEN
    RAISE EXCEPTION 'El nombre de usuario debe tener 3 a 32 caracteres: minúsculas, números, punto, guion o guion bajo.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.profiles
             WHERE lower(btrim(nombre_usuario)) = v_usuario AND id IS DISTINCT FROM p_id) THEN
    RAISE EXCEPTION 'Ese nombre de usuario ya está registrado.';
  END IF;

  v_cargo := NULLIF(btrim(COALESCE(p_datos->>'cargo', '')), '');
  IF v_cargo IS NOT NULL AND length(v_cargo) > 80 THEN
    RAISE EXCEPTION 'El cargo no puede superar 80 caracteres.';
  END IF;

  -- Datos opcionales: colegio y número se completan juntos.
  -- Conservar ceros iniciales no equivale a verificar habilitación profesional.
  v_colegio := NULLIF(upper(btrim(COALESCE(p_datos->>'colegio_codigo',''))),'');
  v_numero := NULLIF(btrim(COALESCE(p_datos->>'numero_colegiatura','')),'');
  v_especialidad := NULLIF(btrim(COALESCE(p_datos->>'especialidad_codigo','')),'');
  IF v_colegio IS NULL THEN
    IF v_numero IS NOT NULL OR v_especialidad IS NOT NULL THEN
      RAISE EXCEPTION 'Selecciona el colegio profesional de la colegiatura o especialidad.';
    END IF;
  ELSE
    IF v_numero IS NULL OR v_numero !~ '^[0-9]{1,20}$' THEN
      RAISE EXCEPTION 'Ingresa el número de colegiatura (solo dígitos, máximo 20).';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.colegios_profesionales WHERE codigo=v_colegio) THEN
      RAISE EXCEPTION 'Colegio profesional desconocido.';
    END IF;
    IF v_especialidad IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.especialidades_profesionales
      WHERE codigo=v_especialidad AND colegio_codigo=v_colegio
    ) THEN RAISE EXCEPTION 'La especialidad no corresponde al colegio profesional.'; END IF;
  END IF;

  v_rol := p_datos->>'rol';
  IF v_rol IS NULL OR v_rol NOT IN ('ADMINISTRADOR','JEFATURA_FARMACIA','FARMACIA','ALMACEN','ENFERMERIA') THEN
    RAISE EXCEPTION 'Selecciona un rol válido.';
  END IF;

  IF jsonb_typeof(p_datos->'areas') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Las áreas asignadas deben enviarse como una lista.';
  END IF;
  -- Cada área se guarda con su alias operativo (areas.codigo). Una asignación
  -- histórica desconocida solo se conserva si el usuario ya la tenía.
  FOR v_token IN SELECT DISTINCT btrim(x) FROM jsonb_array_elements_text(p_datos->'areas') AS t(x) LOOP
    v_codigo := NULL;
    SELECT a.codigo INTO v_codigo FROM public.areas a
      WHERE upper(a.codigo) = upper(v_token) OR upper(a.codigo_interno) = upper(v_token)
         OR lower(a.nombre) = lower(v_token)
      ORDER BY a.id LIMIT 1;
    IF v_codigo IS NOT NULL THEN
      v_areas := v_areas || v_codigo;
    ELSIF EXISTS (SELECT 1 FROM public.profiles WHERE id = p_id AND v_token = ANY(areas_asignadas)) THEN
      v_areas := v_areas || v_token;
    ELSE
      RAISE EXCEPTION 'Área desconocida: %', v_token;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'nombres', v_nombres, 'apellidos', v_apellidos,
    'nombre', v_nombres || ' ' || v_apellidos,
    'nombre_usuario', v_usuario, 'cargo', v_cargo,
    'colegio_codigo',v_colegio,'numero_colegiatura',v_numero,'especialidad_codigo',v_especialidad,
    'rol', v_rol, 'areas', to_jsonb(ARRAY(SELECT DISTINCT unnest(v_areas) ORDER BY 1)));
END;
$$;
REVOKE ALL ON FUNCTION public.hu021_normalizar_perfil(JSONB, UUID) FROM PUBLIC, anon, authenticated;

-- Edición y habilitación de usuarios (HU-020 / HU-022). Solo Administrador activo.
-- p_accion: EDITAR (usa p_datos con los campos del perfil) o ESTADO (p_datos.activo).
-- Reglas de seguridad: no se puede deshabilitar ni quitar el rol a la propia cuenta
-- y siempre debe quedar al menos un Administrador activo. El correo no se edita aquí
-- porque pertenece a Supabase Auth. Registra el antes/después sin tokens FCM.
CREATE OR REPLACE FUNCTION public.administrar_usuario_hu020(
  p_accion TEXT, p_id UUID, p_datos JSONB DEFAULT '{}'::JSONB
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_antes public.profiles%ROWTYPE; v_normal JSONB; v_despues JSONB; v_activo BOOLEAN;
  v_pierde_admin BOOLEAN;
BEGIN
  IF public.sitra_rol_actual() IS DISTINCT FROM 'ADMINISTRADOR' THEN
    RAISE EXCEPTION 'Solo Administrador puede gestionar usuarios.' USING ERRCODE = '42501';
  END IF;
  IF p_accion IS NULL OR p_accion NOT IN ('EDITAR','ESTADO') OR p_id IS NULL THEN
    RAISE EXCEPTION 'Operación de usuario inválida.';
  END IF;
  -- Serializa los cambios para que dos administradores no dejen el sistema sin ninguno activo.
  PERFORM pg_advisory_xact_lock(12020, 2);
  SELECT * INTO v_antes FROM public.profiles WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'El usuario ya no existe.'; END IF;

  IF p_accion = 'ESTADO' THEN
    IF jsonb_typeof(p_datos->'activo') IS DISTINCT FROM 'boolean' THEN
      RAISE EXCEPTION 'Estado inválido.';
    END IF;
    v_activo := (p_datos->>'activo')::BOOLEAN;
    v_pierde_admin := NOT v_activo;
  ELSE
    v_normal := public.hu021_normalizar_perfil(p_datos, p_id);
    v_pierde_admin := (v_normal->>'rol') <> 'ADMINISTRADOR';
    IF p_id = auth.uid() AND (v_normal->>'rol') <> v_antes.rol THEN
      RAISE EXCEPTION 'No puedes cambiar el rol de tu propia cuenta.';
    END IF;
  END IF;

  IF p_accion = 'ESTADO' AND NOT v_activo AND p_id = auth.uid() THEN
    RAISE EXCEPTION 'No puedes deshabilitar tu propia cuenta.';
  END IF;
  IF v_pierde_admin AND v_antes.rol = 'ADMINISTRADOR' AND v_antes.activo AND NOT EXISTS (
       SELECT 1 FROM public.profiles WHERE rol = 'ADMINISTRADOR' AND activo AND id <> p_id) THEN
    RAISE EXCEPTION 'Debe quedar al menos un Administrador activo.';
  END IF;

  BEGIN
    IF p_accion = 'ESTADO' THEN
      UPDATE public.profiles SET activo = v_activo, updated_at = now() WHERE id = p_id;
    ELSE
      UPDATE public.profiles SET
        nombres = v_normal->>'nombres', apellidos = v_normal->>'apellidos',
        nombre = v_normal->>'nombre', nombre_usuario = v_normal->>'nombre_usuario',
        cargo = v_normal->>'cargo',
        rol = v_normal->>'rol',
        colegio_codigo = v_normal->>'colegio_codigo',
        numero_colegiatura = v_normal->>'numero_colegiatura',
        especialidad_codigo = v_normal->>'especialidad_codigo',
        areas_asignadas = ARRAY(SELECT jsonb_array_elements_text(v_normal->'areas')),
        updated_at = now()
      WHERE id = p_id;
    END IF;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Ese nombre de usuario ya está registrado.';
  END;

  SELECT to_jsonb(p.*) - 'fcm_token' - 'correo_drive' INTO v_despues FROM public.profiles p WHERE p.id = p_id;
  INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
    usuario_id, estado_anterior, estado_nuevo, descripcion)
  VALUES('USUARIO_' || p_accion, p_id, 'profiles', auth.uid(),
    to_jsonb(v_antes) - 'fcm_token' - 'correo_drive', v_despues, 'Administración de usuario: ' || p_accion);
  RETURN p_id;
END;
$$;
REVOKE ALL ON FUNCTION public.administrar_usuario_hu020(TEXT, UUID, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.administrar_usuario_hu020(TEXT, UUID, JSONB) TO authenticated;

-- Completa y activa el perfil de una cuenta recién creada en Supabase Auth (HU-021).
-- SOLO la Edge Function `crear-usuario` puede llamarla (rol service_role): la función
-- recibe el UUID del administrador que solicita el alta y lo vuelve a validar.
-- El perfil lo crea handle_new_user con activo = false; esta función solo acepta
-- perfiles en ese estado para que no pueda reutilizarse sobre usuarios existentes.
CREATE OR REPLACE FUNCTION public.registrar_perfil_usuario_hu021(
  p_admin_id UUID, p_id UUID, p_datos JSONB
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_normal JSONB; v_despues JSONB;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles
                 WHERE id = p_admin_id AND rol = 'ADMINISTRADOR' AND activo) THEN
    RAISE EXCEPTION 'Solo Administrador puede crear usuarios.' USING ERRCODE = '42501';
  END IF;
  PERFORM pg_advisory_xact_lock(12020, 2);
  v_normal := public.hu021_normalizar_perfil(p_datos, p_id);
  BEGIN
    UPDATE public.profiles SET
      nombres = v_normal->>'nombres', apellidos = v_normal->>'apellidos',
      nombre = v_normal->>'nombre', nombre_usuario = v_normal->>'nombre_usuario',
      cargo = v_normal->>'cargo',
      rol = v_normal->>'rol',
        colegio_codigo = v_normal->>'colegio_codigo',
        numero_colegiatura = v_normal->>'numero_colegiatura',
        especialidad_codigo = v_normal->>'especialidad_codigo',
      areas_asignadas = ARRAY(SELECT jsonb_array_elements_text(v_normal->'areas')),
      activo = true, updated_at = now()
    WHERE id = p_id AND activo = false;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Ese nombre de usuario ya está registrado.';
  END;
  IF NOT FOUND THEN RAISE EXCEPTION 'No se encontró el perfil pendiente de la nueva cuenta.'; END IF;

  SELECT to_jsonb(p.*) - 'fcm_token' - 'correo_drive' INTO v_despues FROM public.profiles p WHERE p.id = p_id;
  INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
    usuario_id, estado_nuevo, descripcion)
  VALUES('USUARIO_CREAR', p_id, 'profiles', p_admin_id, v_despues, 'Alta de usuario');
  RETURN p_id;
END;
$$;
REVOKE ALL ON FUNCTION public.registrar_perfil_usuario_hu021(UUID, UUID, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_perfil_usuario_hu021(UUID, UUID, JSONB) TO service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;

-- 25. Abastecimiento atómico HU-029/HU-030 y reintentos seguros.
-- HU-029/HU-030: creación atómica y reintentos sin duplicar stock ni auditoría.
-- Requiere recepción, HU-002 y HU-012. No reconstruye ni siembra la base existente.
BEGIN;

ALTER TABLE public.pedidos_abastecimiento
  ADD COLUMN IF NOT EXISTS solicitud_id UUID,
  ADD COLUMN IF NOT EXISTS solicitud_datos JSONB;
CREATE UNIQUE INDEX IF NOT EXISTS uq_pedido_solicitud_usuario
  ON public.pedidos_abastecimiento(solicitante_id,solicitud_id) WHERE solicitud_id IS NOT NULL;
CREATE SEQUENCE IF NOT EXISTS public.pedido_abastecimiento_codigo_seq;
REVOKE ALL ON SEQUENCE public.pedido_abastecimiento_codigo_seq FROM PUBLIC,anon,authenticated;

-- El solicitante sale de auth.uid(); no se acepta un actor ni estado del cliente.
-- La firma JSON conserva los datos originales, aunque luego cambie el estado.
CREATE OR REPLACE FUNCTION public.crear_pedido_abastecimiento(
  p_solicitud_id UUID, p_area_destino TEXT, p_turno TEXT, p_justificacion TEXT,
  p_notas TEXT DEFAULT NULL, p_items JSONB DEFAULT '{}'::JSONB
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_usuario UUID := auth.uid();
  v_rol TEXT := public.sitra_rol_actual();
  v_pedido public.pedidos_abastecimiento%ROWTYPE;
  v_datos JSONB;
  v_items JSONB;
  v_numero BIGINT;
BEGIN
  IF v_usuario IS NULL OR v_rol IS NULL OR v_rol NOT IN ('FARMACIA','ADMINISTRADOR') THEN
    RAISE EXCEPTION 'Solo Farmacia o Administración pueden crear solicitudes.' USING ERRCODE='42501';
  END IF;
  IF p_solicitud_id IS NULL OR p_area_destino IS DISTINCT FROM 'ALMACEN'
     OR p_turno IS NULL OR p_turno NOT IN ('DIA','TARDE','NOCHE')
     OR p_justificacion IS NULL OR p_justificacion NOT IN ('STOCK_CERO','RELLENAR_STOCK') THEN
    RAISE EXCEPTION 'Solicitud, destino, turno o justificación inválidos.';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items)<>'object' OR p_items='{}'::JSONB THEN
    RAISE EXCEPTION 'Agrega al menos un medicamento con cantidad mayor que cero.';
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_each(p_items) x
    WHERE x.key !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      OR jsonb_typeof(x.value)<>'number' OR x.value::TEXT !~ '^[1-9][0-9]*$') THEN
    RAISE EXCEPTION 'Los medicamentos y cantidades enteras deben ser válidos.';
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_each(p_items) x WHERE (x.value::TEXT)::NUMERIC>2147483647) THEN
    RAISE EXCEPTION 'La cantidad solicitada supera el límite permitido.';
  END IF;
  v_datos:=jsonb_build_object('destino',p_area_destino,'turno',p_turno,
    'justificacion',p_justificacion,'notas',NULLIF(btrim(p_notas),''),'items',p_items);

  -- Serializa dos envíos simultáneos con la misma clave antes de buscar el pedido.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_usuario::TEXT||':'||p_solicitud_id::TEXT,29));
  SELECT * INTO v_pedido FROM public.pedidos_abastecimiento
    WHERE solicitante_id=v_usuario AND solicitud_id=p_solicitud_id;
  IF FOUND THEN
    IF v_pedido.solicitud_datos IS DISTINCT FROM v_datos THEN
      RAISE EXCEPTION 'La clave de envío ya corresponde a otra solicitud.';
    END IF;
    SELECT COALESCE(jsonb_agg(to_jsonb(i) ORDER BY i.id),'[]'::JSONB) INTO v_items
      FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=v_pedido.id;
    RETURN to_jsonb(v_pedido)||jsonb_build_object('items',v_items);
  END IF;

  -- Comparte bloqueos con la deshabilitación del catálogo y de las áreas.
  PERFORM id FROM public.areas WHERE codigo IN ('FARMACIA','ALMACEN') ORDER BY id FOR SHARE;
  IF (SELECT count(*) FROM public.areas WHERE codigo IN ('FARMACIA','ALMACEN') AND activo)<>2 THEN
    RAISE EXCEPTION 'Farmacia y Almacén deben estar habilitados para nuevas solicitudes.';
  END IF;
  PERFORM m.id FROM public.medicamentos m JOIN jsonb_object_keys(p_items) x(id)
    ON m.id=x.id::UUID ORDER BY m.id FOR SHARE OF m;
  IF EXISTS (SELECT 1 FROM jsonb_object_keys(p_items) x(id) WHERE NOT EXISTS (
    SELECT 1 FROM public.medicamentos m WHERE m.id=x.id::UUID AND m.activo)) THEN
    RAISE EXCEPTION 'Un medicamento no existe o está deshabilitado.';
  END IF;

  v_numero:=nextval('public.pedido_abastecimiento_codigo_seq');
  INSERT INTO public.pedidos_abastecimiento(codigo,solicitante_id,area_origen,area_destino,
    turno,justificacion,notas,estado,solicitud_id,solicitud_datos)
  VALUES('REQ-'||to_char(CURRENT_DATE,'YYYYMMDD')||'-'||lpad(v_numero::TEXT,GREATEST(6,length(v_numero::TEXT)),'0'),
    v_usuario,'FARMACIA','ALMACEN',p_turno,p_justificacion,NULLIF(btrim(p_notas),''),
    'PENDIENTE',p_solicitud_id,v_datos) RETURNING * INTO v_pedido;
  INSERT INTO public.pedidos_abastecimiento_items(pedido_id,medicamento_id,cantidad_solicitada)
    SELECT v_pedido.id,x.key::UUID,(x.value::TEXT)::INTEGER FROM jsonb_each(p_items) x ORDER BY x.key;
  SELECT jsonb_agg(to_jsonb(i) ORDER BY i.id) INTO v_items
    FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=v_pedido.id;
  INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,
    usuario_id,area_origen,area_destino,estado_nuevo,descripcion,detalles_extra)
  VALUES('CREACION_PEDIDO',v_pedido.id,'pedidos_abastecimiento',v_usuario,'FARMACIA','ALMACEN',
    to_jsonb(v_pedido)||jsonb_build_object('items',v_items),'Creación de solicitud '||v_pedido.codigo,
    jsonb_build_object('solicitud_id',p_solicitud_id,'turno',p_turno,'justificacion',p_justificacion,'items',p_items));
  RETURN to_jsonb(v_pedido)||jsonb_build_object('items',v_items);
END;
$$;
REVOKE ALL ON FUNCTION public.crear_pedido_abastecimiento(UUID,TEXT,TEXT,TEXT,TEXT,JSONB) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.crear_pedido_abastecimiento(UUID,TEXT,TEXT,TEXT,TEXT,JSONB) TO authenticated;

-- Las solicitudes se escriben únicamente a través de las RPC auditadas.
REVOKE INSERT,UPDATE,DELETE ON public.pedidos_abastecimiento,public.pedidos_abastecimiento_items FROM authenticated;
DROP POLICY IF EXISTS hu002_pedidos_creacion ON public.pedidos_abastecimiento;
DROP POLICY IF EXISTS hu002_pedido_items_creacion ON public.pedidos_abastecimiento_items;
-- La ruta antigua de transferencia directa queda retirada del cliente.
-- Registrar un ingreso nuevo sigue pudiendo insertar stock en Almacén (HU-024).
REVOKE UPDATE ON public.inventario_stock FROM authenticated;

-- RPC de atención actualizada a continuación.
CREATE OR REPLACE FUNCTION public.procesar_pedido_abastecimiento(
  p_pedido_id UUID,
  p_accion TEXT,
  p_motivo TEXT DEFAULT NULL,
  p_cantidades JSONB DEFAULT '{}'::jsonb,
  p_modalidad TEXT DEFAULT NULL,
  p_notas TEXT DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_usuario UUID := auth.uid();
  v_rol TEXT;
  v_pedido public.pedidos_abastecimiento%ROWTYPE;
  v_item RECORD;
  v_stock RECORD;
  v_despacho RECORD;
  v_cantidad INTEGER;
  v_restante INTEGER;
  v_movimiento INTEGER;
  v_total INTEGER := 0;
  v_devolucion INTEGER;
  v_evento TEXT;
  v_nuevo TEXT;
BEGIN
  SELECT rol INTO v_rol FROM public.profiles WHERE id = v_usuario AND activo;
  IF v_usuario IS NULL OR v_rol IS NULL THEN
    RAISE EXCEPTION 'Inicie sesión con un usuario activo para realizar esta acción.';
  END IF;
  IF p_accion IS NULL OR p_accion NOT IN ('TOMAR', 'CANCELAR', 'RECHAZAR', 'DESPACHAR', 'RECIBIR') THEN
    RAISE EXCEPTION 'Acción de pedido no válida.';
  END IF;
  IF v_rol <> 'ADMINISTRADOR' AND (
     p_accion IN ('CANCELAR', 'RECIBIR') AND v_rol <> 'FARMACIA'
     OR p_accion IN ('TOMAR', 'RECHAZAR', 'DESPACHAR') AND v_rol <> 'ALMACEN') THEN
    RAISE EXCEPTION 'Su rol no puede realizar esta acción.';
  END IF;

  SELECT * INTO v_pedido FROM public.pedidos_abastecimiento WHERE id = p_pedido_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'El pedido no existe.'; END IF;
  IF v_pedido.area_origen <> 'FARMACIA' OR v_pedido.area_destino <> 'ALMACEN' THEN
    RAISE EXCEPTION 'Esta operación solo admite pedidos de Farmacia a Almacén.';
  END IF;
  -- Validar el contenido también en un reintento de una transición completada.
  IF p_accion IN ('DESPACHAR','RECIBIR') THEN
    IF p_cantidades IS NULL OR jsonb_typeof(p_cantidades)<>'object' THEN
      RAISE EXCEPTION 'Las cantidades no son válidas.';
    END IF;
    IF EXISTS (SELECT 1 FROM jsonb_each(p_cantidades) x
      WHERE jsonb_typeof(x.value)<>'number' OR x.value::TEXT !~ '^[0-9]+$'
      OR NOT EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i
        WHERE i.pedido_id=p_pedido_id AND i.id::TEXT=x.key)) THEN
      RAISE EXCEPTION 'Indique cantidades enteras de los ítems de este pedido.';
    END IF;
  END IF;

  -- Un reintento idéntico del mismo actor devuelve éxito sin stock ni eventos nuevos.
  IF p_accion='CANCELAR' AND v_rol<>'ADMINISTRADOR'
     AND v_pedido.solicitante_id IS DISTINCT FROM v_usuario THEN
    RAISE EXCEPTION 'Solo el solicitante o Administración pueden cancelar este pedido.' USING ERRCODE='42501';
  END IF;
  IF p_accion='TOMAR' AND v_pedido.estado IN ('EN_PREPARACION','LISTO','COMPLETADO')
     AND v_pedido.responsable_almacen_id=v_usuario THEN RETURN; END IF;
  IF p_accion='CANCELAR' AND v_pedido.estado='CANCELADO' AND v_pedido.cancelado_por=v_usuario
     AND v_pedido.motivo_cancelacion IS NOT DISTINCT FROM NULLIF(btrim(p_motivo),'') THEN RETURN; END IF;
  IF p_accion='RECHAZAR' AND v_pedido.estado='RECHAZADO' AND v_pedido.rechazado_por=v_usuario
     AND v_pedido.motivo_rechazo IS NOT DISTINCT FROM NULLIF(btrim(p_motivo),'') THEN RETURN; END IF;
  IF p_accion='DESPACHAR' AND v_pedido.estado IN ('LISTO','COMPLETADO')
     AND v_pedido.responsable_almacen_id=v_usuario AND v_pedido.modalidad_entrega=p_modalidad
     AND v_pedido.notas_almacen IS NOT DISTINCT FROM NULLIF(btrim(p_notas),'')
     AND NOT EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=p_pedido_id
       AND i.cantidad_despachada IS DISTINCT FROM COALESCE((p_cantidades->>i.id::TEXT)::INTEGER,0))
     THEN RETURN; END IF;
  IF p_accion='RECIBIR' AND v_pedido.estado='COMPLETADO'
     AND v_pedido.responsable_farmacia_id=v_usuario
     AND NOT EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=p_pedido_id
       AND i.cantidad_recibida IS DISTINCT FROM COALESCE((p_cantidades->>i.id::TEXT)::INTEGER,i.cantidad_despachada))
     AND v_pedido.observacion_recepcion IS NOT DISTINCT FROM (
       CASE WHEN EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i
         WHERE i.pedido_id=p_pedido_id AND i.cantidad_recibida<i.cantidad_despachada)
       THEN NULLIF(btrim(p_motivo),'') ELSE NULL END)
     THEN RETURN; END IF;

  IF p_accion = 'CANCELAR' AND v_pedido.estado <> 'PENDIENTE' THEN
    RAISE EXCEPTION 'El pedido ya no está pendiente. Comuníquese físicamente con Almacén si requiere cancelarlo.';
  END IF;
  IF p_accion = 'TOMAR' AND v_pedido.estado <> 'PENDIENTE'
     OR p_accion = 'RECHAZAR' AND v_pedido.estado NOT IN ('PENDIENTE', 'EN_PREPARACION')
     OR p_accion = 'DESPACHAR' AND v_pedido.estado <> 'EN_PREPARACION'
     OR p_accion = 'RECIBIR' AND (v_pedido.estado <> 'LISTO' OR NOT COALESCE(v_pedido.confirmado_almacen, false)) THEN
    RAISE EXCEPTION 'El pedido cambió de estado. Actualice la lista antes de continuar.';
  END IF;
  IF p_accion IN ('CANCELAR', 'RECHAZAR') AND NULLIF(btrim(p_motivo), '') IS NULL THEN
    RAISE EXCEPTION 'Debe indicar un motivo.';
  END IF;

  IF p_accion IN ('DESPACHAR', 'RECIBIR') THEN
    IF p_cantidades IS NULL OR jsonb_typeof(p_cantidades) <> 'object' THEN
      RAISE EXCEPTION 'Las cantidades no son válidas.';
    END IF;
    IF EXISTS (
      SELECT 1 FROM jsonb_each(p_cantidades) x
      WHERE jsonb_typeof(x.value) <> 'number' OR x.value::TEXT !~ '^[0-9]+$'
        OR NOT EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i
                       WHERE i.pedido_id = p_pedido_id AND i.id::TEXT = x.key)
    ) THEN RAISE EXCEPTION 'Indique cantidades enteras de los ítems de este pedido.'; END IF;
    PERFORM id FROM public.pedidos_abastecimiento_items WHERE pedido_id = p_pedido_id ORDER BY id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'El pedido no contiene ítems.'; END IF;
    -- Orden fijo de bloqueo para evitar pérdidas por movimientos concurrentes.
    PERFORM s.id FROM public.inventario_stock s JOIN public.lotes l ON l.id = s.lote_id
      WHERE s.area_codigo IN ('ALMACEN', 'FARMACIA') AND l.medicamento_id IN (
        SELECT medicamento_id FROM public.pedidos_abastecimiento_items WHERE pedido_id = p_pedido_id
      ) ORDER BY s.id FOR UPDATE OF s;
  END IF;

  CASE p_accion
  WHEN 'TOMAR' THEN
    v_nuevo := 'EN_PREPARACION'; v_evento := 'TOMA_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo,
      responsable_almacen_id = v_usuario, fecha_toma = now() WHERE id = p_pedido_id;
  WHEN 'CANCELAR' THEN
    v_nuevo := 'CANCELADO'; v_evento := 'CANCELACION_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo,
      motivo_cancelacion = btrim(p_motivo), fecha_cancelacion = now(), cancelado_por = v_usuario
      WHERE id = p_pedido_id;
  WHEN 'RECHAZAR' THEN
    v_nuevo := 'RECHAZADO'; v_evento := 'RECHAZO_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo,
      motivo_rechazo = btrim(p_motivo), fecha_rechazo = now(), rechazado_por = v_usuario
      WHERE id = p_pedido_id;
  WHEN 'DESPACHAR' THEN
    IF p_modalidad IS NULL OR p_modalidad NOT IN ('ENTREGA', 'RECOJO') THEN
      RAISE EXCEPTION 'Seleccione si Almacén entrega o Farmacia recoge.';
    END IF;
    FOR v_item IN SELECT * FROM public.pedidos_abastecimiento_items WHERE pedido_id = p_pedido_id ORDER BY id LOOP
      v_cantidad := COALESCE((p_cantidades->>v_item.id::TEXT)::INTEGER, 0);
      IF v_cantidad > v_item.cantidad_solicitada THEN
        RAISE EXCEPTION 'El despacho no puede superar la cantidad solicitada.';
      END IF;
      v_restante := v_cantidad;
      FOR v_stock IN
        SELECT s.*, l.fecha_vencimiento FROM public.inventario_stock s
        JOIN public.lotes l ON l.id = s.lote_id
        WHERE s.area_codigo = 'ALMACEN' AND l.medicamento_id = v_item.medicamento_id
          AND l.activo AND l.fecha_vencimiento > CURRENT_DATE AND s.cantidad > 0
        ORDER BY l.fecha_vencimiento, l.id
      LOOP
        EXIT WHEN v_restante = 0;
        v_movimiento := LEAST(v_restante, v_stock.cantidad);
        UPDATE public.inventario_stock SET cantidad = cantidad - v_movimiento, updated_at = now() WHERE id = v_stock.id;
        INSERT INTO public.inventario_stock(lote_id, area_codigo, cantidad)
          VALUES(v_stock.lote_id, 'FARMACIA', v_movimiento)
          ON CONFLICT (lote_id, area_codigo) DO UPDATE
          SET cantidad = public.inventario_stock.cantidad + EXCLUDED.cantidad, updated_at = now();
        INSERT INTO public.pedido_abastecimiento_despachos(item_id, lote_id, cantidad)
          VALUES(v_item.id, v_stock.lote_id, v_movimiento);
        INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
          usuario_id, medicamento_id, lote_id, area_origen, area_destino, cantidad, descripcion)
          VALUES('TRANSFERENCIA_FARMACIA', p_pedido_id, 'pedidos_abastecimiento', v_usuario,
            v_item.medicamento_id, v_stock.lote_id, 'ALMACEN', 'FARMACIA', v_movimiento, 'Despacho de pedido ' || v_pedido.codigo);
        v_restante := v_restante - v_movimiento;
      END LOOP;
      IF v_restante > 0 THEN RAISE EXCEPTION 'Stock disponible insuficiente. Actualice las cantidades antes de despachar.'; END IF;
      UPDATE public.pedidos_abastecimiento_items SET cantidad_despachada = v_cantidad WHERE id = v_item.id;
      v_total := v_total + v_cantidad;
    END LOOP;
    IF v_total = 0 THEN RAISE EXCEPTION 'No se puede despachar un pedido vacío. Utilice Rechazar Solicitud.'; END IF;
    v_nuevo := 'LISTO'; v_evento := 'DESPACHO_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo, modalidad_entrega = p_modalidad,
      confirmado_almacen = true, responsable_almacen_id = v_usuario,
      fecha_listo = now(), fecha_despacho = now(), fecha_confirmacion_almacen = now(),
      notas_almacen = NULLIF(btrim(p_notas), '') WHERE id = p_pedido_id;
  WHEN 'RECIBIR' THEN
    FOR v_item IN SELECT * FROM public.pedidos_abastecimiento_items WHERE pedido_id = p_pedido_id ORDER BY id LOOP
      v_cantidad := COALESCE((p_cantidades->>v_item.id::TEXT)::INTEGER, v_item.cantidad_despachada);
      IF v_cantidad < 0 OR v_cantidad > v_item.cantidad_despachada THEN
        RAISE EXCEPTION 'La cantidad aceptada debe estar entre cero y lo despachado.';
      END IF;
      v_devolucion := v_item.cantidad_despachada - v_cantidad;
      IF v_devolucion > 0 THEN
        IF NULLIF(btrim(p_motivo), '') IS NULL THEN RAISE EXCEPTION 'Indique el motivo de la devolución.'; END IF;
        -- Compatibilidad con despachos anteriores que guardaban un único lote.
        IF NOT EXISTS (SELECT 1 FROM public.pedido_abastecimiento_despachos WHERE item_id = v_item.id) THEN
          IF v_item.lote_id IS NULL THEN
            RAISE EXCEPTION 'El despacho anterior no tiene lote trazable. Revise el movimiento antes de devolver.';
          END IF;
          INSERT INTO public.pedido_abastecimiento_despachos(item_id, lote_id, cantidad)
            VALUES(v_item.id, v_item.lote_id, v_item.cantidad_despachada);
        END IF;
        v_restante := v_devolucion;
        -- Retorna primero los lotes con vencimiento posterior; conserva FEFO en lo aceptado.
        FOR v_despacho IN SELECT d.* FROM public.pedido_abastecimiento_despachos d
          JOIN public.lotes l ON l.id = d.lote_id WHERE d.item_id = v_item.id
          ORDER BY l.fecha_vencimiento DESC, l.id DESC FOR UPDATE OF d
        LOOP
          EXIT WHEN v_restante = 0;
          v_movimiento := LEAST(v_restante, v_despacho.cantidad - v_despacho.cantidad_devuelta);
          IF v_movimiento = 0 THEN CONTINUE; END IF;
          UPDATE public.inventario_stock SET cantidad = cantidad - v_movimiento, updated_at = now()
            WHERE lote_id = v_despacho.lote_id AND area_codigo = 'FARMACIA' AND cantidad >= v_movimiento;
          IF NOT FOUND THEN RAISE EXCEPTION 'Stock de Farmacia insuficiente para devolver el lote. Revise el inventario.'; END IF;
          INSERT INTO public.inventario_stock(lote_id, area_codigo, cantidad)
            VALUES(v_despacho.lote_id, 'ALMACEN', v_movimiento)
            ON CONFLICT (lote_id, area_codigo) DO UPDATE
            SET cantidad = public.inventario_stock.cantidad + EXCLUDED.cantidad, updated_at = now();
          UPDATE public.pedido_abastecimiento_despachos SET cantidad_devuelta = cantidad_devuelta + v_movimiento WHERE id = v_despacho.id;
          INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
            usuario_id, medicamento_id, lote_id, area_origen, area_destino, cantidad, descripcion, detalles_extra)
            VALUES('DEVOLUCION_EN_RECEPCION', p_pedido_id, 'pedidos_abastecimiento', v_usuario,
              v_item.medicamento_id, v_despacho.lote_id, 'FARMACIA', 'ALMACEN', v_movimiento,
              btrim(p_motivo), jsonb_build_object('item_id', v_item.id, 'despachado', v_item.cantidad_despachada, 'aceptado', v_cantidad));
          v_restante := v_restante - v_movimiento;
        END LOOP;
        IF v_restante > 0 THEN RAISE EXCEPTION 'El detalle de lotes no cubre la devolución. Revise el despacho.'; END IF;
      END IF;
      UPDATE public.pedidos_abastecimiento_items SET cantidad_recibida = v_cantidad WHERE id = v_item.id;
      v_total := v_total + v_devolucion;
    END LOOP;
    v_nuevo := 'COMPLETADO'; v_evento := 'RECEPCION_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo, confirmado_farmacia = true,
      responsable_farmacia_id = v_usuario, fecha_confirmacion_farmacia = now(), fecha_recepcion = now(), fecha_completado = now(),
      observacion_recepcion = CASE WHEN v_total > 0 THEN btrim(p_motivo) ELSE NULL END WHERE id = p_pedido_id;
  END CASE;

  INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
    usuario_id, estado_anterior, estado_nuevo, descripcion, detalles_extra)
    VALUES(v_evento, p_pedido_id, 'pedidos_abastecimiento', v_usuario,
      jsonb_build_object('estado', v_pedido.estado), jsonb_build_object('estado', v_nuevo),
      p_accion || ' pedido ' || v_pedido.codigo,
      jsonb_build_object('motivo', p_motivo, 'modalidad', p_modalidad, 'cantidades', p_cantidades));
END;
$$;

REVOKE ALL ON FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) TO authenticated;

NOTIFY pgrst,'reload schema';
COMMIT;


-- INCLUIDA: migracion_stock_transito_y_envios_almacen_2026_10_25.sql
-- Stock disponible solo después del conteo y recepción física en Farmacia.
-- Requiere abastecimiento atómico 25/10/2026. No reescribe movimientos históricos.
BEGIN;
ALTER TABLE public.pedidos_abastecimiento
  ADD COLUMN IF NOT EXISTS despacho_en_transito BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS iniciativa TEXT NOT NULL DEFAULT 'SOLICITUD_FARMACIA'
    CHECK(iniciativa IN ('SOLICITUD_FARMACIA','TRASLADO_ALMACEN'));
ALTER TABLE public.pedido_abastecimiento_despachos
  ADD COLUMN IF NOT EXISTS cantidad_recibida INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.pedido_abastecimiento_despachos DROP CONSTRAINT IF EXISTS despacho_conteo_check;
ALTER TABLE public.pedido_abastecimiento_despachos ADD CONSTRAINT despacho_conteo_check
  CHECK(cantidad_recibida>=0 AND cantidad_recibida+cantidad_devuelta<=cantidad);

CREATE OR REPLACE FUNCTION public.procesar_pedido_abastecimiento(
  p_pedido_id UUID,
  p_accion TEXT,
  p_motivo TEXT DEFAULT NULL,
  p_cantidades JSONB DEFAULT '{}'::jsonb,
  p_modalidad TEXT DEFAULT NULL,
  p_notas TEXT DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_usuario UUID := auth.uid();
  v_rol TEXT;
  v_pedido public.pedidos_abastecimiento%ROWTYPE;
  v_item RECORD;
  v_stock RECORD;
  v_despacho RECORD;
  v_cantidad INTEGER;
  v_restante INTEGER;
  v_movimiento INTEGER;
  v_total INTEGER := 0;
  v_devolucion INTEGER;
  v_aceptada_lote INTEGER;
  v_evento TEXT;
  v_nuevo TEXT;
BEGIN
  SELECT rol INTO v_rol FROM public.profiles WHERE id = v_usuario AND activo;
  IF v_usuario IS NULL OR v_rol IS NULL THEN
    RAISE EXCEPTION 'Inicie sesión con un usuario activo para realizar esta acción.';
  END IF;
  IF p_accion IS NULL OR p_accion NOT IN ('TOMAR', 'CANCELAR', 'RECHAZAR', 'DESPACHAR', 'RECIBIR') THEN
    RAISE EXCEPTION 'Acción de pedido no válida.';
  END IF;
  IF v_rol <> 'ADMINISTRADOR' AND (
     p_accion IN ('CANCELAR', 'RECIBIR') AND v_rol <> 'FARMACIA'
     OR p_accion IN ('TOMAR', 'RECHAZAR', 'DESPACHAR') AND v_rol <> 'ALMACEN') THEN
    RAISE EXCEPTION 'Su rol no puede realizar esta acción.';
  END IF;

  SELECT * INTO v_pedido FROM public.pedidos_abastecimiento WHERE id = p_pedido_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'El pedido no existe.'; END IF;
  IF v_pedido.area_origen <> 'FARMACIA' OR v_pedido.area_destino <> 'ALMACEN' THEN
    RAISE EXCEPTION 'Esta operación solo admite pedidos de Farmacia a Almacén.';
  END IF;
  -- Validar el contenido también en un reintento de una transición completada.
  IF p_accion IN ('DESPACHAR','RECIBIR') THEN
    IF p_cantidades IS NULL OR jsonb_typeof(p_cantidades)<>'object' THEN
      RAISE EXCEPTION 'Las cantidades no son válidas.';
    END IF;
    IF EXISTS (SELECT 1 FROM jsonb_each(p_cantidades) x
      WHERE jsonb_typeof(x.value)<>'number' OR x.value::TEXT !~ '^[0-9]+$'
      OR NOT EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i
        WHERE i.pedido_id=p_pedido_id AND i.id::TEXT=x.key)) THEN
      RAISE EXCEPTION 'Indique cantidades enteras de los ítems de este pedido.';
    END IF;
  END IF;

  -- Un reintento idéntico del mismo actor devuelve éxito sin stock ni eventos nuevos.
  IF p_accion='CANCELAR' AND v_rol<>'ADMINISTRADOR'
     AND v_pedido.solicitante_id IS DISTINCT FROM v_usuario THEN
    RAISE EXCEPTION 'Solo el solicitante o Administración pueden cancelar este pedido.' USING ERRCODE='42501';
  END IF;
  IF p_accion='TOMAR' AND v_pedido.estado IN ('EN_PREPARACION','LISTO','COMPLETADO')
     AND v_pedido.responsable_almacen_id=v_usuario THEN RETURN; END IF;
  IF p_accion='CANCELAR' AND v_pedido.estado='CANCELADO' AND v_pedido.cancelado_por=v_usuario
     AND v_pedido.motivo_cancelacion IS NOT DISTINCT FROM NULLIF(btrim(p_motivo),'') THEN RETURN; END IF;
  IF p_accion='RECHAZAR' AND v_pedido.estado='RECHAZADO' AND v_pedido.rechazado_por=v_usuario
     AND v_pedido.motivo_rechazo IS NOT DISTINCT FROM NULLIF(btrim(p_motivo),'') THEN RETURN; END IF;
  IF p_accion='DESPACHAR' AND v_pedido.estado IN ('LISTO','COMPLETADO')
     AND v_pedido.responsable_almacen_id=v_usuario AND v_pedido.modalidad_entrega=p_modalidad
     AND v_pedido.notas_almacen IS NOT DISTINCT FROM NULLIF(btrim(p_notas),'')
     AND NOT EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=p_pedido_id
       AND i.cantidad_despachada IS DISTINCT FROM COALESCE((p_cantidades->>i.id::TEXT)::INTEGER,0))
     THEN RETURN; END IF;
  IF p_accion='RECIBIR' AND v_pedido.estado='COMPLETADO'
     AND v_pedido.responsable_farmacia_id=v_usuario
     AND NOT EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=p_pedido_id
       AND i.cantidad_recibida IS DISTINCT FROM COALESCE((p_cantidades->>i.id::TEXT)::INTEGER,i.cantidad_despachada))
     AND v_pedido.observacion_recepcion IS NOT DISTINCT FROM (
       CASE WHEN EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i
         WHERE i.pedido_id=p_pedido_id AND i.cantidad_recibida<i.cantidad_despachada)
       THEN NULLIF(btrim(p_motivo),'') ELSE NULL END)
     THEN RETURN; END IF;

  IF p_accion = 'CANCELAR' AND v_pedido.estado <> 'PENDIENTE' THEN
    RAISE EXCEPTION 'El pedido ya no está pendiente. Comuníquese físicamente con Almacén si requiere cancelarlo.';
  END IF;
  IF p_accion = 'TOMAR' AND v_pedido.estado <> 'PENDIENTE'
     OR p_accion = 'RECHAZAR' AND v_pedido.estado NOT IN ('PENDIENTE', 'EN_PREPARACION')
     OR p_accion = 'DESPACHAR' AND v_pedido.estado <> 'EN_PREPARACION'
     OR p_accion = 'RECIBIR' AND (v_pedido.estado <> 'LISTO' OR NOT COALESCE(v_pedido.confirmado_almacen, false)) THEN
    RAISE EXCEPTION 'El pedido cambió de estado. Actualice la lista antes de continuar.';
  END IF;
  IF p_accion IN ('CANCELAR', 'RECHAZAR') AND NULLIF(btrim(p_motivo), '') IS NULL THEN
    RAISE EXCEPTION 'Debe indicar un motivo.';
  END IF;

  IF p_accion IN ('DESPACHAR', 'RECIBIR') THEN
    IF p_cantidades IS NULL OR jsonb_typeof(p_cantidades) <> 'object' THEN
      RAISE EXCEPTION 'Las cantidades no son válidas.';
    END IF;
    IF EXISTS (
      SELECT 1 FROM jsonb_each(p_cantidades) x
      WHERE jsonb_typeof(x.value) <> 'number' OR x.value::TEXT !~ '^[0-9]+$'
        OR NOT EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i
                       WHERE i.pedido_id = p_pedido_id AND i.id::TEXT = x.key)
    ) THEN RAISE EXCEPTION 'Indique cantidades enteras de los ítems de este pedido.'; END IF;
    PERFORM id FROM public.pedidos_abastecimiento_items WHERE pedido_id = p_pedido_id ORDER BY id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'El pedido no contiene ítems.'; END IF;
    -- Orden fijo de bloqueo para evitar pérdidas por movimientos concurrentes.
    PERFORM s.id FROM public.inventario_stock s JOIN public.lotes l ON l.id = s.lote_id
      WHERE s.area_codigo IN ('ALMACEN', 'FARMACIA') AND l.medicamento_id IN (
        SELECT medicamento_id FROM public.pedidos_abastecimiento_items WHERE pedido_id = p_pedido_id
      ) ORDER BY s.id FOR UPDATE OF s;
  END IF;

  CASE p_accion
  WHEN 'TOMAR' THEN
    v_nuevo := 'EN_PREPARACION'; v_evento := 'TOMA_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo,
      responsable_almacen_id = v_usuario, fecha_toma = now() WHERE id = p_pedido_id;
  WHEN 'CANCELAR' THEN
    v_nuevo := 'CANCELADO'; v_evento := 'CANCELACION_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo,
      motivo_cancelacion = btrim(p_motivo), fecha_cancelacion = now(), cancelado_por = v_usuario
      WHERE id = p_pedido_id;
  WHEN 'RECHAZAR' THEN
    v_nuevo := 'RECHAZADO'; v_evento := 'RECHAZO_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo,
      motivo_rechazo = btrim(p_motivo), fecha_rechazo = now(), rechazado_por = v_usuario
      WHERE id = p_pedido_id;
  WHEN 'DESPACHAR' THEN
    IF p_modalidad IS NULL OR p_modalidad NOT IN ('ENTREGA', 'RECOJO') THEN
      RAISE EXCEPTION 'Seleccione si Almacén entrega o Farmacia recoge.';
    END IF;
    FOR v_item IN SELECT * FROM public.pedidos_abastecimiento_items WHERE pedido_id = p_pedido_id ORDER BY id LOOP
      v_cantidad := COALESCE((p_cantidades->>v_item.id::TEXT)::INTEGER, 0);
      IF v_cantidad > v_item.cantidad_solicitada THEN
        RAISE EXCEPTION 'El despacho no puede superar la cantidad solicitada.';
      END IF;
      v_restante := v_cantidad;
      FOR v_stock IN
        SELECT s.*, l.fecha_vencimiento FROM public.inventario_stock s
        JOIN public.lotes l ON l.id = s.lote_id
        WHERE s.area_codigo = 'ALMACEN' AND l.medicamento_id = v_item.medicamento_id
          AND l.activo AND l.fecha_vencimiento > CURRENT_DATE AND s.cantidad > 0
        ORDER BY l.fecha_vencimiento, l.id
      LOOP
        EXIT WHEN v_restante = 0;
        v_movimiento := LEAST(v_restante, v_stock.cantidad);
        UPDATE public.inventario_stock SET cantidad = cantidad - v_movimiento, updated_at = now() WHERE id = v_stock.id;
        -- Estas unidades están en tránsito: no son stock disponible en Farmacia.
        INSERT INTO public.pedido_abastecimiento_despachos(item_id, lote_id, cantidad)
          VALUES(v_item.id, v_stock.lote_id, v_movimiento);
        INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
          usuario_id, medicamento_id, lote_id, area_origen, area_destino, cantidad, descripcion)
          VALUES('SALIDA_A_TRANSITO', p_pedido_id, 'pedidos_abastecimiento', v_usuario,
            v_item.medicamento_id, v_stock.lote_id, 'ALMACEN', 'FARMACIA', v_movimiento, 'Salida a tránsito del pedido ' || v_pedido.codigo);
        v_restante := v_restante - v_movimiento;
      END LOOP;
      IF v_restante > 0 THEN RAISE EXCEPTION 'Stock disponible insuficiente. Actualice las cantidades antes de despachar.'; END IF;
      UPDATE public.pedidos_abastecimiento_items SET cantidad_despachada = v_cantidad WHERE id = v_item.id;
      v_total := v_total + v_cantidad;
    END LOOP;
    IF v_total = 0 THEN RAISE EXCEPTION 'No se puede despachar un pedido vacío. Utilice Rechazar Solicitud.'; END IF;
    v_nuevo := 'LISTO'; v_evento := 'DESPACHO_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo, modalidad_entrega = p_modalidad,
      confirmado_almacen = true, responsable_almacen_id = v_usuario, despacho_en_transito = true,
      fecha_listo = now(), fecha_despacho = now(), fecha_confirmacion_almacen = now(),
      notas_almacen = NULLIF(btrim(p_notas), '') WHERE id = p_pedido_id;
  WHEN 'RECIBIR' THEN
    IF v_pedido.despacho_en_transito THEN
      FOR v_item IN SELECT * FROM public.pedidos_abastecimiento_items WHERE pedido_id=p_pedido_id ORDER BY id LOOP
        v_cantidad:=COALESCE((p_cantidades->>v_item.id::TEXT)::INTEGER,v_item.cantidad_despachada);
        IF v_cantidad<0 OR v_cantidad>v_item.cantidad_despachada THEN
          RAISE EXCEPTION 'La cantidad contada debe estar entre cero y lo despachado.';
        END IF;
        v_devolucion:=v_item.cantidad_despachada-v_cantidad;
        IF v_devolucion>0 AND NULLIF(btrim(p_motivo),'') IS NULL THEN
          RAISE EXCEPTION 'Indique el motivo de la diferencia o devolución.';
        END IF;
        IF (SELECT COALESCE(sum(cantidad),0) FROM public.pedido_abastecimiento_despachos WHERE item_id=v_item.id)
           <>v_item.cantidad_despachada THEN
          RAISE EXCEPTION 'El detalle de lotes no coincide con el despacho.';
        END IF;
        v_restante:=v_cantidad;
        -- Se aceptan primero los lotes con vencimiento más próximo.
        FOR v_despacho IN SELECT d.* FROM public.pedido_abastecimiento_despachos d
          JOIN public.lotes l ON l.id=d.lote_id WHERE d.item_id=v_item.id
          ORDER BY l.fecha_vencimiento,l.id FOR UPDATE OF d
        LOOP
          v_aceptada_lote:=LEAST(v_restante,v_despacho.cantidad);
          v_movimiento:=v_despacho.cantidad-v_aceptada_lote;
          IF v_aceptada_lote>0 THEN
            INSERT INTO public.inventario_stock(lote_id,area_codigo,cantidad)
              VALUES(v_despacho.lote_id,'FARMACIA',v_aceptada_lote)
              ON CONFLICT(lote_id,area_codigo) DO UPDATE
              SET cantidad=public.inventario_stock.cantidad+EXCLUDED.cantidad,updated_at=now();
            INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,
              usuario_id,medicamento_id,lote_id,area_origen,area_destino,cantidad,descripcion,detalles_extra)
            VALUES('RECEPCION_LOTE_FARMACIA',p_pedido_id,'pedidos_abastecimiento',v_usuario,
              v_item.medicamento_id,v_despacho.lote_id,'ALMACEN','FARMACIA',v_aceptada_lote,
              'Cantidad física contada y aceptada en Farmacia',
              jsonb_build_object('item_id',v_item.id,'desde_transito',true,'motivo',p_motivo));
          END IF;
          IF v_movimiento>0 THEN
            INSERT INTO public.inventario_stock(lote_id,area_codigo,cantidad)
              VALUES(v_despacho.lote_id,'ALMACEN',v_movimiento)
              ON CONFLICT(lote_id,area_codigo) DO UPDATE
              SET cantidad=public.inventario_stock.cantidad+EXCLUDED.cantidad,updated_at=now();
            INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,
              usuario_id,medicamento_id,lote_id,area_origen,area_destino,cantidad,descripcion,detalles_extra)
            VALUES('DEVOLUCION_EN_RECEPCION',p_pedido_id,'pedidos_abastecimiento',v_usuario,
              v_item.medicamento_id,v_despacho.lote_id,'FARMACIA','ALMACEN',v_movimiento,btrim(p_motivo),
              jsonb_build_object('item_id',v_item.id,'desde_transito',true,
                'despachado',v_item.cantidad_despachada,'aceptado',v_cantidad));
          END IF;
          UPDATE public.pedido_abastecimiento_despachos
            SET cantidad_recibida=v_aceptada_lote,cantidad_devuelta=v_movimiento WHERE id=v_despacho.id;
          v_restante:=v_restante-v_aceptada_lote;
        END LOOP;
        UPDATE public.pedidos_abastecimiento_items SET cantidad_recibida=v_cantidad WHERE id=v_item.id;
        v_total:=v_total+v_devolucion;
      END LOOP;
    ELSE
      -- Los despachos previos conservan su tratamiento y auditoría originales.
    FOR v_item IN SELECT * FROM public.pedidos_abastecimiento_items WHERE pedido_id = p_pedido_id ORDER BY id LOOP
      v_cantidad := COALESCE((p_cantidades->>v_item.id::TEXT)::INTEGER, v_item.cantidad_despachada);
      IF v_cantidad < 0 OR v_cantidad > v_item.cantidad_despachada THEN
        RAISE EXCEPTION 'La cantidad aceptada debe estar entre cero y lo despachado.';
      END IF;
      v_devolucion := v_item.cantidad_despachada - v_cantidad;
      IF v_devolucion > 0 THEN
        IF NULLIF(btrim(p_motivo), '') IS NULL THEN RAISE EXCEPTION 'Indique el motivo de la devolución.'; END IF;
        -- Compatibilidad con despachos anteriores que guardaban un único lote.
        IF NOT EXISTS (SELECT 1 FROM public.pedido_abastecimiento_despachos WHERE item_id = v_item.id) THEN
          IF v_item.lote_id IS NULL THEN
            RAISE EXCEPTION 'El despacho anterior no tiene lote trazable. Revise el movimiento antes de devolver.';
          END IF;
          INSERT INTO public.pedido_abastecimiento_despachos(item_id, lote_id, cantidad)
            VALUES(v_item.id, v_item.lote_id, v_item.cantidad_despachada);
        END IF;
        v_restante := v_devolucion;
        -- Retorna primero los lotes con vencimiento posterior; conserva FEFO en lo aceptado.
        FOR v_despacho IN SELECT d.* FROM public.pedido_abastecimiento_despachos d
          JOIN public.lotes l ON l.id = d.lote_id WHERE d.item_id = v_item.id
          ORDER BY l.fecha_vencimiento DESC, l.id DESC FOR UPDATE OF d
        LOOP
          EXIT WHEN v_restante = 0;
          v_movimiento := LEAST(v_restante, v_despacho.cantidad - v_despacho.cantidad_devuelta);
          IF v_movimiento = 0 THEN CONTINUE; END IF;
          UPDATE public.inventario_stock SET cantidad = cantidad - v_movimiento, updated_at = now()
            WHERE lote_id = v_despacho.lote_id AND area_codigo = 'FARMACIA' AND cantidad >= v_movimiento;
          IF NOT FOUND THEN RAISE EXCEPTION 'Stock de Farmacia insuficiente para devolver el lote. Revise el inventario.'; END IF;
          INSERT INTO public.inventario_stock(lote_id, area_codigo, cantidad)
            VALUES(v_despacho.lote_id, 'ALMACEN', v_movimiento)
            ON CONFLICT (lote_id, area_codigo) DO UPDATE
            SET cantidad = public.inventario_stock.cantidad + EXCLUDED.cantidad, updated_at = now();
          UPDATE public.pedido_abastecimiento_despachos SET cantidad_devuelta = cantidad_devuelta + v_movimiento WHERE id = v_despacho.id;
          INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
            usuario_id, medicamento_id, lote_id, area_origen, area_destino, cantidad, descripcion, detalles_extra)
            VALUES('DEVOLUCION_EN_RECEPCION', p_pedido_id, 'pedidos_abastecimiento', v_usuario,
              v_item.medicamento_id, v_despacho.lote_id, 'FARMACIA', 'ALMACEN', v_movimiento,
              btrim(p_motivo), jsonb_build_object('item_id', v_item.id, 'despachado', v_item.cantidad_despachada, 'aceptado', v_cantidad));
          v_restante := v_restante - v_movimiento;
        END LOOP;
        IF v_restante > 0 THEN RAISE EXCEPTION 'El detalle de lotes no cubre la devolución. Revise el despacho.'; END IF;
      END IF;
      UPDATE public.pedidos_abastecimiento_items SET cantidad_recibida = v_cantidad WHERE id = v_item.id;
      v_total := v_total + v_devolucion;
    END LOOP;
    END IF;
    v_nuevo := 'COMPLETADO'; v_evento := 'RECEPCION_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo, confirmado_farmacia = true,
      responsable_farmacia_id = v_usuario, fecha_confirmacion_farmacia = now(), fecha_recepcion = now(), fecha_completado = now(),
      observacion_recepcion = CASE WHEN v_total > 0 THEN btrim(p_motivo) ELSE NULL END WHERE id = p_pedido_id;
  END CASE;

  INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
    usuario_id, estado_anterior, estado_nuevo, descripcion, detalles_extra)
    VALUES(v_evento, p_pedido_id, 'pedidos_abastecimiento', v_usuario,
      jsonb_build_object('estado', v_pedido.estado), jsonb_build_object('estado', v_nuevo),
      p_accion || ' pedido ' || v_pedido.codigo,
      jsonb_build_object('motivo', p_motivo, 'modalidad', p_modalidad, 'cantidades', p_cantidades));
END;
$$;

REVOKE ALL ON FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.registrar_abastecimiento_interno(
  p_solicitud_id UUID, p_area_destino TEXT, p_turno TEXT, p_justificacion TEXT,
  p_notas TEXT, p_items JSONB, p_iniciativa TEXT
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_usuario UUID := auth.uid();
  v_rol TEXT := public.sitra_rol_actual();
  v_pedido public.pedidos_abastecimiento%ROWTYPE;
  v_datos JSONB;
  v_items JSONB;
  v_numero BIGINT;
BEGIN
  IF v_usuario IS NULL OR v_rol IS NULL OR p_iniciativa IS NULL OR
     (p_iniciativa='SOLICITUD_FARMACIA' AND v_rol NOT IN ('FARMACIA','ADMINISTRADOR')) OR
     (p_iniciativa='TRASLADO_ALMACEN' AND v_rol NOT IN ('ALMACEN','ADMINISTRADOR')) OR
     p_iniciativa NOT IN ('SOLICITUD_FARMACIA','TRASLADO_ALMACEN') THEN
    RAISE EXCEPTION 'Su rol no puede iniciar esta operación de abastecimiento.' USING ERRCODE='42501';
  END IF;
  IF p_iniciativa='TRASLADO_ALMACEN' AND NULLIF(btrim(p_notas),'') IS NULL THEN
    RAISE EXCEPTION 'Indique el motivo del envío iniciado por Almacén.';
  END IF;
  IF p_solicitud_id IS NULL OR p_area_destino IS DISTINCT FROM 'ALMACEN'
     OR p_turno IS NULL OR p_turno NOT IN ('DIA','TARDE','NOCHE')
     OR p_justificacion IS NULL OR p_justificacion NOT IN ('STOCK_CERO','RELLENAR_STOCK') THEN
    RAISE EXCEPTION 'Solicitud, destino, turno o justificación inválidos.';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items)<>'object' OR p_items='{}'::JSONB THEN
    RAISE EXCEPTION 'Agrega al menos un medicamento con cantidad mayor que cero.';
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_each(p_items) x
    WHERE x.key !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      OR jsonb_typeof(x.value)<>'number' OR x.value::TEXT !~ '^[1-9][0-9]*$') THEN
    RAISE EXCEPTION 'Los medicamentos y cantidades enteras deben ser válidos.';
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_each(p_items) x WHERE (x.value::TEXT)::NUMERIC>2147483647) THEN
    RAISE EXCEPTION 'La cantidad solicitada supera el límite permitido.';
  END IF;
  v_datos:=jsonb_build_object('destino',p_area_destino,'turno',p_turno,
    'justificacion',p_justificacion,'notas',NULLIF(btrim(p_notas),''),'items',p_items,'iniciativa',p_iniciativa);

  -- Serializa dos envíos simultáneos con la misma clave antes de buscar el pedido.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_usuario::TEXT||':'||p_solicitud_id::TEXT,29));
  SELECT * INTO v_pedido FROM public.pedidos_abastecimiento
    WHERE solicitante_id=v_usuario AND solicitud_id=p_solicitud_id;
  IF FOUND THEN
    IF (v_pedido.solicitud_datos||jsonb_build_object('iniciativa',v_pedido.iniciativa)) IS DISTINCT FROM v_datos THEN
      RAISE EXCEPTION 'La clave de envío ya corresponde a otra solicitud.';
    END IF;
    SELECT COALESCE(jsonb_agg(to_jsonb(i) ORDER BY i.id),'[]'::JSONB) INTO v_items
      FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=v_pedido.id;
    RETURN to_jsonb(v_pedido)||jsonb_build_object('items',v_items);
  END IF;

  -- Comparte bloqueos con la deshabilitación del catálogo y de las áreas.
  PERFORM id FROM public.areas WHERE codigo IN ('FARMACIA','ALMACEN') ORDER BY id FOR SHARE;
  IF (SELECT count(*) FROM public.areas WHERE codigo IN ('FARMACIA','ALMACEN') AND activo)<>2 THEN
    RAISE EXCEPTION 'Farmacia y Almacén deben estar habilitados para nuevas solicitudes.';
  END IF;
  PERFORM m.id FROM public.medicamentos m JOIN jsonb_object_keys(p_items) x(id)
    ON m.id=x.id::UUID ORDER BY m.id FOR SHARE OF m;
  IF EXISTS (SELECT 1 FROM jsonb_object_keys(p_items) x(id) WHERE NOT EXISTS (
    SELECT 1 FROM public.medicamentos m WHERE m.id=x.id::UUID AND m.activo)) THEN
    RAISE EXCEPTION 'Un medicamento no existe o está deshabilitado.';
  END IF;

  v_numero:=nextval('public.pedido_abastecimiento_codigo_seq');
  INSERT INTO public.pedidos_abastecimiento(codigo,solicitante_id,area_origen,area_destino,
    turno,justificacion,notas,estado,solicitud_id,solicitud_datos,iniciativa)
  VALUES('REQ-'||to_char(CURRENT_DATE,'YYYYMMDD')||'-'||lpad(v_numero::TEXT,GREATEST(6,length(v_numero::TEXT)),'0'),
    v_usuario,'FARMACIA','ALMACEN',p_turno,p_justificacion,NULLIF(btrim(p_notas),''),
    'PENDIENTE',p_solicitud_id,v_datos,p_iniciativa) RETURNING * INTO v_pedido;
  INSERT INTO public.pedidos_abastecimiento_items(pedido_id,medicamento_id,cantidad_solicitada)
    SELECT v_pedido.id,x.key::UUID,(x.value::TEXT)::INTEGER FROM jsonb_each(p_items) x ORDER BY x.key;
  SELECT jsonb_agg(to_jsonb(i) ORDER BY i.id) INTO v_items
    FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=v_pedido.id;
  INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,
    usuario_id,area_origen,area_destino,estado_nuevo,descripcion,detalles_extra)
  VALUES(CASE WHEN p_iniciativa='TRASLADO_ALMACEN' THEN 'INICIO_TRASLADO_ALMACEN' ELSE 'CREACION_PEDIDO' END,v_pedido.id,'pedidos_abastecimiento',v_usuario,'FARMACIA','ALMACEN',
    to_jsonb(v_pedido)||jsonb_build_object('items',v_items),'Creación de solicitud '||v_pedido.codigo,
    jsonb_build_object('solicitud_id',p_solicitud_id,'turno',p_turno,'justificacion',p_justificacion,'items',p_items));
  RETURN to_jsonb(v_pedido)||jsonb_build_object('items',v_items);
END;
$$;

REVOKE ALL ON FUNCTION public.registrar_abastecimiento_interno(UUID,TEXT,TEXT,TEXT,TEXT,JSONB,TEXT) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.crear_pedido_abastecimiento(
  p_solicitud_id UUID,p_area_destino TEXT,p_turno TEXT,p_justificacion TEXT,
  p_notas TEXT DEFAULT NULL,p_items JSONB DEFAULT '{}'::JSONB
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  RETURN public.registrar_abastecimiento_interno(p_solicitud_id,p_area_destino,p_turno,
    p_justificacion,p_notas,p_items,'SOLICITUD_FARMACIA');
END;
$$;
REVOKE ALL ON FUNCTION public.crear_pedido_abastecimiento(UUID,TEXT,TEXT,TEXT,TEXT,JSONB) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.crear_pedido_abastecimiento(UUID,TEXT,TEXT,TEXT,TEXT,JSONB) TO authenticated;

-- El envío iniciado por Almacén crea y despacha en una transacción.
-- La cantidad que no se selecciona permanece en Almacén; Farmacia aún debe contar.
CREATE OR REPLACE FUNCTION public.iniciar_traslado_almacen(
  p_solicitud_id UUID,p_area_destino TEXT,p_turno TEXT,p_justificacion TEXT,
  p_notas TEXT,p_items JSONB,p_modalidad TEXT DEFAULT 'ENTREGA'
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_respuesta JSONB;v_cantidades JSONB;v_pedido public.pedidos_abastecimiento%ROWTYPE;
BEGIN
  v_respuesta:=public.registrar_abastecimiento_interno(p_solicitud_id,p_area_destino,p_turno,
    p_justificacion,p_notas,p_items,'TRASLADO_ALMACEN');
  SELECT jsonb_object_agg(i.id::TEXT,i.cantidad_solicitada) INTO v_cantidades
    FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=(v_respuesta->>'id')::UUID;
  PERFORM public.procesar_pedido_abastecimiento((v_respuesta->>'id')::UUID,'TOMAR');
  PERFORM public.procesar_pedido_abastecimiento((v_respuesta->>'id')::UUID,'DESPACHAR',NULL,v_cantidades,p_modalidad,p_notas);
  SELECT * INTO v_pedido FROM public.pedidos_abastecimiento WHERE id=(v_respuesta->>'id')::UUID;
  RETURN to_jsonb(v_pedido)||jsonb_build_object('items',(
    SELECT jsonb_agg(to_jsonb(i) ORDER BY i.id) FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=v_pedido.id));
END;
$$;
REVOKE ALL ON FUNCTION public.iniciar_traslado_almacen(UUID,TEXT,TEXT,TEXT,TEXT,JSONB,TEXT) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.iniciar_traslado_almacen(UUID,TEXT,TEXT,TEXT,TEXT,JSONB,TEXT) TO authenticated;

-- Consulta consolidada: el tránsito nunca se suma a disponible en Farmacia.
-- Las reservas de despachos antiguos se restan para no publicar stock sin recibir.
CREATE OR REPLACE FUNCTION public.consultar_stock_ubicaciones(
  p_busqueda TEXT DEFAULT '',p_desde INTEGER DEFAULT 0,p_limite INTEGER DEFAULT 200
) RETURNS TABLE(medicamento_id UUID,nombre TEXT,principio_activo TEXT,gtin TEXT,
  presentacion TEXT,unidad TEXT,activo BOOLEAN,almacen_disponible BIGINT,
  farmacia_disponible BIGINT,en_transito BIGINT,almacen_fisico BIGINT,
  farmacia_fisico BIGINT,pendiente_conciliacion BOOLEAN)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF public.sitra_rol_actual() IS NULL THEN
    RAISE EXCEPTION 'Inicia sesión con un perfil activo.' USING ERRCODE='42501';
  END IF;
  IF p_desde IS NULL OR p_desde<0 OR p_limite IS NULL OR p_limite<1 OR p_limite>500 THEN
    RAISE EXCEPTION 'Paginación inválida.';
  END IF;
  RETURN QUERY
  WITH mov AS (
    SELECT d.lote_id,
      COALESCE(sum(CASE WHEN p.despacho_en_transito
        THEN d.cantidad-d.cantidad_recibida-d.cantidad_devuelta ELSE 0 END),0)::BIGINT nuevo,
      COALESCE(sum(CASE WHEN NOT p.despacho_en_transito
        THEN d.cantidad-d.cantidad_devuelta ELSE 0 END),0)::BIGINT legado
    FROM public.pedido_abastecimiento_despachos d
    JOIN public.pedidos_abastecimiento_items i ON i.id=d.item_id
    JOIN public.pedidos_abastecimiento p ON p.id=i.pedido_id
    WHERE p.estado='LISTO' AND NOT p.confirmado_farmacia GROUP BY d.lote_id
  ), saldos AS (
    SELECT s.lote_id,
      COALESCE(sum(s.cantidad) FILTER(WHERE s.area_codigo='ALMACEN'),0)::BIGINT almacen,
      COALESCE(sum(s.cantidad) FILTER(WHERE s.area_codigo='FARMACIA'),0)::BIGINT farmacia
    FROM public.inventario_stock s WHERE s.area_codigo IN ('ALMACEN','FARMACIA') GROUP BY s.lote_id
  ), por_producto AS (
    SELECT l.medicamento_id,
      COALESCE(sum(CASE WHEN l.activo AND l.fecha_vencimiento>CURRENT_DATE THEN COALESCE(s.almacen,0) ELSE 0 END),0)::BIGINT ad,
      COALESCE(sum(CASE WHEN l.activo AND l.fecha_vencimiento>CURRENT_DATE
        THEN GREATEST(COALESCE(s.farmacia,0)-COALESCE(mv.legado,0),0) ELSE 0 END),0)::BIGINT fd,
      COALESCE(sum(COALESCE(mv.nuevo,0)+COALESCE(mv.legado,0)),0)::BIGINT tr,
      COALESCE(sum(COALESCE(s.almacen,0)),0)::BIGINT af,
      COALESCE(sum(GREATEST(COALESCE(s.farmacia,0)-COALESCE(mv.legado,0),0)),0)::BIGINT ff,
      COALESCE(bool_or(COALESCE(mv.legado,0)>COALESCE(s.farmacia,0)),false) conciliar
    FROM public.lotes l LEFT JOIN saldos s ON s.lote_id=l.id LEFT JOIN mov mv ON mv.lote_id=l.id
    GROUP BY l.medicamento_id
  )
  SELECT m.id,m.nombre_comercial,m.principio_activo,m.gtin,m.presentacion,m.unidad_presentacion,m.activo,
    CASE WHEN m.activo THEN COALESCE(pp.ad,0) ELSE 0 END,
    CASE WHEN m.activo THEN COALESCE(pp.fd,0) ELSE 0 END,
    COALESCE(pp.tr,0),COALESCE(pp.af,0),COALESCE(pp.ff,0),COALESCE(pp.conciliar,false)
  FROM public.medicamentos m LEFT JOIN por_producto pp ON pp.medicamento_id=m.id
  WHERE COALESCE(p_busqueda,'')='' OR m.nombre_comercial ILIKE '%'||p_busqueda||'%'
    OR m.principio_activo ILIKE '%'||p_busqueda||'%' OR m.gtin ILIKE '%'||p_busqueda||'%'
  ORDER BY lower(m.nombre_comercial),m.id OFFSET p_desde LIMIT p_limite;
END;
$$;
REVOKE ALL ON FUNCTION public.consultar_stock_ubicaciones(TEXT,INTEGER,INTEGER) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.consultar_stock_ubicaciones(TEXT,INTEGER,INTEGER) TO authenticated;

NOTIFY pgrst,'reload schema';
COMMIT;


-- INCLUIDA: migracion_diferencias_abastecimiento_2026_10_26.sql
-- Requiere stock en tránsito 25/10/2026. No modifica existencias históricas.
BEGIN;
CREATE TABLE IF NOT EXISTS public.diferencias_abastecimiento(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 pedido_id UUID NOT NULL REFERENCES public.pedidos_abastecimiento(id),
 reportado_por UUID NOT NULL REFERENCES public.profiles(id),
 estado TEXT NOT NULL CHECK(estado IN ('PENDIENTE','PROPUESTA','RESUELTO','CANCELADO','RECHAZADO')),
 conteo JSONB NOT NULL, motivo TEXT NOT NULL CHECK(length(btrim(motivo)) BETWEEN 1 AND 1000),
 propuesta JSONB, destino TEXT CHECK(destino IN ('ALMACEN','PERDIDA','ENTREGA')),
 justificacion TEXT, version INTEGER NOT NULL DEFAULT 1,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS diferencia_activa_pedido ON public.diferencias_abastecimiento(pedido_id)
 WHERE estado IN ('PENDIENTE','PROPUESTA');
CREATE TABLE IF NOT EXISTS public.diferencias_abastecimiento_historial(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 reporte_id UUID NOT NULL REFERENCES public.diferencias_abastecimiento(id),
 usuario_id UUID NOT NULL REFERENCES public.profiles(id),
 operacion_id UUID NOT NULL, accion TEXT NOT NULL, motivo TEXT NOT NULL,
 datos JSONB NOT NULL, resultado JSONB NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(usuario_id,operacion_id)
);
ALTER TABLE public.diferencias_abastecimiento ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diferencias_abastecimiento_historial ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.diferencias_abastecimiento,public.diferencias_abastecimiento_historial FROM PUBLIC,anon,authenticated;

ALTER TABLE public.pedido_abastecimiento_despachos ADD COLUMN IF NOT EXISTS cantidad_perdida INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.pedido_abastecimiento_despachos DROP CONSTRAINT IF EXISTS despacho_conteo_check;
ALTER TABLE public.pedido_abastecimiento_despachos ADD CONSTRAINT despacho_conteo_check
 CHECK(cantidad_recibida>=0 AND cantidad_devuelta>=0 AND cantidad_perdida>=0
 AND cantidad_recibida+cantidad_devuelta+cantidad_perdida<=cantidad);

-- La ruta antigua queda privada y se protege la recepción con reportes abiertos.
DO $$ BEGIN
 IF to_regprocedure('public.procesar_abastecimiento_sin_reporte(uuid,text,text,jsonb,text,text)') IS NULL THEN
  ALTER FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT)
   RENAME TO procesar_abastecimiento_sin_reporte;
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.procesar_abastecimiento_sin_reporte(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.procesar_pedido_abastecimiento(
 p_pedido_id UUID,p_accion TEXT,p_motivo TEXT DEFAULT NULL,p_cantidades JSONB DEFAULT '{}',
 p_modalidad TEXT DEFAULT NULL,p_notas TEXT DEFAULT NULL) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM 1 FROM public.pedidos_abastecimiento WHERE id=p_pedido_id FOR UPDATE;
 IF p_accion='RECIBIR' AND EXISTS(SELECT 1 FROM public.diferencias_abastecimiento
  WHERE pedido_id=p_pedido_id AND estado IN ('PENDIENTE','PROPUESTA')) THEN
  RAISE EXCEPTION 'Hay un reporte pendiente. Revise Diferencias e historial antes de recibir.';
 END IF;
 PERFORM public.procesar_abastecimiento_sin_reporte(p_pedido_id,p_accion,p_motivo,p_cantidades,p_modalidad,p_notas);
END $$;
REVOKE ALL ON FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.huella_stock_diferencia(p_pedido UUID) RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT md5(COALESCE(string_agg(to_jsonb(s)::text,'|' ORDER BY s.lote_id,s.area_codigo),''))
 FROM public.inventario_stock s WHERE s.area_codigo IN ('ALMACEN','FARMACIA')
 AND s.lote_id IN(SELECT l.id FROM public.lotes l JOIN public.pedidos_abastecimiento_items i
 ON i.medicamento_id=l.medicamento_id WHERE i.pedido_id=p_pedido)
$$;
REVOKE ALL ON FUNCTION public.huella_stock_diferencia(UUID) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.gestionar_diferencia_abastecimiento(
 p_pedido_id UUID,p_accion TEXT,p_motivo TEXT,p_cantidades JSONB DEFAULT '{}',
 p_destino TEXT DEFAULT NULL,p_version INTEGER DEFAULT 0,p_operacion_id UUID DEFAULT NULL,
 p_saldo_version TEXT DEFAULT NULL) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 v_actor UUID:=auth.uid(); v_rol TEXT; v_p public.pedidos_abastecimiento%ROWTYPE;
 v_r public.diferencias_abastecimiento%ROWTYPE; v_h RECORD; v_i RECORD; v_d RECORD;
 v_datos JSONB; v_resultado JSONB; v_antes JSONB; v_conteo JSONB; v_destino TEXT;
 v_n INTEGER; v_restante INTEGER; v_aceptado INTEGER; v_diferencia INTEGER; v_evento TEXT;
BEGIN
 SELECT rol INTO v_rol FROM public.profiles WHERE id=v_actor AND activo;
 IF v_actor IS NULL OR v_rol IS NULL OR v_rol NOT IN ('FARMACIA','ALMACEN','ADMINISTRADOR') THEN
  RAISE EXCEPTION 'Su usuario no puede gestionar diferencias.'; END IF;
 IF p_operacion_id IS NULL THEN RAISE EXCEPTION 'Falta la clave de la operación.'; END IF;
 IF p_accion IS NULL OR p_accion NOT IN ('REPORTAR','CANCELAR','RECHAZAR','RESOLVER','CONFIRMAR','DEVOLVER_PROPUESTA') THEN
  RAISE EXCEPTION 'Acción no válida.'; END IF;
 IF p_motivo IS NULL OR length(btrim(p_motivo)) NOT BETWEEN 1 AND 1000 THEN
  RAISE EXCEPTION 'Escriba una justificación de hasta 1000 caracteres.'; END IF;
 v_datos:=jsonb_build_object('pedido',p_pedido_id,'accion',p_accion,'motivo',btrim(p_motivo),
  'cantidades',p_cantidades,'destino',p_destino,'version',p_version,'saldo_version',p_saldo_version);
 PERFORM pg_advisory_xact_lock(hashtextextended(v_actor::text||p_operacion_id::text,0));
 SELECT * INTO v_h FROM public.diferencias_abastecimiento_historial WHERE usuario_id=v_actor AND operacion_id=p_operacion_id;
 IF FOUND THEN
  IF v_h.datos<>v_datos THEN RAISE EXCEPTION 'La clave ya corresponde a otra operación.'; END IF;
  RETURN v_h.resultado;
 END IF;
 SELECT * INTO v_p FROM public.pedidos_abastecimiento WHERE id=p_pedido_id FOR UPDATE;
 IF NOT FOUND OR v_p.estado<>'LISTO' OR NOT v_p.despacho_en_transito THEN
  RAISE EXCEPTION 'El pedido debe estar en tránsito y pendiente de recepción.'; END IF;
 SELECT * INTO v_r FROM public.diferencias_abastecimiento WHERE pedido_id=p_pedido_id
 AND estado IN ('PENDIENTE','PROPUESTA') FOR UPDATE;
 IF p_accion='REPORTAR' THEN
  IF v_rol NOT IN ('FARMACIA','ADMINISTRADOR') THEN RAISE EXCEPTION 'Solo Farmacia reporta su conteo.'; END IF;
  IF v_r.id IS NOT NULL THEN RAISE EXCEPTION 'Ya existe un reporte abierto.'; END IF;
  v_conteo:=p_cantidades;
 ELSE
  IF v_r.id IS NULL OR v_r.version<>p_version THEN RAISE EXCEPTION 'El reporte cambió. Actualice antes de continuar.'; END IF;
  IF p_accion IN ('CANCELAR','CONFIRMAR','DEVOLVER_PROPUESTA') AND v_rol<>'ADMINISTRADOR'
   AND (v_rol<>'FARMACIA' OR v_r.reportado_por<>v_actor) THEN
   RAISE EXCEPTION 'Solo quien reportó en Farmacia puede realizar esta acción.'; END IF;
  IF p_accion IN ('RESOLVER','RECHAZAR') AND v_rol NOT IN ('ALMACEN','ADMINISTRADOR') THEN
   RAISE EXCEPTION 'Solo Almacén revisa y soluciona.'; END IF;
  v_conteo:=CASE WHEN p_accion='RESOLVER' THEN p_cantidades ELSE v_r.propuesta END;
 END IF;
 IF p_accion IN ('REPORTAR','RESOLVER') THEN
  IF v_conteo IS NULL OR jsonb_typeof(v_conteo)<>'object' THEN RAISE EXCEPTION 'Conteo no válido.'; END IF;
  IF (SELECT count(*) FROM jsonb_object_keys(v_conteo))<>(SELECT count(*) FROM public.pedidos_abastecimiento_items WHERE pedido_id=p_pedido_id)
   OR EXISTS(SELECT 1 FROM jsonb_each(v_conteo) x WHERE jsonb_typeof(x.value)<>'number' OR x.value::text !~ '^[0-9]+$'
    OR x.value::numeric>2147483647 OR NOT EXISTS(SELECT 1 FROM public.pedidos_abastecimiento_items i
     WHERE i.pedido_id=p_pedido_id AND i.id::text=x.key AND x.value::numeric<=i.cantidad_despachada)) THEN
   RAISE EXCEPTION 'Revise cada cantidad: debe estar entre cero y lo despachado.'; END IF;
 END IF;
 v_antes:=to_jsonb(v_r);
 IF p_accion='REPORTAR' THEN
  IF NOT EXISTS(SELECT 1 FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=p_pedido_id
   AND (v_conteo->>i.id::text)::integer<i.cantidad_despachada) THEN RAISE EXCEPTION 'El conteo es conforme: utilice recepción conforme.'; END IF;
  INSERT INTO public.diferencias_abastecimiento(pedido_id,reportado_por,estado,conteo,motivo)
   VALUES(p_pedido_id,v_actor,'PENDIENTE',v_conteo,btrim(p_motivo)) RETURNING * INTO v_r;
 ELSIF p_accion IN ('CANCELAR','RECHAZAR') THEN
  UPDATE public.diferencias_abastecimiento SET estado=CASE WHEN p_accion='CANCELAR' THEN 'CANCELADO' ELSE 'RECHAZADO' END,
   version=version+1,updated_at=now() WHERE id=v_r.id RETURNING * INTO v_r;
 ELSIF p_accion='DEVOLVER_PROPUESTA' THEN
  IF v_r.estado<>'PROPUESTA' THEN RAISE EXCEPTION 'No hay propuesta que revisar.'; END IF;
  UPDATE public.diferencias_abastecimiento SET estado='PENDIENTE',propuesta=NULL,destino=NULL,justificacion=NULL,
   version=version+1,updated_at=now() WHERE id=v_r.id RETURNING * INTO v_r;
 ELSE
  IF p_accion='RESOLVER' THEN
   IF v_r.estado<>'PENDIENTE' THEN RAISE EXCEPTION 'Farmacia debe responder primero a la propuesta vigente.'; END IF;
   IF p_destino IS NULL OR p_destino NOT IN ('ALMACEN','PERDIDA','ENTREGA') THEN RAISE EXCEPTION 'Seleccione una solución.'; END IF;
   IF p_destino='ENTREGA' AND EXISTS(SELECT 1 FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=p_pedido_id
    AND (v_conteo->>i.id::text)::integer<>i.cantidad_despachada) THEN RAISE EXCEPTION 'La entrega pendiente requiere confirmar el total despachado.'; END IF;
   UPDATE public.diferencias_abastecimiento SET propuesta=v_conteo,destino=p_destino,justificacion=btrim(p_motivo),
    version=version+1,updated_at=now() WHERE id=v_r.id RETURNING * INTO v_r;
   IF v_conteo<>v_r.conteo THEN
    UPDATE public.diferencias_abastecimiento SET estado='PROPUESTA' WHERE id=v_r.id RETURNING * INTO v_r;
   END IF;
  ELSE
   IF v_r.estado<>'PROPUESTA' THEN RAISE EXCEPTION 'No hay propuesta pendiente de confirmación.'; END IF;
   v_conteo:=v_r.propuesta;
  END IF;
  IF v_r.estado<>'PROPUESTA' OR p_accion='CONFIRMAR' THEN
   -- La vista previa se invalida si otra operación alteró estos lotes.
   LOCK TABLE public.inventario_stock IN SHARE ROW EXCLUSIVE MODE;
   PERFORM 1 FROM public.inventario_stock s WHERE s.lote_id IN(
    SELECT d.lote_id FROM public.pedido_abastecimiento_despachos d JOIN public.pedidos_abastecimiento_items i ON i.id=d.item_id
    WHERE i.pedido_id=p_pedido_id) ORDER BY s.lote_id,s.area_codigo FOR UPDATE;
   IF p_saldo_version IS NULL OR p_saldo_version<>public.huella_stock_diferencia(p_pedido_id) THEN
    RAISE EXCEPTION 'El stock cambió desde la vista previa. Actualice y revise nuevamente.'; END IF;
   v_destino:=v_r.destino;
   FOR v_i IN SELECT * FROM public.pedidos_abastecimiento_items WHERE pedido_id=p_pedido_id ORDER BY id LOOP
    v_n:=(v_conteo->>v_i.id::text)::integer; v_restante:=v_n;
    IF (SELECT COALESCE(sum(cantidad),0) FROM public.pedido_abastecimiento_despachos WHERE item_id=v_i.id)<>v_i.cantidad_despachada THEN
     RAISE EXCEPTION 'Los lotes no coinciden con el despacho; requiere revisión técnica.'; END IF;
    FOR v_d IN SELECT d.* FROM public.pedido_abastecimiento_despachos d JOIN public.lotes l ON l.id=d.lote_id
     WHERE d.item_id=v_i.id ORDER BY l.fecha_vencimiento,l.id FOR UPDATE OF d LOOP
     IF v_d.cantidad_recibida+v_d.cantidad_devuelta+v_d.cantidad_perdida<>0 THEN RAISE EXCEPTION 'El lote ya fue conciliado.'; END IF;
     v_aceptado:=LEAST(v_restante,v_d.cantidad); v_diferencia:=v_d.cantidad-v_aceptado;
     IF v_aceptado>0 THEN
      INSERT INTO public.inventario_stock(lote_id,area_codigo,cantidad) VALUES(v_d.lote_id,'FARMACIA',v_aceptado)
       ON CONFLICT(lote_id,area_codigo) DO UPDATE SET cantidad=public.inventario_stock.cantidad+EXCLUDED.cantidad,updated_at=now();
     END IF;
     IF v_diferencia>0 AND v_destino='ALMACEN' THEN
      INSERT INTO public.inventario_stock(lote_id,area_codigo,cantidad) VALUES(v_d.lote_id,'ALMACEN',v_diferencia)
       ON CONFLICT(lote_id,area_codigo) DO UPDATE SET cantidad=public.inventario_stock.cantidad+EXCLUDED.cantidad,updated_at=now();
     END IF;
     UPDATE public.pedido_abastecimiento_despachos SET cantidad_recibida=v_aceptado,
      cantidad_devuelta=CASE WHEN v_destino='ALMACEN' THEN v_diferencia ELSE 0 END,
      cantidad_perdida=CASE WHEN v_destino='PERDIDA' THEN v_diferencia ELSE 0 END WHERE id=v_d.id;
     INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,usuario_id,
      medicamento_id,lote_id,cantidad,descripcion,detalles_extra)
      VALUES('CONCILIACION_LOTE',v_r.id,'diferencias_abastecimiento',v_actor,v_i.medicamento_id,v_d.lote_id,v_d.cantidad,
       btrim(p_motivo),jsonb_build_object('pedido_id',p_pedido_id,'recibido_farmacia',v_aceptado,
       'reintegrado_almacen',CASE WHEN v_destino='ALMACEN' THEN v_diferencia ELSE 0 END,
       'perdida',CASE WHEN v_destino='PERDIDA' THEN v_diferencia ELSE 0 END,'justificacion_almacen',v_r.justificacion));
     v_restante:=v_restante-v_aceptado;
    END LOOP;
    UPDATE public.pedidos_abastecimiento_items SET cantidad_recibida=v_n WHERE id=v_i.id;
   END LOOP;
   UPDATE public.pedidos_abastecimiento SET estado='COMPLETADO',confirmado_farmacia=true,
    responsable_farmacia_id=CASE WHEN p_accion='CONFIRMAR' THEN v_actor ELSE v_r.reportado_por END,
    fecha_confirmacion_farmacia=now(),fecha_recepcion=now(),fecha_completado=now(),
    observacion_recepcion='Conciliado mediante reporte '||v_r.id WHERE id=p_pedido_id;
   UPDATE public.diferencias_abastecimiento SET estado='RESUELTO',version=version+1,updated_at=now() WHERE id=v_r.id RETURNING * INTO v_r;
  END IF;
 END IF;
 v_resultado:=to_jsonb(v_r);
 INSERT INTO public.diferencias_abastecimiento_historial(reporte_id,usuario_id,operacion_id,accion,motivo,datos,resultado)
 VALUES(v_r.id,v_actor,p_operacion_id,p_accion,btrim(p_motivo),v_datos,v_resultado);
 v_evento:='DIFERENCIA_'||p_accion;
 INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,usuario_id,
 estado_anterior,estado_nuevo,descripcion,detalles_extra) VALUES(v_evento,v_r.id,'diferencias_abastecimiento',v_actor,
 v_antes,v_resultado,btrim(p_motivo),v_datos);
 RETURN v_resultado;
END $$;
REVOKE ALL ON FUNCTION public.gestionar_diferencia_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,INTEGER,UUID,TEXT) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gestionar_diferencia_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,INTEGER,UUID,TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.consultar_diferencias_abastecimiento() RETURNS SETOF JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_rol TEXT; BEGIN
 SELECT rol INTO v_rol FROM public.profiles WHERE id=auth.uid() AND activo;
 IF v_rol IS NULL OR v_rol NOT IN ('FARMACIA','ALMACEN','JEFATURA_FARMACIA','ADMINISTRADOR') THEN
 RAISE EXCEPTION 'Su usuario no puede consultar reportes.'; END IF;
 RETURN QUERY SELECT to_jsonb(r)||jsonb_build_object('codigo',p.codigo,'reportante',u.nombre,
 'saldo_version',public.huella_stock_diferencia(p.id),
 'items',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',i.id,'nombre',m.nombre_comercial,
 'despachado',i.cantidad_despachada,'contado',(r.conteo->>i.id::text)::integer,
 'almacen',COALESCE((SELECT sum(s.cantidad) FROM public.inventario_stock s JOIN public.lotes l ON l.id=s.lote_id
 WHERE l.medicamento_id=i.medicamento_id AND s.area_codigo='ALMACEN'),0),
 'farmacia',COALESCE((SELECT sum(s.cantidad) FROM public.inventario_stock s JOIN public.lotes l ON l.id=s.lote_id
 WHERE l.medicamento_id=i.medicamento_id AND s.area_codigo='FARMACIA'),0)) ORDER BY i.id)
 FROM public.pedidos_abastecimiento_items i JOIN public.medicamentos m ON m.id=i.medicamento_id WHERE i.pedido_id=p.id),'[]'),
 'historial',COALESCE((SELECT jsonb_agg(jsonb_build_object('accion',h.accion,'motivo',h.motivo,'fecha',h.created_at,
 'usuario',pr.nombre,'datos',h.datos,'resultado',h.resultado) ORDER BY h.created_at,h.id)
 FROM public.diferencias_abastecimiento_historial h JOIN public.profiles pr ON pr.id=h.usuario_id WHERE h.reporte_id=r.id),'[]'))
 FROM public.diferencias_abastecimiento r JOIN public.pedidos_abastecimiento p ON p.id=r.pedido_id
 JOIN public.profiles u ON u.id=r.reportado_por
 WHERE v_rol<>'FARMACIA' OR r.reportado_por=auth.uid() ORDER BY r.updated_at DESC;
END $$;
REVOKE ALL ON FUNCTION public.consultar_diferencias_abastecimiento() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.consultar_diferencias_abastecimiento() TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;

