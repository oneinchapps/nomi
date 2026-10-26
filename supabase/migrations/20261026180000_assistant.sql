-- nomi als Assistent für alles rund ums Essen: ein gemeinsamer Verlauf pro Haushalt.
-- nomi führt Aktionen direkt aus (Wochenplan, Einkaufsliste, heutiges Essen); was dabei angelegt
-- oder geändert wurde, steht in result – damit lässt sich jede Aktion rückgängig machen.

create table public.assistant_messages (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households on delete cascade,
    -- null = nomi
    user_id uuid references auth.users on delete set null default auth.uid(),
    content text not null,
    -- Was nomi tun möchte (von der Function), z. B. {"plan": [...], "shopping": {...}, "today": {...}}
    actions jsonb,
    -- Was die App daraus gemacht hat (angelegte IDs, vorherige Stände) und ob es rückgängig gemacht wurde
    result jsonb,
    created_at timestamptz not null default now()
);

create index assistant_messages_household_idx on public.assistant_messages (household_id, created_at);

alter table public.assistant_messages enable row level security;

create policy "Mitglieder lesen den Verlauf" on public.assistant_messages
    for select to authenticated using (public.is_member(household_id));
create policy "Mitglieder schreiben als sie selbst" on public.assistant_messages
    for insert to authenticated with check (public.is_member(household_id) and user_id = auth.uid());
create policy "Mitglieder vermerken Ergebnisse" on public.assistant_messages
    for update to authenticated using (public.is_member(household_id)) with check (public.is_member(household_id));

grant select, insert on public.assistant_messages to authenticated;
-- Nur das Ergebnis darf nachträglich geändert werden, nicht der Text
grant update (result) on public.assistant_messages to authenticated;
grant select, insert on public.assistant_messages to service_role;

alter publication supabase_realtime add table public.assistant_messages;

-- Heute: Jede Person kann allein für den Haushalt festlegen, ohne Match.
-- Technisch stimmt die Funktion im Namen aller Mitglieder für die Karte – so greift die bestehende
-- Match-Logik (auch für Menüs mit mehreren Gängen) unverändert. decided_by zeigt, wer es war.
alter table public.decide_sessions add column decided_by uuid references auth.users on delete set null;

create function public.decide_alone(candidate uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    c public.session_candidates;
begin
    select * into c from public.session_candidates where id = candidate;
    if c.id is null or not public.is_member(c.household_id) then
        raise exception 'candidate not found';
    end if;
    if (select status from public.decide_sessions where id = c.session_id) <> 'open' then
        raise exception 'already decided';
    end if;

    update public.decide_sessions set decided_by = auth.uid() where id = c.session_id;

    insert into public.session_votes (candidate_id, session_id, household_id, user_id, liked)
    select c.id, c.session_id, c.household_id, m.user_id, true
    from public.household_members m
    where m.household_id = c.household_id
    on conflict (candidate_id, user_id) do update set liked = true;
end;
$$;

revoke execute on function public.decide_alone(uuid) from public, anon;
grant execute on function public.decide_alone(uuid) to authenticated;
