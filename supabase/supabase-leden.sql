-- Ritueelmuziek Loge Ramses — toegang per graad (uitvoeren na supabase-setup.sql)

-- Graad per tabblad (1 = Leerling, 2 = Gezel, 3 = Meester)
alter table public.tabs add column if not exists graad int not null default 1 check (graad between 1 and 3);

-- Ledenlijst: alleen deze e-mailadressen komen binnen
create table if not exists public.members (
  email text primary key check (email = lower(email)),
  graad int not null check (graad between 1 and 3),
  created_at timestamptz not null default now()
);

-- Beheerders
create table if not exists public.admins (
  email text primary key check (email = lower(email))
);
insert into public.admins (email) values ('jasperuitlobith@hotmail.com') on conflict do nothing;

alter table public.members enable row level security;
alter table public.admins  enable row level security;

-- Hulpfuncties
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from admins where email = lower(coalesce(auth.jwt()->>'email','')));
$$;

create or replace function public.my_graad() returns int
language sql stable security definer set search_path = public as $$
  select case when public.is_admin() then 3
         else (select graad from members where email = lower(coalesce(auth.jwt()->>'email',''))) end;
$$;

-- Wie ben ik (voor de app)
create or replace function public.whoami() returns json
language sql stable security definer set search_path = public as $$
  select json_build_object('admin', public.is_admin(), 'graad', public.my_graad());
$$;

-- Controle vóór het versturen van de inloglink: e-mail bekend en graad klopt?
create or replace function public.check_member(p_email text, p_graad int) returns text
language sql stable security definer set search_path = public as $$
  select case
    when exists (select 1 from admins where email = lower(trim(p_email))) then 'ok'
    when not exists (select 1 from members where email = lower(trim(p_email))) then 'onbekend'
    when exists (select 1 from members where email = lower(trim(p_email)) and graad = p_graad) then 'ok'
    else 'graad' end;
$$;

revoke all on function public.check_member(text,int) from public;
grant execute on function public.check_member(text,int) to anon, authenticated;
grant execute on function public.whoami() to authenticated;

-- Oude regels weg (iedereen mocht lezen)
drop policy if exists "iedereen leest tabs"  on public.tabs;
drop policy if exists "beheer wijzigt tabs"  on public.tabs;
drop policy if exists "iedereen leest items" on public.items;
drop policy if exists "beheer wijzigt items" on public.items;
drop policy if exists "beheer uploadt"    on storage.objects;
drop policy if exists "beheer wijzigt"    on storage.objects;
drop policy if exists "beheer verwijdert" on storage.objects;

-- Nieuwe regels: leden zien hun eigen graad en lager, alleen beheerders wijzigen
create policy "leden lezen tabs"  on public.tabs  for select to authenticated
  using (public.is_admin() or graad <= coalesce(public.my_graad(), 0));
create policy "beheer wijzigt tabs" on public.tabs for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "leden lezen items" on public.items for select to authenticated
  using (public.is_admin() or exists (select 1 from public.tabs t where t.id = items.tab_id and t.graad <= coalesce(public.my_graad(), 0)));
create policy "beheer wijzigt items" on public.items for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "beheer leest leden"   on public.members for select to authenticated using (public.is_admin());
create policy "beheer wijzigt leden" on public.members for all    to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "beheer leest beheer"  on public.admins  for select to authenticated using (public.is_admin());

create policy "beheer uploadt"    on storage.objects for insert to authenticated with check (bucket_id = 'ritueel' and public.is_admin());
create policy "beheer wijzigt"    on storage.objects for update to authenticated using (bucket_id = 'ritueel' and public.is_admin());
create policy "beheer verwijdert" on storage.objects for delete to authenticated using (bucket_id = 'ritueel' and public.is_admin());
