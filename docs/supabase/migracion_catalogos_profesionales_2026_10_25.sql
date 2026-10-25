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
