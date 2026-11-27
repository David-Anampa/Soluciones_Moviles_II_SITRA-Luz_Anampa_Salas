begin;
create or replace function public.normalizar_procedencia(p_nombre text)
returns text language sql immutable strict set search_path='' as $$
 select lower(regexp_replace(translate(p_nombre,'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun'),'[^A-Za-z0-9]','','g'));
$$;
create table if not exists public.procedencias_paciente (
 codigo text primary key default ('PROC_'||gen_random_uuid()::text),
 nombre text not null check(length(nombre) between 2 and 120),
 normalizado text generated always as (public.normalizar_procedencia(nombre)) stored unique,
 activo boolean not null default true,
 creado_por uuid references public.profiles(id),
 creado_en timestamptz not null default now()
);
insert into public.procedencias_paciente(codigo,nombre) values
 ('EMERGENCIA','Emergencia'),('HOSPITALIZACION','Hospitalización') on conflict do nothing;
alter table public.procedencias_paciente enable row level security;
revoke all on public.procedencias_paciente from public,anon,authenticated;

create or replace function public.registrar_procedencia_ficha(p_nombre text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare limpio text:=regexp_replace(btrim(coalesce(p_nombre,'')),'\s+',' ','g'); r public.procedencias_paciente;
begin
 if coalesce(public.sitra_rol_actual(),'') not in ('ADMINISTRADOR','FARMACIA','ENFERMERIA') then
  raise exception 'No tienes permiso para registrar procedencias' using errcode='42501'; end if;
 if length(limpio) not between 2 and 120 or length(public.normalizar_procedencia(limpio))<2
   or public.normalizar_procedencia(limpio) in ('otro','otros') then raise exception 'Especifica el nombre de la procedencia (2 a 120 caracteres)'; end if;
 perform pg_advisory_xact_lock(hashtextextended(public.normalizar_procedencia(limpio),0));
 select * into r from public.procedencias_paciente where normalizado=public.normalizar_procedencia(limpio);
 if found then
  if not r.activo then raise exception 'Esa procedencia está desactivada. Consulta a Administración'; end if;
  return jsonb_build_object('codigo',r.codigo,'nombre',r.nombre);
 end if;
 insert into public.procedencias_paciente(nombre,creado_por) values(limpio,auth.uid()) returning * into r;
 insert into public.auditoria_trazabilidad(tipo_evento,tabla_referencia,usuario_id,estado_nuevo,descripcion)
 values('PROCEDENCIA_CREAR','procedencias_paciente',auth.uid(),jsonb_build_object('codigo',r.codigo,'nombre',r.nombre),'Procedencia compartida registrada');
 return jsonb_build_object('codigo',r.codigo,'nombre',r.nombre);
end; $$;
revoke all on function public.registrar_procedencia_ficha(text) from public,anon;
grant execute on function public.registrar_procedencia_ficha(text) to authenticated;

-- Conservar el contrato histórico EMERGENCIA/HOSPITALIZACION/OTRO + detalle.
-- Alta/reutilización y ficha quedan atómicas si se guarda directamente Otro.
create or replace function public.catalogar_procedencia_ficha()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare dato jsonb;
begin
 if new.tipo_ficha='GENERAL' and new.procedencia='OTRO' then
  dato:=public.registrar_procedencia_ficha(new.procedencia_detalle);
  if dato->>'codigo' in ('EMERGENCIA','HOSPITALIZACION') then
   new.procedencia:=dato->>'codigo'; new.procedencia_detalle:=null;
  else new.procedencia_detalle:=dato->>'nombre'; end if;
 end if;
 return new;
end; $$;
drop trigger if exists catalogar_procedencia on public.dispensaciones;
create trigger catalogar_procedencia before insert or update of procedencia,procedencia_detalle,tipo_ficha
 on public.dispensaciones for each row execute function public.catalogar_procedencia_ficha();

do $patch$
declare def text; nuevo text;
begin
 def:=pg_get_functiondef('public.contexto_registro_ficha_hu003(text)'::regprocedure);
 if position('procedencias_paciente' in def)>0 then return; end if;
 nuevo:=replace(def,'''doctores'', v_doctores,',
  '''doctores'', v_doctores, ''procedencias'', coalesce((select jsonb_agg(jsonb_build_object(''codigo'',p.codigo,''nombre'',p.nombre) order by p.nombre) from public.procedencias_paciente p where p.activo),''[]''::jsonb),');
 if nuevo=def then raise exception 'Versión de contexto no reconocida; revisar migración'; end if;
 execute nuevo;
end; $patch$;
notify pgrst,'reload schema';
commit;
