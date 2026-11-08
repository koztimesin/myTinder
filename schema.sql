-- myTinder: полная схема Supabase (Postgres) для MVP
-- Запускать в Supabase Dashboard -> SQL Editor на новом проекте.
-- Содержит: таблицы, индексы, RLS-политики, функции, триггер матчей, realtime, хранилище фото.

-- =========================================================
-- 1. ТАБЛИЦЫ
-- =========================================================

create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  name          text not null check (char_length(name) between 1 and 50),
  birth_date    date not null check (birth_date <= current_date - interval '18 years'),
  bio           text check (char_length(bio) <= 500),
  gender        text,
  interested_in text[] default '{}',
  photo_paths   text[] default '{}',          -- пути к файлам в Storage
  min_age       integer not null default 18,
  max_age       integer not null default 99,
  created_at    timestamptz not null default now()
);

-- Допустимые значения пола, лимит фото и настройки возрастной выдачи.
-- Значения пола должны совпадать с rawValue enum Gender в приложении.
alter table public.profiles
  add constraint profiles_gender_check
    check (gender in ('male','female')),
  add constraint profiles_interested_in_check
    check (interested_in <@ array['male','female']::text[]),
  add constraint profiles_photo_paths_limit
    check (cardinality(photo_paths) <= 6),
  add constraint profiles_age_range_check
    check (18 <= min_age and min_age <= max_age and max_age <= 99);

create table public.swipes (
  swiper     uuid not null references public.profiles(id) on delete cascade,
  target     uuid not null references public.profiles(id) on delete cascade,
  liked      boolean not null,
  created_at timestamptz not null default now(),
  primary key (swiper, target),
  check (swiper <> target)
);
create index swipes_target_swiper_idx on public.swipes (target, swiper);

create table public.matches (
  id         uuid primary key default gen_random_uuid(),
  user_a     uuid not null references public.profiles(id) on delete cascade,
  user_b     uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (user_a < user_b),                   -- пара хранится в одном порядке
  unique (user_a, user_b)
);
create index matches_user_b_idx on public.matches (user_b);

