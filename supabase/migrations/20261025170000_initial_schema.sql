-- nomnom: Grundschema
-- Alle Daten hängen an einem Haushalt. Zugriff nur für Mitglieder (RLS über is_member()).

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Haushalte
-- ---------------------------------------------------------------------------

create table public.households (
    id uuid primary key default gen_random_uuid(),
    name text not null default 'Unser Haushalt',
    invite_code text not null unique,
    created_at timestamptz not null default now()
);

create table public.household_members (
    household_id uuid not null references public.households on delete cascade,
    user_id uuid not null references auth.users on delete cascade,
    display_name text not null,
    joined_at timestamptz not null default now(),
    primary key (household_id, user_id)
);

create index household_members_user_idx on public.household_members (user_id);

-- security definer, damit Policies auf household_members nicht rekursiv werden
create function public.is_member(hid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1 from public.household_members
        where household_id = hid and user_id = auth.uid()
    );
$$;

-- Einladungscode ohne verwechselbare Zeichen (0/O, 1/I)
create function public.generate_invite_code()
returns text
language sql
volatile
set search_path = ''
as $$
    select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1), '')
    from generate_series(1, 6);
$$;

create function public.create_household(display_name text, household_name text default 'Unser Haushalt')
returns public.households
language plpgsql
security definer
set search_path = ''
as $$
declare
    h public.households;
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    if exists (select 1 from public.household_members where user_id = auth.uid()) then
        raise exception 'already in a household';
    end if;

    insert into public.households (name, invite_code)
    values (household_name, public.generate_invite_code())
    returning * into h;

    insert into public.household_members (household_id, user_id, display_name)
    values (h.id, auth.uid(), display_name);

    return h;
end;
$$;

create function public.join_household(code text, display_name text)
returns public.households
language plpgsql
security definer
set search_path = ''
as $$
declare
    h public.households;
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    if exists (select 1 from public.household_members where user_id = auth.uid()) then
        raise exception 'already in a household';
    end if;

    select * into h from public.households where invite_code = upper(trim(code));
    if h.id is null then
        raise exception 'invalid invite code';
    end if;

    insert into public.household_members (household_id, user_id, display_name)
    values (h.id, auth.uid(), display_name);

    return h;
end;
$$;

revoke execute on function public.create_household(text, text) from anon;
revoke execute on function public.join_household(text, text) from anon;

-- ---------------------------------------------------------------------------
-- Rezepte
-- ---------------------------------------------------------------------------

-- Supermarkt-Abteilungen, Reihenfolge entspricht dem Weg durch den Laden
create type public.aisle as enum (
    'obst_gemuese', 'backwaren', 'kuehlregal', 'fleisch_fisch', 'trockenwaren',
    'konserven', 'gewuerze_oele', 'tiefkuehl', 'getraenke', 'drogerie', 'sonstiges'
);

create type public.recipe_source as enum ('manual', 'web', 'instagram', 'tiktok', 'ai');

