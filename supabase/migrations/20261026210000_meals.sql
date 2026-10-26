-- Mahlzeiten: Frühstück, Mittag- und Abendessen, jede mit beliebig vielen Gängen (position).
-- Bestehende Einträge waren Abendessen.
alter table public.meal_plan_entries
    add column meal text not null default 'abend' check (meal in ('fruehstueck', 'mittag', 'abend')),
    add column position int not null default 0,
    -- Aus welcher Vorschlagskarte der Eintrag stammt – verhindert doppeltes Eintragen
    add column candidate_id uuid references public.session_candidates on delete set null;

create unique index meal_plan_candidate_idx on public.meal_plan_entries (candidate_id) where candidate_id is not null;

-- Für welche Mahlzeit heute eine Runde läuft; null = alte Runden ohne Bezug
alter table public.decide_sessions
    add column meal text check (meal in ('fruehstueck', 'mittag', 'abend'));

-- Entschiedene Runde → Gerichte für heute in ihre Mahlzeit eintragen.
-- Ideen ohne Rezept werden übersprungen und nach dem Ausarbeiten nachgetragen (decide-Function ruft das erneut auf).
create function public.plan_decision(session uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    s public.decide_sessions;
    members int;
    today_date date := (now() at time zone 'Europe/Berlin')::date;
    next_position int;
begin
    select * into s from public.decide_sessions where id = session;
    if s.id is null or s.meal is null or s.status <> 'matched' then
        return;
    end if;
    if auth.uid() is not null and not public.is_member(s.household_id) then
        raise exception 'session not found';
    end if;

    select count(*) into members from public.household_members where household_id = s.household_id;
    select coalesce(max(position) + 1, 0) into next_position
    from public.meal_plan_entries
    where household_id = s.household_id and day = today_date and meal = s.meal;

    insert into public.meal_plan_entries (household_id, day, recipe_id, servings, note, meal, position, candidate_id)
    select s.household_id, today_date, c.recipe_id, 2, c.course, s.meal,
           next_position + (row_number() over (order by array_position(s.courses, c.course), c.position))::int - 1,
           c.id
    from public.session_candidates c
    where c.session_id = s.id
      and c.recipe_id is not null
      and (
          (coalesce(cardinality(s.courses), 0) = 0 and c.id = s.matched_candidate_id)
          or c.id in (
              -- Menü: pro Gang die erste Karte, die alle mögen
              select distinct on (d.course) d.id
              from public.session_candidates d
              where d.session_id = s.id
                and d.course is not null
                and (select count(*) from public.session_votes v where v.candidate_id = d.id and v.liked) >= members
              order by d.course, d.position
          )
      )
    on conflict (candidate_id) where candidate_id is not null do nothing;
end;
$$;

revoke execute on function public.plan_decision(uuid) from public, anon;
grant execute on function public.plan_decision(uuid) to authenticated;

-- check_match wie bisher, trägt aber nach dem Match gleich ein
create or replace function public.check_match()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    members int;
    session_courses text[];
    course_name text;
    decided boolean;
begin
    if not new.liked then
        return new;
    end if;

    select count(*) into members
    from public.household_members
    where household_id = new.household_id;

    select courses into session_courses
    from public.decide_sessions
    where id = new.session_id;

    if coalesce(cardinality(session_courses), 0) = 0 then
        if (select count(*) from public.session_votes where candidate_id = new.candidate_id and liked) >= members then
            update public.decide_sessions
            set status = 'matched', matched_candidate_id = new.candidate_id
            where id = new.session_id and status = 'open';
            perform public.plan_decision(new.session_id);
        end if;
        return new;
    end if;

    foreach course_name in array session_courses loop
        select exists (
            select 1
            from public.session_candidates c
            where c.session_id = new.session_id
              and c.course = course_name
              and (select count(*) from public.session_votes v where v.candidate_id = c.id and v.liked) >= members
        ) into decided;
        if not decided then
            return new;
        end if;
    end loop;

    update public.decide_sessions
    set status = 'matched', matched_candidate_id = new.candidate_id
    where id = new.session_id and status = 'open';
    perform public.plan_decision(new.session_id);
    return new;
end;
$$;
