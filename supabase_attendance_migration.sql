-- Migration for the existing ambulance_attendance schema.
-- This uses attendance_users, attendance_records, and attendance_settings.
-- It does not create or modify the unrelated dispatch tables.

-- Allow the app to add future job titles without another APK release.
alter table public.attendance_users
  drop constraint if exists attendance_job_title_check;

alter table public.attendance_users
  add constraint attendance_job_title_check
  check (
    job_title is not null
    and char_length(trim(job_title)) between 2 and 100
  );

alter table public.attendance_users
  add column if not exists work_days smallint[]
  not null
  default array[1, 2, 3, 4, 5, 6, 7]::smallint[];

alter table public.attendance_users
  drop constraint if exists attendance_work_days_check;

alter table public.attendance_users
  add constraint attendance_work_days_check
  check (
    work_days <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]
    and cardinality(work_days) > 0
  );

-- The login screen uses profiles.username, while the attendance tables use
-- the Supabase auth user id. The function exposes only the matching email
-- needed by signInWithPassword.
create or replace function public.email_for_username(p_username text)
returns text
language sql
security definer
set search_path = public
as $$
  select au.email
  from auth.users au
  join public.profiles p on p.id = au.id
  where lower(trim(p.username)) = lower(trim(p_username))
    and au.email is not null
  limit 1;
$$;

revoke all on function public.email_for_username(text) from public;
grant execute on function public.email_for_username(text) to anon, authenticated;

-- Only the attendance application tables are hardened here. The other
-- application tables already in the project need their own product policies.
alter table public.attendance_users enable row level security;
alter table public.attendance_records enable row level security;

drop policy if exists "attendance_users_select_self" on public.attendance_users;
drop policy if exists "attendance_users_select_admin" on public.attendance_users;
drop policy if exists "attendance_users_update_admin" on public.attendance_users;
drop policy if exists "attendance_records_select_self" on public.attendance_records;
drop policy if exists "attendance_records_select_admin" on public.attendance_records;
drop policy if exists "attendance_settings_select_authenticated"
  on public.attendance_settings;

create or replace function public.attendance_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.attendance_users admin_user
    where admin_user.id = auth.uid()
      and (
        admin_user.role = 'admin'
        or admin_user.job_title = 'مدير النظام'
      )
  );
$$;

revoke all on function public.attendance_is_admin() from public;
grant execute on function public.attendance_is_admin() to authenticated;

create policy "attendance_users_select_self"
  on public.attendance_users for select
  to authenticated
  using (auth.uid() = id);

create policy "attendance_users_select_admin"
  on public.attendance_users for select
  to authenticated
  using (public.attendance_is_admin());

create policy "attendance_users_update_admin"
  on public.attendance_users for update
  to authenticated
  using (public.attendance_is_admin())
  with check (public.attendance_is_admin());

create policy "attendance_records_select_self"
  on public.attendance_records for select
  to authenticated
  using (auth.uid() = user_id);

create policy "attendance_records_select_admin"
  on public.attendance_records for select
  to authenticated
  using (public.attendance_is_admin());

create policy "attendance_settings_select_authenticated"
  on public.attendance_settings for select
  to authenticated
  using (true);

-- The RPCs below are the only write path for attendance. They use the
-- settings row already present in the project, including its real QR value
-- and center coordinates.
drop index if exists attendance_records_open_user_idx;
create unique index if not exists attendance_records_open_user_idx
  on public.attendance_records (user_id)
  where check_out is null;

create or replace function public.attendance_distance_meters(
  p_latitude double precision,
  p_longitude double precision,
  p_center_latitude double precision,
  p_center_longitude double precision
)
returns double precision
language sql
immutable
strict
as $$
  select 2 * 6371000 * asin(sqrt(
    power(sin(radians(p_latitude - p_center_latitude) / 2), 2)
    + cos(radians(p_center_latitude))
      * cos(radians(p_latitude))
      * power(sin(radians(p_longitude - p_center_longitude) / 2), 2)
  ));
$$;

revoke all on function public.attendance_distance_meters(
  double precision, double precision, double precision, double precision
) from public;

create or replace function public.attendance_check_in(
  p_latitude double precision,
  p_longitude double precision,
  p_qr_payload text
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings public.attendance_settings%rowtype;
  v_id bigint;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.attendance_users where id = auth.uid()
  ) then
    raise exception 'attendance user profile is missing' using errcode = '42501';
  end if;

  select *
    into v_settings
    from public.attendance_settings
   where id = 1;

  if v_settings.id is null
     or v_settings.center_lat is null
     or v_settings.center_lng is null then
    raise exception 'attendance settings are incomplete' using errcode = '22023';
  end if;

  if p_latitude is null
     or p_longitude is null
     or p_latitude < -90 or p_latitude > 90
     or p_longitude < -180 or p_longitude > 180 then
    raise exception 'invalid coordinates' using errcode = '22023';
  end if;

  if p_qr_payload is null
     or btrim(p_qr_payload) <> v_settings.qr_code then
    raise exception 'invalid attendance qr code' using errcode = '22023';
  end if;

  if public.attendance_distance_meters(
       p_latitude, p_longitude, v_settings.center_lat, v_settings.center_lng
     ) > v_settings.allowed_radius_meters then
    raise exception 'outside attendance center range' using errcode = '22023';
  end if;

  insert into public.attendance_records (
    user_id,
    attendance_date,
    check_in,
    check_in_lat,
    check_in_lng
  )
  values (
    auth.uid(),
    current_date,
    now(),
    p_latitude,
    p_longitude
  )
  returning id into v_id;

  return v_id;
