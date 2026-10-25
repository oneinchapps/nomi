-- Chat-Nachrichten gehören der schreibenden Person; niemand schreibt im Namen anderer.
-- Antworten von nomnom (user_id null) legt nur die decide-Function mit dem Service-Key an.
alter table public.chat_messages alter column user_id set default auth.uid();

create policy "Nur als man selbst schreiben" on public.chat_messages
    as restrictive
    for insert to authenticated
    with check (user_id = auth.uid());

-- Neue Tabellen haben keine Standardrechte mehr – die Function braucht genau dieses eine.
grant insert on public.chat_messages to service_role;