create table public.messages (
  id         uuid primary key default gen_random_uuid(),
  match_id   uuid not null references public.matches(id) on delete cascade,
  sender     uuid not null references public.profiles(id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index messages_match_created_idx on public.messages (match_id, created_at);

-- Статус «прочитано»: когда пользователь последний раз открывал диалог.
-- Непрочитанные = сообщения собеседника новее last_read_at (нет строки = все).
-- Писать в таблицу можно только через mark_match_read().
create table public.match_reads (
  match_id     uuid not null references public.matches(id) on delete cascade,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (match_id, user_id)
);

-- Блокировки: писать можно только через block_user() (разблокировки в MVP нет).
create table public.blocks (
  blocker    uuid not null references public.profiles(id) on delete cascade,
  blocked    uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);

-- Жалобы: категория из фиксированного списка (значения совпадают с rawValue
-- ReportCategory в приложении), комментарий необязателен.
create table public.reports (
  id         uuid primary key default gen_random_uuid(),
  reporter   uuid not null references public.profiles(id) on delete cascade,
  reported   uuid not null references public.profiles(id) on delete cascade,
  category   text not null
    check (category in ('fake','inappropriate_photos','harassment','spam','underage','other')),
  reason     text check (char_length(reason) <= 1000),
  created_at timestamptz not null default now(),
  check (reporter <> reported)
);

-- =========================================================
-- 2. ФУНКЦИИ
-- =========================================================

-- Внутренние функции живут вне схемы, доступной через Data API.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

-- Новые функции по умолчанию недоступны через Data API: доступ выдаётся явно ниже.
alter default privileges revoke execute on functions from public;
alter default privileges in schema public revoke execute on functions from anon, authenticated;
alter default privileges in schema private revoke execute on functions from anon, authenticated;

-- Есть ли блокировка между двумя пользователями (в любую сторону).
-- security definer: видит блокировки независимо от RLS. Функция разрешает проверять
-- только отношения, в которых участвует текущий пользователь, и не выставлена как RPC.
create function private.is_blocked_between(a uuid, b uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select
    auth.uid() is not null
    and (auth.uid() = a or auth.uid() = b)
    and exists (
      select 1 from public.blocks
      where (blocker = a and blocked = b) or (blocker = b and blocked = a)
    );
$$;

-- Лента: те, кого пользователь ещё не свайпал, без заблокированных.
-- Фильтры взаимны: пол и полный возраст каждого участника входят в настройки другого.
-- У кандидата должно быть хотя бы одно фото. Для MVP порядок случайный.
-- Если у вызывающего нет профиля, лента пустая.
create function public.get_feed(p_limit int default 20)
returns setof public.profiles
language sql stable security invoker set search_path = ''
as $$
  with me as (
    select
      gender,
      interested_in,
      extract(year from age(current_date, birth_date))::integer as age,
      min_age,
      max_age
    from public.profiles
    where id = auth.uid()
  )
  select p.*
  from public.profiles p, me
  where p.id <> auth.uid()
    and p.gender = any(me.interested_in)
    and me.gender = any(p.interested_in)
    and extract(year from age(current_date, p.birth_date))::integer
      between me.min_age and me.max_age
    and me.age between p.min_age and p.max_age
    and cardinality(p.photo_paths) >= 1
    and not exists (
      select 1 from public.swipes s
      where s.swiper = auth.uid() and s.target = p.id
    )
    and not private.is_blocked_between(auth.uid(), p.id)
  order by random()
  limit least(p_limit, 50);
$$;

-- Список матчей: мои матчи с краткими данными собеседника,
-- последним сообщением и числом непрочитанных. security invoker: работают
-- RLS-политики вызывающего, поэтому матчи с заблокированными пропадают сами.
-- Главное фото собеседника — первый элемент photo_paths (может быть null).
create function public.get_matches()
returns table (
  match_id            uuid,
  matched_at          timestamptz,
  partner_id          uuid,
  partner_name        text,
  partner_photo_path  text,
  last_message_body   text,
  last_message_at     timestamptz,
  last_message_sender uuid,
  unread_count        int
)
language sql stable security invoker set search_path = ''
as $$
  select
    m.id,
    m.created_at,
    p.id,
    p.name,
    p.photo_paths[1],
    lm.body,
    lm.created_at,
    lm.sender,
    un.cnt
  from public.matches m
  join public.profiles p
    on p.id = case when m.user_a = auth.uid() then m.user_b else m.user_a end
  left join public.match_reads r
    on r.match_id = m.id and r.user_id = auth.uid()
  left join lateral (
    select ms.body, ms.created_at, ms.sender
    from public.messages ms
    where ms.match_id = m.id
    order by ms.created_at desc
    limit 1
  ) lm on true
  left join lateral (
    select count(*)::int as cnt
    from public.messages ms
    where ms.match_id = m.id
      and ms.sender <> auth.uid()
      and ms.created_at > coalesce(r.last_read_at, '-infinity'::timestamptz)
  ) un on true
  where auth.uid() in (m.user_a, m.user_b)
  order by coalesce(lm.created_at, m.created_at) desc;
$$;

-- Отметить диалог прочитанным. Только для своих матчей;
-- чужой или несуществующий match_id просто ничего не делает.
create function public.mark_match_read(p_match_id uuid)
returns void
language sql volatile security definer set search_path = ''
as $$
  insert into public.match_reads (match_id, user_id, last_read_at)
  select m.id, auth.uid(), now()
  from public.matches m
  where m.id = p_match_id and auth.uid() in (m.user_a, m.user_b)
  on conflict (match_id, user_id) do update set last_read_at = now();
$$;

-- Заблокировать пользователя: запись в blocks и удаление матча одной транзакцией.
-- Сообщения и match_reads удаляются каскадом. Повторный вызов безопасен.
create function public.block_user(p_target uuid)
returns void
language plpgsql volatile security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_target = auth.uid() then
    raise exception 'cannot block yourself' using errcode = '22023';
  end if;

  insert into public.blocks (blocker, blocked)
  values (auth.uid(), p_target)
  on conflict do nothing;

  delete from public.matches
  where user_a = least(auth.uid(), p_target)
    and user_b = greatest(auth.uid(), p_target);
end;
$$;

-- Создание матча при взаимном лайке.
create function public.create_match()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.liked and exists (
    select 1 from public.swipes
    where swiper = new.target and target = new.swiper and liked
  ) then
    insert into public.matches (user_a, user_b)
    values (least(new.swiper, new.target), greatest(new.swiper, new.target))
    on conflict do nothing;
  end if;
  return new;
end;
$$;

create trigger on_swipe_created
after insert on public.swipes
for each row execute function public.create_match();

-- Уведомить обоих участников, что матч удалён (блокировка или удаление аккаунта).
-- Приватные темы user:<uuid> не раскрывают события другим пользователям.
create function public.broadcast_match_deleted()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  perform realtime.send(
    jsonb_build_object('match_id', old.id),
    'match_deleted',
    'user:' || old.user_a::text,
    true
  );
  perform realtime.send(
    jsonb_build_object('match_id', old.id),
    'match_deleted',
    'user:' || old.user_b::text,
    true
  );
  return old;
end;
$$;

create trigger on_match_deleted_broadcast
after delete on public.matches
for each row execute function public.broadcast_match_deleted();

-- =========================================================
-- 3. ROW LEVEL SECURITY
-- =========================================================

alter table public.profiles    enable row level security;
alter table public.swipes      enable row level security;
alter table public.matches     enable row level security;
alter table public.messages    enable row level security;
alter table public.match_reads enable row level security;
alter table public.blocks      enable row level security;
alter table public.reports     enable row level security;

-- profiles: читать можно всех, кроме заблокированных (в обе стороны); править только свой
create policy "profiles_select" on public.profiles for select to authenticated
  using (id = auth.uid() or not private.is_blocked_between(auth.uid(), id));
create policy "profiles_insert" on public.profiles for insert to authenticated
  with check (id = auth.uid());
create policy "profiles_update" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- swipes: свои свайпы видно и создавать можно только от своего имени; чужие не видны
create policy "swipes_select" on public.swipes for select to authenticated
  using (swiper = auth.uid());
create policy "swipes_insert" on public.swipes for insert to authenticated
  with check (swiper = auth.uid() and not private.is_blocked_between(swiper, target));

-- matches: только участникам; создаёт их только триггер, удаляет только block_user()
create policy "matches_select" on public.matches for select to authenticated
  using (auth.uid() in (user_a, user_b));

-- messages: читать и писать только участникам матча, между которыми нет блокировки
create policy "messages_select" on public.messages for select to authenticated
  using (exists (
    select 1 from public.matches m
    where m.id = match_id
      and auth.uid() in (m.user_a, m.user_b)
      and not private.is_blocked_between(m.user_a, m.user_b)
  ));
create policy "messages_insert" on public.messages for insert to authenticated
  with check (
    sender = auth.uid()
    and exists (
      select 1 from public.matches m
      where m.id = match_id
        and auth.uid() in (m.user_a, m.user_b)
        and not private.is_blocked_between(m.user_a, m.user_b)
    )
  );

-- match_reads: видно только свои строки; запись только через mark_match_read()
create policy "match_reads_select" on public.match_reads for select to authenticated
  using (user_id = auth.uid());

-- blocks: клиент видит только свои блокировки; создаёт их только block_user()
create policy "blocks_select" on public.blocks for select to authenticated
  using (blocker = auth.uid());

-- reports: можно только создавать; читать жалобы клиент не может
create policy "reports_insert" on public.reports for insert to authenticated
  with check (reporter = auth.uid());

-- Приватные Broadcast-уведомления: пользователь может слушать только свою тему.
create policy "users_receive_own_match_events"
on realtime.messages for select to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and (select realtime.topic()) = 'user:' || (select auth.uid())::text
);

-- =========================================================
-- 4. REALTIME (для чата и уведомления о новом матче)
-- =========================================================
-- Realtime применяет RLS: подписчик получает только доступные ему строки.

alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.matches;

-- =========================================================
-- 5. ХРАНИЛИЩЕ ФОТО
-- =========================================================
-- Приватный бакет; путь файла: <user_id>/<filename>

insert into storage.buckets (id, name, public)
values ('photos', 'photos', false)
on conflict (id) do nothing;

create policy "photos_read" on storage.objects for select to authenticated
  using (bucket_id = 'photos');
create policy "photos_insert_own" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "photos_update_own" on storage.objects for update to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "photos_delete_own" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- =========================================================
-- 6. ПРАВА ДОСТУПА (GRANT)
-- =========================================================
-- Нужны, если отключено "Automatically expose new tables".
-- RLS решает, какие строки видны, а GRANT — можно ли обращаться к объекту.

grant usage on schema public to anon, authenticated;

-- Имя, пол и дата рождения после создания не меняются.
grant select, insert on public.profiles to authenticated;
grant update (bio, interested_in, photo_paths, min_age, max_age)
  on public.profiles to authenticated;
grant select, insert on public.swipes to authenticated;
grant select on public.matches to authenticated;
-- created_at сообщения всегда ставит сервер.
grant select on public.messages to authenticated;
grant insert (id, match_id, sender, body) on public.messages to authenticated;
grant select on public.match_reads to authenticated;
grant select on public.blocks to authenticated;
grant insert on public.reports to authenticated;

-- Функции: убираем доступ для анонимных пользователей, оставляем для вошедших.
revoke execute on function public.get_feed(int)                  from public, anon;
revoke execute on function public.get_matches()                  from public, anon;
revoke execute on function public.mark_match_read(uuid)          from public, anon;
revoke execute on function public.block_user(uuid)               from public, anon;
revoke execute on function public.create_match()                 from public, anon, authenticated;
revoke execute on function public.broadcast_match_deleted()      from public, anon, authenticated;
revoke execute on function private.is_blocked_between(uuid, uuid) from public, anon;
grant execute on function public.get_feed(int)                  to authenticated;
grant execute on function public.get_matches()                  to authenticated;
grant execute on function public.mark_match_read(uuid)          to authenticated;
grant execute on function public.block_user(uuid)               to authenticated;
grant execute on function private.is_blocked_between(uuid, uuid) to authenticated;

-- Supabase создаёт event-trigger для автоматического включения RLS. Он работает
-- от имени владельца и не должен быть доступен клиентским ролям как RPC.
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke execute on function public.rls_auto_enable() from public, anon, authenticated';
  end if;
end
$$;

-- =========================================================
-- ЗАМЕТКИ
-- =========================================================
-- * Клиент при создании профиля записывает min_age/max_age как возраст ±5 лет,
--   ограничивая результат диапазоном 18...99. Серверные default — безопасный fallback.
-- * Удаление аккаунта делает Edge Function supabase/functions/delete-account:
--   сначала очищает папку пользователя в Storage, затем вызывает
--   auth.admin.deleteUser(uid); внешние ключи каскадно удаляют данные из public.
-- * Перед релизом проверить RLS под разными пользователями: чужие свайпы, сообщения,
--   матчи, match_reads, blocks и reports не должны быть доступны.
-- * Внутренняя private.is_blocked_between() не выставляется через Data API и разрешает
--   проверять только блокировки с участием текущего пользователя.
-- * Блокировка необратима в MVP; block_user() удаляет матч вместе с перепиской.
-- * Жалоба хранит категорию и комментарий. Для модерации истории переписки понадобится
--   отдельный снимок сообщений до удаления матча.
-- * Защиты от спама сообщениями пока нет (лимит частоты вставки): вопрос этапа 6.
-- * В Supabase Auth перед production нужно выставить минимальную длину нового пароля 8;
--   проверка утёкших паролей доступна на Pro-плане и включается в Auth Settings.
-- * Для уже существующего проекта изменения настроек применяются через
--   settings_migration.sql. Этот schema.sql всегда должен содержать итоговое состояние.
