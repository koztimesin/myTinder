-- Редактор и onboarding поддерживают максимум четыре фотографии.
-- Перед применением проверено, что в текущем проекте нет профилей с большим числом фото.
alter table public.profiles
  drop constraint if exists profiles_photo_paths_limit;

alter table public.profiles
  add constraint profiles_photo_paths_limit
  check (cardinality(photo_paths) <= 4);
