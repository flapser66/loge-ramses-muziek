-- Activiteitenlog: wie wanneer online was en wat er gedaan is (alleen leesbaar voor beheer)
create table if not exists public.activity (
  id bigint generated always as identity primary key,
  email text not null default lower(coalesce(auth.jwt()->>'email','')),
  action text not null check (action in ('bezoek','tabblad','afspelen','download')),
  detail text check (char_length(detail) <= 300),
  created_at timestamptz not null default now()
);
create index if not exists activity_time on public.activity (created_at desc);
alter table public.activity enable row level security;
drop policy if exists "leden loggen" on public.activity;
drop policy if exists "beheer leest activiteit" on public.activity;
drop policy if exists "beheer wist activiteit" on public.activity;
create policy "leden loggen" on public.activity for insert to authenticated
  with check (email = lower(coalesce(auth.jwt()->>'email','')) and public.my_graad() is not null);
create policy "beheer leest activiteit" on public.activity for select to authenticated using (public.is_admin());
create policy "beheer wist activiteit" on public.activity for delete to authenticated using (public.is_admin());
