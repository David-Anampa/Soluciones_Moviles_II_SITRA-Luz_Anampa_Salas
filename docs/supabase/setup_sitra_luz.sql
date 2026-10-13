-- ============================================================================
-- SITRA-Luz • Sistema de Trazabilidad — Clínica La Luz (Sede Tacna)
-- Script de Creación y Configuración Completa de Base de Datos en Supabase (PostgreSQL)
-- Esquema consultado en Supabase: 13 de octubre de 2026.
-- ============================================================================
-- Instrucciones:
-- 1. Ingresa a tu proyecto en https://supabase.com
-- 2. Ve a la sección "SQL Editor" en el menú lateral izquierdo.
-- 3. Solo para una base nueva: pega este contenido y presiona "Run".
-- 4. Este setup incluye el detalle por lote y la función transaccional de pedidos.
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

