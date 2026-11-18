-- PulsoBiz Monitor - plataforma em nuvem (Supabase). Rodar uma vez.
-- Tudo fica bloqueado para o publico (RLS ligado, sem policies): so a Edge Function
-- "data" (service role) le e escreve.

create table if not exists public.readings (
  id          bigint generated always as identity primary key,
  variable    text not null,
  num         double precision,
  value       text not null,
  unit        text,
  created_at  timestamptz not null default now()
);
create index if not exists readings_var_time_idx on public.readings (variable, created_at desc);
alter table public.readings enable row level security;

create table if not exists public.config (
  key   text primary key,
  value text not null
);
alter table public.config enable row level security;

create table if not exists public.alert_log (
  id           bigint generated always as identity primary key,
  kind         text not null,
  sent_at      timestamptz not null default now(),
  email_status text,
  sms_status   text
);
create index if not exists alert_log_kind_idx on public.alert_log (kind, sent_at desc);
alter table public.alert_log enable row level security;

-- Token do dispositivo (o mesmo "Device-Token" do contrato de dados).
insert into public.config (key, value)
values ('device_token', gen_random_uuid()::text)
on conflict (key) do nothing;

-- Consultas do dashboard (so a service role executa).
create or replace function public.series_avg(p_variable text, p_since timestamptz, p_bin interval)
returns table (t timestamptz, v double precision)
language sql stable set search_path = public as $$
  select date_bin(least(p_bin, interval '1 minute'), created_at, timestamptz 'epoch') as t, avg(num) as v
  from public.readings
  where variable = p_variable and created_at >= p_since and num is not null
  group by 1 order by 1
$$;

create or replace function public.hourly_counts(p_since timestamptz)
returns table (h timestamptz, n bigint)
language sql stable set search_path = public as $$
  select date_trunc('hour', created_at) as h, count(*) as n
  from public.readings
  where variable = 'movimento' and num = 1 and created_at >= p_since
  group by 1 order by 1
$$;

create or replace function public.latest_values()
returns table (variable text, num double precision, value text, unit text, created_at timestamptz)
language sql stable set search_path = public as $$
  select distinct on (variable) variable, num, value, unit, created_at
  from public.readings order by variable, created_at desc
$$;

revoke all on function public.series_avg(text, timestamptz, interval) from public, anon, authenticated;
revoke all on function public.hourly_counts(timestamptz) from public, anon, authenticated;
revoke all on function public.latest_values() from public, anon, authenticated;
grant execute on function public.series_avg(text, timestamptz, interval) to service_role;
grant execute on function public.hourly_counts(timestamptz) to service_role;
grant execute on function public.latest_values() to service_role;
