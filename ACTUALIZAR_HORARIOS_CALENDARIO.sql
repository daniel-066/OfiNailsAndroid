-- OfiNails: horarios de atención, disponibilidad pública sin datos personales y corrección del nombre.
-- Ejecutar en Supabase > SQL Editor > New query.

-- Horario solicitado: lunes a viernes 9:00-20:00; sábado 9:00-17:00; domingo cerrado.
insert into public.business_hours (weekday, is_open, open_time, close_time)
values
  (0, false, '09:00', '17:00'),
  (1, true,  '09:00', '20:00'),
  (2, true,  '09:00', '20:00'),
  (3, true,  '09:00', '20:00'),
  (4, true,  '09:00', '20:00'),
  (5, true,  '09:00', '20:00'),
  (6, true,  '09:00', '17:00')
on conflict (weekday) do update set
  is_open = excluded.is_open,
  open_time = excluded.open_time,
  close_time = excluded.close_time;

-- Corrige el nombre existente, si está guardado con el error tipográfico indicado.
update public.profiles
set full_name = 'Sofia Montiel Díaz'
where lower(trim(full_name)) = 'sofia montiel diz';

-- Devuelve únicamente horas y disponibilidad; nunca expone nombres, teléfonos ni correos de clientas.
create or replace function public.get_day_slots(
  p_date date,
  p_service_id uuid default null
)
returns table(slot_time time without time zone, is_available boolean, status text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_hours public.business_hours%rowtype;
  v_duration integer := 30;
begin
  if p_date is null or p_date < current_date then
    return;
  end if;

  if p_service_id is not null then
    select s.duration_minutes into v_duration
    from public.services s
    where s.id = p_service_id and s.active = true;
    if not found then
      raise exception 'El servicio no está disponible.';
    end if;
  end if;

  select * into v_hours
  from public.business_hours bh
  where bh.weekday = extract(dow from p_date)::integer;

  if not found or not v_hours.is_open then
    return;
  end if;

  return query
  select
    g.slot_start::time without time zone as slot_time,
    not exists (
      select 1
      from public.appointments a
      where a.appointment_date = p_date
        and a.status <> 'cancelada'::public.appointment_status
        and g.slot_start::time < a.end_time
        and (g.slot_start::time + make_interval(mins => v_duration)) > a.start_time
    ) as is_available,
    case when exists (
      select 1
      from public.appointments a
      where a.appointment_date = p_date
        and a.status <> 'cancelada'::public.appointment_status
        and g.slot_start::time < a.end_time
        and (g.slot_start::time + make_interval(mins => v_duration)) > a.start_time
    ) then 'reservado' else 'libre' end as status
  from generate_series(
    (p_date + v_hours.open_time)::timestamp,
    (p_date + v_hours.close_time - make_interval(mins => v_duration))::timestamp,
    interval '30 minutes'
  ) as g(slot_start)
  where (v_hours.break_start is null or v_hours.break_end is null
      or not (g.slot_start::time < v_hours.break_end
          and (g.slot_start::time + make_interval(mins => v_duration)) > v_hours.break_start))
  order by g.slot_start;
end;
$$;

grant execute on function public.get_day_slots(date, uuid) to anon, authenticated;
