-- Supermärkte mit eigener Reihenfolge der Kategorien, umbenannte und eigene Kategorien.
--
-- shopping_categories: Zeilen mit aisle benennen eine feste Abteilung um (höchstens eine pro Haushalt),
--   Zeilen ohne aisle sind eigene Kategorien wie „Bio-Ecke“.
-- shopping_stores.category_order: Schlüssel der Kategorien in Laufreihenfolge, „aisle:<abteilung>“
--   oder die id einer eigenen Kategorie. Fehlende kommen in der App ans Ende.
-- Einträge und gemerkte Abteilungen zeigen per category_id auf eine eigene Kategorie; die feste
--   Abteilung (aisle) bleibt daneben stehen und gilt wieder, wenn die eigene Kategorie gelöscht wird.

create table public.shopping_categories (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households (id) on delete cascade,
    name text not null check (char_length(name) between 1 and 40),
    aisle public.aisle,
    created_at timestamptz not null default now(),
    -- NULL zählt nicht doppelt: beliebig viele eigene, aber jede feste Abteilung nur einmal
    unique (household_id, aisle)
);

create table public.shopping_stores (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households (id) on delete cascade,
    name text not null check (char_length(name) between 1 and 40),
    category_order text[] not null default '{}',
    position integer not null default 0,
    created_at timestamptz not null default now()
);

create index shopping_stores_household_idx on public.shopping_stores (household_id, position);

alter table public.shopping_items
    add column category_id uuid references public.shopping_categories (id) on delete set null;
create index shopping_items_category_idx on public.shopping_items (category_id);

alter table public.aisle_preferences
    add column category_id uuid references public.shopping_categories (id) on delete set null;

alter table public.shopping_categories enable row level security;
alter table public.shopping_stores enable row level security;

create policy "Haushalt hat Zugriff" on public.shopping_categories for all to authenticated
    using (public.is_member(household_id)) with check (public.is_member(household_id));
create policy "Haushalt hat Zugriff" on public.shopping_stores for all to authenticated
    using (public.is_member(household_id)) with check (public.is_member(household_id));

grant select, insert, update, delete on public.shopping_categories, public.shopping_stores to authenticated;

alter publication supabase_realtime add table public.shopping_categories, public.shopping_stores;
