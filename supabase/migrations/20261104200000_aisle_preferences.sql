-- Abteilungen, die ein Haushalt per Ziehen selbst festgelegt hat: Wer „Hafermilch“ ins Kühlregal zieht,
-- findet sie beim nächsten Mal gleich dort. name_key ist der Name klein und mit einfachen Leerzeichen
-- (ShoppingMerge.key in der App).

create table public.aisle_preferences (
    household_id uuid not null references public.households (id) on delete cascade,
    name_key text not null,
    aisle public.aisle not null,
    updated_at timestamptz not null default now(),
    primary key (household_id, name_key)
);

alter table public.aisle_preferences enable row level security;

create policy "Haushalt hat Zugriff" on public.aisle_preferences for all to authenticated
    using (public.is_member(household_id)) with check (public.is_member(household_id));

grant select, insert, update, delete on public.aisle_preferences to authenticated;
