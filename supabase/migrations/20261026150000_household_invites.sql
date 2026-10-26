-- Einladungen per WhatsApp/Nachricht: Einmal-Codes, mit denen sich die zweite Person ohne E-Mail anmeldet.
-- Eingelöst werden sie in der Edge Function `invite` (legt das Konto an und meldet an).
-- Mit member_id meldet ein Code ein bestehendes Mitglied auf einem neuen Gerät an.

create table public.household_invites (
    code text primary key,
    household_id uuid not null references public.households on delete cascade,
    member_id uuid references auth.users on delete cascade,
    created_by uuid references auth.users on delete set null default auth.uid(),
    expires_at timestamptz not null default now() + interval '7 days',
    created_at timestamptz not null default now()
);

create index household_invites_household_idx on public.household_invites (household_id);

alter table public.household_invites enable row level security;
-- Kein direkter Zugriff für Nutzer:innen: Anlegen über create_invite(), Einlösen über die Function
grant select, insert, delete on public.household_invites to service_role;
grant insert on public.household_members to service_role;

-- Konten aus Einladungen haben keine echte Mailadresse
create function public.is_invited_account(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1 from auth.users
        where id = uid and email like '%@einladung.nomi.invalid'
    );
$$;

revoke execute on function public.is_invited_account(uuid) from public, anon;
grant execute on function public.is_invited_account(uuid) to authenticated, service_role;

-- Gibt einen gültigen Code für den eigenen Haushalt zurück (noch mindestens einen Tag gültig) oder legt einen an.
-- member: anderes Mitglied, das sich auf einem neuen Gerät anmelden soll – nur für Konten ohne E-Mail,
-- sonst könnte man sich als jemand mit eigener Mailadresse anmelden.
create function public.create_invite(member uuid default null)
returns public.household_invites
language plpgsql
security definer
set search_path = ''
as $$
declare
    hid uuid;
    invite public.household_invites;
begin
    select household_id into hid from public.household_members where user_id = auth.uid();
    if hid is null then
        raise exception 'not in a household';
    end if;
    if member is not null then
        if member = auth.uid()
            or not exists (select 1 from public.household_members where household_id = hid and user_id = member)
            or not public.is_invited_account(member) then
            raise exception 'invalid member';
        end if;
    end if;

    delete from public.household_invites where expires_at < now();

    select * into invite from public.household_invites
    where household_id = hid
      and member_id is not distinct from member
      and expires_at > now() + interval '1 day'
    order by created_at desc
    limit 1;

    if invite.code is null then
        insert into public.household_invites (code, household_id, member_id)
        values (
            (select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1), '')
             from generate_series(1, 8)),
            hid,
            member
        )
        returning * into invite;
    end if;

    return invite;
end;
$$;

revoke execute on function public.create_invite(uuid) from public, anon;
grant execute on function public.create_invite(uuid) to authenticated;

-- Wer sich per E-Mail angemeldet hat, kann einen Einmal-Code auch im Haushalts-Schritt eingeben.
-- Der dauerhafte Haushalts-Code funktioniert weiterhin.
create or replace function public.join_household(code text, display_name text)
returns public.households
language plpgsql
security definer
set search_path = ''
as $$
declare
    h public.households;
    normalized text := upper(regexp_replace(code, '[^A-Za-z0-9]', '', 'g'));
    invited uuid;
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    if exists (select 1 from public.household_members where user_id = auth.uid()) then
        raise exception 'already in a household';
    end if;

    delete from public.household_invites i
    where i.code = normalized and i.member_id is null and i.expires_at > now()
    returning i.household_id into invited;

    if invited is not null then
        select * into h from public.households where id = invited;
    else
        select * into h from public.households where invite_code = normalized;
    end if;
    if h.id is null then
        raise exception 'invalid invite code';
    end if;

    insert into public.household_members (household_id, user_id, display_name)
    values (h.id, auth.uid(), display_name);

    return h;
end;
$$;
