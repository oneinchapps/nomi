-- Mehrgängige Menüs: Die Runde kennt ihre Gänge (z. B. Vorspeise, Hauptgang, Dessert),
-- jede Karte gehört zu einem Gang. Ohne Gänge (null) bleibt alles wie bisher: ein Gericht, ein Match.
alter table public.decide_sessions add column courses text[];
alter table public.session_candidates add column course text;

-- Ein Gang ist entschieden, sobald alle Mitglieder eine seiner Karten mögen.
-- Das Menü ist entschieden, wenn jeder Gang entschieden ist.
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
        -- Einzelnes Gericht: diese Karte von allen gemocht?
        if (select count(*) from public.session_votes where candidate_id = new.candidate_id and liked) >= members then
            update public.decide_sessions
            set status = 'matched', matched_candidate_id = new.candidate_id
            where id = new.session_id and status = 'open';
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
    return new;
end;
$$;
