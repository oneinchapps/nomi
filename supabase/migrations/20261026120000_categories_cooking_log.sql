-- Feste Kategorien für Filter und Startseite (freie Tags bleiben daneben bestehen)
alter table public.recipes
    add column dish_type text check (dish_type in (
        'vorspeise', 'suppe', 'salat', 'hauptgericht', 'beilage', 'dessert', 'backen', 'snack', 'getraenk'
    )),
    add column diet text check (diet in ('fleisch', 'fisch', 'vegetarisch', 'vegan'));

-- Kochhistorie: ein Eintrag pro Rezept und Tag, sobald im Kochmodus „Los geht's“ getippt wird
create table public.cooking_log (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households on delete cascade,
    recipe_id uuid not null references public.recipes on delete cascade,
    cooked_by uuid references auth.users on delete set null default auth.uid(),
    cooked_on date not null,
    servings int check (servings > 0),
    created_at timestamptz not null default now(),
    unique (household_id, recipe_id, cooked_on)
);

create index cooking_log_household_idx on public.cooking_log (household_id, cooked_on desc);

alter table public.cooking_log enable row level security;
grant select, insert, delete on public.cooking_log to authenticated;

create policy "Haushalt sieht Kochhistorie" on public.cooking_log
    for select to authenticated using (public.is_member(household_id));
create policy "Haushalt trägt ein" on public.cooking_log
    for insert to authenticated with check (public.is_member(household_id) and cooked_by = auth.uid());
create policy "Haushalt löscht Einträge" on public.cooking_log
    for delete to authenticated using (public.is_member(household_id));

alter publication supabase_realtime add table public.cooking_log;