exception
  when unique_violation then
    raise exception 'open attendance already exists' using errcode = '23505';
end;
$$;

create or replace function public.attendance_check_out(
  p_latitude double precision,
  p_longitude double precision
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings public.attendance_settings%rowtype;
  v_id bigint;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select *
    into v_settings
    from public.attendance_settings
   where id = 1;

  if v_settings.id is null
     or v_settings.center_lat is null
     or v_settings.center_lng is null then
    raise exception 'attendance settings are incomplete' using errcode = '22023';
  end if;

  if p_latitude is null
     or p_longitude is null
     or p_latitude < -90 or p_latitude > 90
     or p_longitude < -180 or p_longitude > 180 then
    raise exception 'invalid coordinates' using errcode = '22023';
  end if;

  if public.attendance_distance_meters(
       p_latitude, p_longitude, v_settings.center_lat, v_settings.center_lng
     ) > v_settings.allowed_radius_meters then
    raise exception 'outside attendance center range' using errcode = '22023';
  end if;

  select id
    into v_id
    from public.attendance_records
   where user_id = auth.uid()
     and check_out is null
   order by check_in desc
   limit 1
   for update;

  if v_id is null then
    raise exception 'no open attendance' using errcode = 'P0001';
  end if;

  update public.attendance_records
     set check_out = now(),
         check_out_lat = p_latitude,
         check_out_lng = p_longitude
   where id = v_id;

  return v_id;
end;
$$;

revoke all on function public.attendance_check_in(
  double precision, double precision, text
) from public;
grant execute on function public.attendance_check_in(
  double precision, double precision, text
) to authenticated;

revoke all on function public.attendance_check_out(
  double precision, double precision
) from public;
grant execute on function public.attendance_check_out(
  double precision, double precision
) to authenticated;

create or replace function public.attendance_dashboard_stats()
returns table (
  doctors_count bigint,
  nurses_count bigint,
  present_count bigint,
  absent_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.attendance_is_admin() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return query
  with eligible_users as (
    select id, job_title, role
    from public.attendance_users
    where role <> 'admin'
      and job_title <> 'مدير النظام'
      and extract(
        isodow from (now() at time zone 'Africa/Khartoum')::date
      )::smallint = any(work_days)
  ),
  present_users as (
    select distinct r.user_id
    from public.attendance_records r
    join eligible_users e on e.id = r.user_id
    where r.check_out is null
  )
  select
    count(*) filter (
      where role = 'doctor' or job_title = 'طبيب'
    ),
    count(*) filter (
      where role = 'nurse' or job_title in ('ممرض', 'ممرضة')
    ),
    (select count(*) from present_users),
    (select count(*) from eligible_users)
      - (select count(*) from present_users);
end;
$$;

revoke all on function public.attendance_dashboard_stats() from public;
grant execute on function public.attendance_dashboard_stats() to authenticated;

create or replace function public.attendance_report(p_date date)
returns table (
  record_id bigint,
  user_id uuid,
  username text,
  full_name text,
  job_title text,
  attendance_date date,
  check_in timestamptz,
  check_out timestamptz,
  status text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.attendance_is_admin() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return query
  with eligible_users as (
    select
      u.id,
      coalesce(p.username, '')::text as username,
      coalesce(u.full_name, '')::text as full_name,
      coalesce(u.job_title, '')::text as job_title,
      coalesce(u.work_days, array[1, 2, 3, 4, 5, 6, 7]::smallint[]) as work_days
    from public.attendance_users u
    left join public.profiles p on p.id = u.id
    where u.role <> 'admin'
      and u.job_title <> 'مدير النظام'
  ),
  daily_records as (
    select distinct on (r.user_id)
      r.id,
      r.user_id,
      r.attendance_date,
      r.check_in,
      r.check_out
    from public.attendance_records r
    where r.attendance_date = p_date
    order by r.user_id, r.check_in desc
  )
  select
    r.id,
    e.id,
    e.username,
    e.full_name,
    e.job_title,
    p_date,
    r.check_in,
    r.check_out,
    case
      when r.user_id is not null and r.check_out is null then 'حاضر'
      when r.user_id is not null then 'انصرف'
      when extract(isodow from p_date)::smallint = any(e.work_days)
        then 'غائب'
      else 'غير مجدول'
    end::text
  from eligible_users e
  left join daily_records r on r.user_id = e.id
  order by
    case
      when r.user_id is not null and r.check_out is null then 1
      when r.user_id is not null then 2
      when extract(isodow from p_date)::smallint = any(e.work_days) then 3
      else 4
    end,
    e.full_name;
end;
$$;

revoke all on function public.attendance_report(date) from public;
grant execute on function public.attendance_report(date) to authenticated;