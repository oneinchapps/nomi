-- Bilder für die Anmelde-Mail (Chefi, Wortmarke): öffentlich lesbar, weil Mailprogramme sie ohne Anmeldung laden.
-- Keine Schreibregeln: Hochladen nur über das Dashboard bzw. service_role.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('mail', 'mail', true, 1048576, array['image/png'])
on conflict (id) do nothing;
