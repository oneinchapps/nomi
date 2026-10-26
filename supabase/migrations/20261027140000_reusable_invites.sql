-- Demo-Zugang für die App-Prüfung: Ein wiederverwendbarer Anmeldecode führt immer in dasselbe
-- Demo-Konto (member_id). Normale Einladungen bleiben Einmal-Codes.
alter table public.household_invites
    add column reusable boolean not null default false,
    add constraint household_invites_reusable_member check (not reusable or member_id is not null);
