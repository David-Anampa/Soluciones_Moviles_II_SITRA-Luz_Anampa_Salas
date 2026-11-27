-- Catálogo administrativo. Conserva IDs y fichas históricas; no crea usuarios.
begin;
alter table public.colegios_profesionales add column if not exists sigla text;
update public.colegios_profesionales set sigla=codigo where sigla is null;
insert into public.colegios_profesionales(codigo,nombre,fuente_url,sigla) values
 ('COP_ODONTO','Colegio Odontológico del Perú','https://www.cop.org.pe/','COP'),
 ('COP_OBST','Colegio de Obstetras del Perú','https://colegiodeobstetras.pe/','COP')
on conflict(codigo) do nothing;

create or replace function public.normalizar_colegiatura(p_numero text)
returns text language sql immutable strict set search_path='' as $$
 select case when n ~ '^[0-9]+$' then coalesce(nullif(ltrim(n,'0'),''),'0') else n end
 from (select upper(regexp_replace(regexp_replace(btrim(p_numero),'^(CMP|CTMP|COP|CEP|CQFP)[[:space:]./-]*([0-9 ./-]+)$','\2','i'),'[^A-Za-z0-9]','','g')) n) x;
$$;
alter table public.doctores add column if not exists colegio_codigo text references public.colegios_profesionales(codigo);
alter table public.doctores add column if not exists numero_colegiatura text;
alter table public.doctores add column if not exists numero_normalizado text
 generated always as (public.normalizar_colegiatura(numero_colegiatura)) stored;
alter table public.doctores add column if not exists updated_at timestamptz not null default now();
create unique index if not exists profesionales_identidad_unica on public.doctores(colegio_codigo,numero_normalizado)
 where colegio_codigo is not null and numero_normalizado is not null;
create table if not exists public.doctor_areas (
 doctor_id uuid references public.doctores(id) on delete restrict,
 area_codigo text references public.areas(codigo) on delete restrict,
 primary key(doctor_id,area_codigo)
);
alter table public.doctor_areas enable row level security;
drop policy if exists doctor_areas_lectura on public.doctor_areas;
create policy doctor_areas_lectura on public.doctor_areas for select to authenticated
 using(public.sitra_rol_actual() is not null);
grant select on public.doctor_areas to authenticated;
revoke insert,update,delete on public.doctores,public.doctor_areas,public.colegios_profesionales from authenticated,anon;

create or replace function public.listar_profesionales_admin()
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if public.sitra_rol_actual() is distinct from 'ADMINISTRADOR' then
  raise exception 'Solo Administración puede gestionar profesionales' using errcode='42501';
 end if;
 return jsonb_build_object(
  'profesionales',coalesce((select jsonb_agg(to_jsonb(d)||jsonb_build_object('areas',
    coalesce((select jsonb_agg(area_codigo order by area_codigo) from public.doctor_areas where doctor_id=d.id),'[]'::jsonb)) order by lower(d.nombre),d.id)
    from public.doctores d),'[]'::jsonb),
  'colegios',coalesce((select jsonb_agg(to_jsonb(c) order by c.nombre) from public.colegios_profesionales c where c.activo),'[]'::jsonb),
  'areas',coalesce((select jsonb_agg(jsonb_build_object('codigo',a.codigo,'nombre',a.nombre,'activo',a.activo) order by a.nombre)
     from public.areas a),'[]'::jsonb));
end; $$;

