-- OfiNails — esquema inicial para Supabase (SQL Editor)
-- Ejecutá todo este archivo una sola vez en un proyecto nuevo.
create extension if not exists pgcrypto;

create type public.user_role as enum ('client','admin');
create type public.appointment_status as enum ('pendiente','confirmada','completada','cancelada');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text not null default '',
  role public.user_role not null default 'client',
  created_at timestamptz not null default now()
);

create function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name',''),
    coalesce(new.raw_user_meta_data ->> 'phone',''),
    'client'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create table public.services (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text not null default '',
  price numeric(10,2) not null check (price >= 0),
  duration_minutes integer not null default 60 check (duration_minutes between 15 and 480),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.designs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null default 'General',
  image_url text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.business_hours (
  id bigint generated always as identity primary key,
  weekday integer not null unique check (weekday between 0 and 6), -- 0 domingo
  is_open boolean not null default true,
  open_time time not null default '09:00',
  close_time time not null default '17:00',
  break_start time,
  break_end time,
  check (close_time > open_time)
);

insert into public.business_hours(weekday,is_open,open_time,close_time) values
(0,false,'09:00','17:00'),(1,true,'09:00','17:00'),(2,true,'09:00','17:00'),
(3,true,'09:00','17:00'),(4,true,'09:00','17:00'),(5,true,'09:00','17:00'),
(6,true,'09:00','17:00')
on conflict (weekday) do nothing;

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.profiles(id) on delete cascade,
  service_id uuid not null references public.services(id),
  appointment_date date not null,
  start_time time not null,
  end_time time not null,
  note text not null default '',
  status public.appointment_status not null default 'pendiente',
  created_at timestamptz not null default now(),
  check (end_time > start_time)
);

-- Evita que dos reservas activas usen exactamente la misma hora de inicio.
create unique index appointments_unique_active_start
on public.appointments(appointment_date,start_time)
where status <> 'cancelada';

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create function public.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists(select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin');
$$;

-- RPC: calcula la duración y bloquea transacciones concurrentes por día/hora.
create function public.book_appointment(
  p_service_id uuid,
  p_appointment_date date,
  p_start_time time,
  p_note text default ''
) returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_service public.services%rowtype;
  v_end time;
  v_hours public.business_hours%rowtype;
  v_id uuid;
begin
  if v_uid is null then raise exception 'Debés iniciar sesión.'; end if;
  if p_appointment_date < current_date then raise exception 'No se puede reservar una fecha pasada.'; end if;
  select * into v_service from public.services where id=p_service_id and active=true;
  if not found then raise exception 'Servicio no disponible.'; end if;
  v_end := p_start_time + make_interval(mins => v_service.duration_minutes);
  select * into v_hours from public.business_hours where weekday=extract(dow from p_appointment_date)::integer;
  if not found or not v_hours.is_open then raise exception 'El estudio está cerrado ese día.'; end if;
  if p_start_time < v_hours.open_time or v_end > v_hours.close_time then raise exception 'El horario está fuera del horario de atención.'; end if;
  if v_hours.break_start is not null and v_hours.break_end is not null
     and p_start_time < v_hours.break_end and v_end > v_hours.break_start then
     raise exception 'El horario coincide con el descanso del estudio.';
  end if;
  -- Bloqueo asesor para reducir choques concurrentes; el índice único cubre mismo inicio.
  perform pg_advisory_xact_lock(hashtext(p_appointment_date::text), hashtext(p_start_time::text));
  if exists(select 1 from public.appointments a
     where a.appointment_date=p_appointment_date and a.status <> 'cancelada'
       and p_start_time < a.end_time and v_end > a.start_time) then
     raise exception 'SLOT_TAKEN: Ese horario ya está ocupado.';
  end if;
  insert into public.appointments(client_id,service_id,appointment_date,start_time,end_time,note)
  values(v_uid,p_service_id,p_appointment_date,p_start_time,v_end,coalesce(p_note,'')) returning id into v_id;
  insert into public.notifications(user_id,title,body)
  values(v_uid,'Solicitud de cita recibida','Tu solicitud fue registrada y está pendiente de confirmación.');
  return v_id;
end;
$$;

alter table public.profiles enable row level security;
alter table public.services enable row level security;
alter table public.designs enable row level security;
alter table public.business_hours enable row level security;
alter table public.appointments enable row level security;
alter table public.notifications enable row level security;

create policy "profiles read self or admin" on public.profiles for select to authenticated
using (id=auth.uid() or public.is_admin());
create policy "clients update own profile" on public.profiles for update to authenticated
using (id=auth.uid() and role='client') with check (id=auth.uid() and role='client');
create policy "services public read active" on public.services for select to anon,authenticated using (active=true or public.is_admin());
create policy "admin insert services" on public.services for insert to authenticated with check (public.is_admin());
create policy "admin update services" on public.services for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "designs public read active" on public.designs for select to anon,authenticated using (active=true or public.is_admin());
create policy "admin insert designs" on public.designs for insert to authenticated with check (public.is_admin());
create policy "admin update designs" on public.designs for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "hours public read" on public.business_hours for select to anon,authenticated using (true);
create policy "admin manage hours" on public.business_hours for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "appointments read own or admin" on public.appointments for select to authenticated using (client_id=auth.uid() or public.is_admin());
create policy "admin update appointments" on public.appointments for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "notifications read own or admin" on public.notifications for select to authenticated using (user_id=auth.uid() or public.is_admin());
create policy "notifications update own" on public.notifications for update to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());

grant usage on schema public to anon, authenticated;
grant select on public.services, public.designs, public.business_hours to anon, authenticated;
grant select, update on public.profiles to authenticated;
grant insert, update, select on public.services, public.designs, public.business_hours to authenticated;
grant select, update on public.appointments to authenticated;
grant select, update on public.notifications to authenticated;
grant execute on function public.is_admin() to anon, authenticated;
grant execute on function public.book_appointment(uuid,date,time,text) to authenticated;

insert into public.services(name,description,price,duration_minutes) values
('Semi permanente','Color y brillo para tus uñas.',6000,60),
('Rubber base','Refuerzo con acabado elegante.',12000,75),
('Building gel','Estructura y estilo personalizado.',15000,90),
('Gel Calcio','Refuerzo con gel calcio.',12000,60),
('Gel X','Extensiones con sistema Gel X.',15000,90),
('Retiros','Retiro de producto.',2500,30),
('Recubrimiento en uña natural','Refuerzo sobre uña natural.',13000,75),
('Acrílicas','Extensiones acrílicas.',13000,100),
('Polygel','Extensiones con polygel.',14000,100)
on conflict(name) do nothing;

-- IMPORTANTE: después de registrar tu cuenta, asignale el rol admin desde SQL Editor:
-- update public.profiles set role='admin' where id=(select id from auth.users where email='TU_CORREO');
