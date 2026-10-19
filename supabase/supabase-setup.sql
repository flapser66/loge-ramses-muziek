-- Ritueelmuziek Loge Ramses — eenmalig uitvoeren in Supabase (SQL Editor → New query → Run)

-- Tabellen
create table if not exists public.tabs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  position int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  tab_id uuid not null references public.tabs(id) on delete cascade,
  title text not null,
  ritual_date date,
  note text,
  audio_path text,
  audio_name text,
  doc_path text,
  doc_name text,
  created_at timestamptz not null default now()
);

-- Beveiliging: iedereen mag lezen, alleen ingelogde beheerders mogen wijzigen
alter table public.tabs  enable row level security;
alter table public.items enable row level security;

create policy "iedereen leest tabs"   on public.tabs  for select to anon, authenticated using (true);
create policy "beheer wijzigt tabs"   on public.tabs  for all    to authenticated using (true) with check (true);
create policy "iedereen leest items"  on public.items for select to anon, authenticated using (true);
create policy "beheer wijzigt items"  on public.items for all    to authenticated using (true) with check (true);

-- Opslag voor muziek en documenten (openbaar leesbaar, max 50 MB per bestand)
insert into storage.buckets (id, name, public, file_size_limit)
values ('ritueel', 'ritueel', true, 52428800)
on conflict (id) do nothing;

create policy "beheer uploadt"   on storage.objects for insert to authenticated with check (bucket_id = 'ritueel');
create policy "beheer wijzigt"   on storage.objects for update to authenticated using (bucket_id = 'ritueel');
create policy "beheer verwijdert" on storage.objects for delete to authenticated using (bucket_id = 'ritueel');

-- Los document (bouwstuk) per tabblad
alter table public.tabs add column if not exists doc_path text;
alter table public.tabs add column if not exists doc_name text;