create or replace function public.guardar_profesional_admin(p_id uuid,p_nombre text,p_colegio text,p_numero text,p_areas text[],p_version timestamptz default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare anterior jsonb; nuevo jsonb; d public.doctores; ids text[];
begin
 if public.sitra_rol_actual() is distinct from 'ADMINISTRADOR' then
  raise exception 'Solo Administración puede gestionar profesionales' using errcode='42501'; end if;
 if p_id is null or length(btrim(coalesce(p_nombre,''))) not between 3 and 160 then raise exception 'Ingresa el nombre completo (3 a 160 caracteres)'; end if;
 if not exists(select 1 from public.colegios_profesionales where codigo=p_colegio and activo) then raise exception 'Selecciona un colegio activo'; end if;
 if coalesce(p_numero,'') !~ '^[A-Za-z0-9 ./-]{1,40}$' or length(public.normalizar_colegiatura(p_numero)) not between 1 and 30 then raise exception 'Ingresa un número de colegiatura válido'; end if;
 select array_agg(distinct x) into ids from unnest(p_areas) x;
 if coalesce(cardinality(ids),0)=0 or exists(select 1 from unnest(ids) x where x is null or not exists(select 1 from public.areas a where a.codigo=x and a.activo)) then raise exception 'Selecciona una o varias áreas activas'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,0));
 select * into d from public.doctores where id=p_id for update;
 if found then
  -- Reintento idéntico de una creación cuya respuesta se perdió.
  if p_version is null and d.nombre=btrim(p_nombre) and d.colegio_codigo=p_colegio and d.numero_colegiatura=btrim(p_numero)
    and not exists((select unnest(ids) except select area_codigo from public.doctor_areas where doctor_id=p_id)
      union all (select area_codigo from public.doctor_areas where doctor_id=p_id except select unnest(ids))) then return p_id; end if;
  if p_version is null or d.updated_at<>p_version then raise exception 'El registro cambió. Actualiza la lista antes de editar'; end if;
  anterior:=to_jsonb(d)||jsonb_build_object('areas',(select jsonb_agg(area_codigo) from public.doctor_areas where doctor_id=p_id));
  update public.doctores set nombre=btrim(p_nombre),colegio_codigo=p_colegio,numero_colegiatura=btrim(p_numero),
   colegiatura=btrim(p_numero),updated_at=clock_timestamp() where id=p_id;
 else
  if p_version is not null then raise exception 'El profesional no existe'; end if;
  insert into public.doctores(id,nombre,colegio_codigo,numero_colegiatura,colegiatura)
   values(p_id,btrim(p_nombre),p_colegio,btrim(p_numero),btrim(p_numero));
 end if;
 delete from public.doctor_areas where doctor_id=p_id;
 insert into public.doctor_areas select p_id,unnest(ids);
 select to_jsonb(t)||jsonb_build_object('areas',to_jsonb(ids)) into nuevo from public.doctores t where id=p_id;
 insert into public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,usuario_id,estado_anterior,estado_nuevo,descripcion)
 values(case when anterior is null then 'PROFESIONAL_CREAR' else 'PROFESIONAL_EDITAR' end,p_id,'doctores',auth.uid(),anterior,nuevo,'Catálogo administrativo de profesionales');
 return p_id;
exception when unique_violation then raise exception 'Ya existe un profesional con ese colegio y número de colegiatura' using errcode='23505';
end; $$;

create or replace function public.estado_profesional_admin(p_id uuid,p_activo boolean,p_version timestamptz)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare d public.doctores;
begin
 if public.sitra_rol_actual() is distinct from 'ADMINISTRADOR' then raise exception 'Solo Administración puede gestionar profesionales' using errcode='42501'; end if;
 select * into d from public.doctores where id=p_id for update;
 if not found or p_version is null or d.updated_at<>p_version then raise exception 'Actualiza la lista antes de cambiar el estado'; end if;
 if p_activo is null then raise exception 'Estado no válido'; end if;
 if p_activo and (d.colegio_codigo is null or d.numero_normalizado is null or not exists(select 1 from public.doctor_areas da join public.areas a on a.codigo=da.area_codigo where da.doctor_id=p_id and a.activo)) then raise exception 'Completa colegiatura y áreas antes de activar'; end if;
 if d.activo=p_activo then return; end if;
 update public.doctores set activo=p_activo,updated_at=clock_timestamp() where id=p_id;
 insert into public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,usuario_id,estado_anterior,estado_nuevo,descripcion)
 values('PROFESIONAL_ESTADO',p_id,'doctores',auth.uid(),to_jsonb(d),jsonb_build_object('activo',p_activo),'Cambio de disponibilidad del profesional; historial conservado');
end; $$;

