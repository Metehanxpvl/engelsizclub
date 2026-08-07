-- İlan fotoğrafları için Supabase Storage bucket (R2 yedeği / alternatif)
-- Supabase SQL Editor'da çalıştırın.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'ilan-photos',
  'ilan-photos',
  true,
  8388608,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Herkes okuyabilir (ilan kartlarında URL)
drop policy if exists "ilan_photos_public_read" on storage.objects;
create policy "ilan_photos_public_read"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'ilan-photos');

-- Sadece giriş yapmış kullanıcı kendi klasörüne yükler: {user_id}/...
drop policy if exists "ilan_photos_auth_insert" on storage.objects;
create policy "ilan_photos_auth_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'ilan-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "ilan_photos_auth_update" on storage.objects;
create policy "ilan_photos_auth_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'ilan-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'ilan-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "ilan_photos_auth_delete" on storage.objects;
create policy "ilan_photos_auth_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'ilan-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
