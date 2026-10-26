-- Profilfotos: ein Foto pro Mitglied, oben rechts und in der Haushaltsübersicht.
-- Pfad: <household_id>/<user_id>/<datei>.jpg. Lesen öffentlich (nicht erratbare Pfade),
-- schreiben nur in den eigenen Ordner des eigenen Haushalts.

alter table public.household_members add column avatar_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2097152, array['image/jpeg'])
on conflict (id) do nothing;

create policy "Eigenes Profilfoto hochladen" on storage.objects
    for insert to authenticated
    with check (
        bucket_id = 'avatars'
        and public.is_member(((storage.foldername(name))[1])::uuid)
        and (storage.foldername(name))[2] = auth.uid()::text
    );

create policy "Eigenes Profilfoto ersetzen" on storage.objects
    for update to authenticated
    using (
        bucket_id = 'avatars'
        and public.is_member(((storage.foldername(name))[1])::uuid)
        and (storage.foldername(name))[2] = auth.uid()::text
    );

create policy "Eigenes Profilfoto löschen" on storage.objects
    for delete to authenticated
    using (
        bucket_id = 'avatars'
        and public.is_member(((storage.foldername(name))[1])::uuid)
        and (storage.foldername(name))[2] = auth.uid()::text
    );