create or replace function public.agregar_colegio_admin(p_nombre text,p_sigla text)
returns text language plpgsql security definer set search_path=public,pg_temp as $$
declare clave text; nombre_limpio text:=regexp_replace(btrim(coalesce(p_nombre,'')),'\s+',' ','g');
begin
 if public.sitra_rol_actual() is distinct from 'ADMINISTRADOR' then raise exception 'Solo Administración puede gestionar colegios' using errcode='42501'; end if;
 if length(nombre_limpio) not between 5 and 160 or coalesce(p_sigla,'') !~ '^[A-Za-z0-9]{2,12}$' then raise exception 'Completa nombre oficial y sigla del colegio'; end if;
 perform pg_advisory_xact_lock(hashtextextended(lower(regexp_replace(translate(nombre_limpio,'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun'),'[^A-Za-z0-9]','','g')),0));
 select codigo into clave from public.colegios_profesionales where lower(regexp_replace(translate(nombre,'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun'),'[^A-Za-z0-9]','','g'))=lower(regexp_replace(translate(nombre_limpio,'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun'),'[^A-Za-z0-9]','','g'));
 if clave is not null and not exists(select 1 from public.colegios_profesionales where codigo=clave and activo) then raise exception 'Ese colegio ya existe y está inactivo'; end if;
 if clave is not null then return clave; end if;
 clave:='CP_'||gen_random_uuid()::text;
 insert into public.colegios_profesionales(codigo,nombre,sigla,fuente_url) values(clave,nombre_limpio,upper(p_sigla),'');
 insert into public.auditoria_trazabilidad(tipo_evento,tabla_referencia,usuario_id,estado_nuevo,descripcion)
 values('COLEGIO_CREAR','colegios_profesionales',auth.uid(),jsonb_build_object('codigo',clave,'nombre',nombre_limpio,'sigla',upper(p_sigla)),'Colegio registrado por Administración');
 return clave;
end; $$;

-- La restricción de área se aplica al guardar, aunque se altere el cliente.
create or replace function public.validar_profesional_area_ficha()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.doctor_id is null or not exists(select 1 from public.doctores d join public.doctor_areas da on da.doctor_id=d.id
    join public.areas a on a.codigo=da.area_codigo join public.colegios_profesionales c on c.codigo=d.colegio_codigo and c.activo where d.id=new.doctor_id and d.activo
    and d.colegio_codigo is not null and d.numero_normalizado is not null and a.activo and da.area_codigo=new.area_origen) then
  raise exception 'Selecciona un profesional activo registrado para el área solicitante'; end if;
 return new;
end; $$;
drop trigger if exists validar_profesional_area on public.dispensaciones;
create trigger validar_profesional_area before insert or update of doctor_id,area_origen on public.dispensaciones
 for each row execute function public.validar_profesional_area_ficha();

-- Extender contexto vigente sin reemplazar correcciones previas de receptor/stock.
do $patch$
declare def text; nuevo text;
begin
 def:=pg_get_functiondef('public.contexto_registro_ficha_hu003(text)'::regprocedure);
 if position('colegio_sigla' in def)>0 then return; end if;
 nuevo:=replace(def,'''especialidad'', d.especialidad',
   '''especialidad'', d.especialidad, ''colegio_codigo'', d.colegio_codigo, ''colegio_sigla'', (select c.sigla from public.colegios_profesionales c where c.codigo=d.colegio_codigo), ''areas'', coalesce((select jsonb_agg(da.area_codigo) from public.doctor_areas da where da.doctor_id=d.id),''[]''::jsonb)');
 if nuevo=def and position('colegio_sigla' in def)=0 then raise exception 'Versión de contexto no reconocida; revisar migración'; end if;
 execute nuevo;
end; $patch$;
revoke all on function public.listar_profesionales_admin(),public.guardar_profesional_admin(uuid,text,text,text,text[],timestamptz),public.estado_profesional_admin(uuid,boolean,timestamptz),public.agregar_colegio_admin(text,text) from public,anon;
grant execute on function public.listar_profesionales_admin(),public.guardar_profesional_admin(uuid,text,text,text,text[],timestamptz),public.estado_profesional_admin(uuid,boolean,timestamptz),public.agregar_colegio_admin(text,text) to authenticated;
notify pgrst,'reload schema';
commit;
