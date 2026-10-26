-- Konto löschen (Edge Function `account`): Die Function arbeitet mit dem Service-Key und braucht
-- dafür gezielt diese Rechte – neue Tabellen haben für service_role keine Standardrechte.
grant delete on public.assistant_messages to service_role;
grant select, delete on public.chat_messages to service_role;
grant select, delete on public.household_members to service_role;
grant select, delete on public.households to service_role;
