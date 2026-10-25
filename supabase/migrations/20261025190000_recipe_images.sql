-- Rezeptfotos: Pfad = <household_id>/<datei>.jpg
-- Lesen öffentlich (nicht erratbare URLs, keine sensiblen Inhalte), Schreiben nur für Haushaltsmitglieder.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('recipe-images', 'recipe-images', true, 5242880, array['image/jpeg', 'image/png', 'image/heic', 'image/webp'])
on conflict (id) do nothing;

create policy "Haushalt lädt Rezeptfotos hoch" on storage.objects
    for insert to authenticated
    with check (
        bucket_id = 'recipe-images'
        and public.is_member(((storage.foldername(name))[1])::uuid)
    );

create policy "Haushalt ersetzt Rezeptfotos" on storage.objects
    for update to authenticated
    using (
        bucket_id = 'recipe-images'
        and public.is_member(((storage.foldername(name))[1])::uuid)
    );

create policy "Haushalt löscht Rezeptfotos" on storage.objects
    for delete to authenticated
    using (
        bucket_id = 'recipe-images'
        and public.is_member(((storage.foldername(name))[1])::uuid)
    );