create table public.recipes (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households on delete cascade,
    title text not null,
    summary text,
    source public.recipe_source not null default 'manual',
    source_url text,
    image_url text,
    total_minutes int check (total_minutes > 0),
    servings int not null default 2 check (servings > 0),
    -- [{ "name": "Halloumi", "quantity": 250, "unit": "g", "note": "in Scheiben", "aisle": "kuehlregal" }]
    ingredients jsonb not null default '[]',
    -- [{ "text": "Halloumi goldbraun braten.", "timer_seconds": 240 }]
    steps jsonb not null default '[]',
    tags text[] not null default '{}',
    created_by uuid references auth.users on delete set null default auth.uid(),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index recipes_household_idx on public.recipes (household_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Einkauf & Wochenplan
-- ---------------------------------------------------------------------------

create table public.shopping_items (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households on delete cascade,
    name text not null,
    quantity numeric,
    unit text,
    aisle public.aisle not null default 'sonstiges',
    checked boolean not null default false,
    checked_by uuid references auth.users on delete set null,
    recipe_id uuid references public.recipes on delete set null,
    added_by uuid references auth.users on delete set null default auth.uid(),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index shopping_items_household_idx on public.shopping_items (household_id, checked, aisle);

-- Wiederkehrende Artikel (Milch, Eier …), die per Tap auf die Liste kommen
create table public.staple_items (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households on delete cascade,
    name text not null,
    quantity numeric,
    unit text,
    aisle public.aisle not null default 'sonstiges',
    position int not null default 0,
    created_at timestamptz not null default now()
);

create index staple_items_household_idx on public.staple_items (household_id, position);

create table public.meal_plan_entries (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households on delete cascade,
    day date not null,
    recipe_id uuid not null references public.recipes on delete cascade,
    servings int not null default 2 check (servings > 0),
    note text,
    created_at timestamptz not null default now()
);

create index meal_plan_household_day_idx on public.meal_plan_entries (household_id, day);

-- ---------------------------------------------------------------------------
-- Gemeinsam entscheiden: KI-Chat + Swipe
-- ---------------------------------------------------------------------------

create type public.session_status as enum ('open', 'matched', 'closed');

create table public.decide_sessions (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households on delete cascade,
    status public.session_status not null default 'open',
    matched_candidate_id uuid,
    created_by uuid references auth.users on delete set null default auth.uid(),
    created_at timestamptz not null default now()
);

create index decide_sessions_household_idx on public.decide_sessions (household_id, created_at desc);

create table public.chat_messages (
    id uuid primary key default gen_random_uuid(),
    session_id uuid not null references public.decide_sessions on delete cascade,
    household_id uuid not null references public.households on delete cascade,
    -- null = Antwort der KI
    user_id uuid references auth.users on delete set null,
    content text not null,
    created_at timestamptz not null default now()
);

create index chat_messages_session_idx on public.chat_messages (session_id, created_at);

-- Ein Vorschlag ist entweder ein gespeichertes Rezept oder eine neue KI-Idee (ai_recipe im Rezeptformat)
create table public.session_candidates (
    id uuid primary key default gen_random_uuid(),
    session_id uuid not null references public.decide_sessions on delete cascade,
    household_id uuid not null references public.households on delete cascade,
    recipe_id uuid references public.recipes on delete cascade,
    ai_recipe jsonb,
    reason text,
    position int not null default 0,
    created_at timestamptz not null default now(),
    check ((recipe_id is null) <> (ai_recipe is null))
);

create index session_candidates_session_idx on public.session_candidates (session_id, position);

alter table public.decide_sessions
    add constraint decide_sessions_matched_candidate_fkey
    foreign key (matched_candidate_id) references public.session_candidates on delete set null;

create table public.session_votes (
    candidate_id uuid not null references public.session_candidates on delete cascade,
    session_id uuid not null references public.decide_sessions on delete cascade,
    household_id uuid not null references public.households on delete cascade,
    user_id uuid not null references auth.users on delete cascade default auth.uid(),
    liked boolean not null,
    created_at timestamptz not null default now(),
    primary key (candidate_id, user_id)
);

-- Match, sobald alle Haushaltsmitglieder denselben Vorschlag mögen
create function public.check_match()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    likes int;
    members int;
begin
    if not new.liked then
        return new;
    end if;

    select count(*) into likes
    from public.session_votes
    where candidate_id = new.candidate_id and liked;

    select count(*) into members
    from public.household_members
    where household_id = new.household_id;

    if likes >= members then
        update public.decide_sessions
        set status = 'matched', matched_candidate_id = new.candidate_id
        where id = new.session_id and status = 'open';
    end if;

    return new;
end;
$$;

create trigger session_votes_check_match
after insert or update of liked on public.session_votes
for each row execute function public.check_match();

-- ---------------------------------------------------------------------------
-- updated_at
-- ---------------------------------------------------------------------------

create function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger recipes_touch before update on public.recipes
for each row execute function public.touch_updated_at();

create trigger shopping_items_touch before update on public.shopping_items
for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Rechte: nur eingeloggte Nutzer, Zeilenfilter übernimmt RLS
-- ---------------------------------------------------------------------------

grant select, update on public.households to authenticated;
grant select, update, delete on public.household_members to authenticated;
grant select, insert, update, delete on
    public.recipes,
    public.shopping_items,
    public.staple_items,
    public.meal_plan_entries,
    public.decide_sessions,
    public.chat_messages,
    public.session_candidates
to authenticated;
grant select, insert, update on public.session_votes to authenticated;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.recipes enable row level security;
alter table public.shopping_items enable row level security;
alter table public.staple_items enable row level security;
alter table public.meal_plan_entries enable row level security;
alter table public.decide_sessions enable row level security;
alter table public.chat_messages enable row level security;
alter table public.session_candidates enable row level security;
alter table public.session_votes enable row level security;

-- Haushalte entstehen nur über create_household/join_household
create policy "Mitglieder sehen ihren Haushalt" on public.households
    for select to authenticated using (public.is_member(id));
create policy "Mitglieder benennen ihren Haushalt um" on public.households
    for update to authenticated using (public.is_member(id)) with check (public.is_member(id));

create policy "Mitglieder sehen einander" on public.household_members
    for select to authenticated using (public.is_member(household_id));
create policy "Eigenen Anzeigenamen ändern" on public.household_members
    for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Haushalt verlassen" on public.household_members
    for delete to authenticated using (user_id = auth.uid());

-- Für alle Inhaltstabellen gilt dasselbe: voller Zugriff innerhalb des eigenen Haushalts
do $$
declare
    t text;
begin
    foreach t in array array[
        'recipes', 'shopping_items', 'staple_items', 'meal_plan_entries',
        'decide_sessions', 'chat_messages', 'session_candidates'
    ] loop
        execute format(
            'create policy "Haushalt hat Zugriff" on public.%I for all to authenticated
             using (public.is_member(household_id)) with check (public.is_member(household_id))',
            t
        );
    end loop;
end;
$$;

-- Stimmen: alle im Haushalt sehen sie, aber jede Person setzt nur ihre eigene
create policy "Haushalt sieht Stimmen" on public.session_votes
    for select to authenticated using (public.is_member(household_id));
create policy "Eigene Stimme abgeben" on public.session_votes
    for insert to authenticated with check (user_id = auth.uid() and public.is_member(household_id));
create policy "Eigene Stimme ändern" on public.session_votes
    for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------

alter publication supabase_realtime add table
    public.shopping_items,
    public.staple_items,
    public.meal_plan_entries,
    public.recipes,
    public.decide_sessions,
    public.chat_messages,
    public.session_candidates,
    public.session_votes;
