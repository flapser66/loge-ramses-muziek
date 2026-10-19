-- Archief voor oude muzieklijsten
alter table public.tabs add column if not exists archived boolean not null default false;
