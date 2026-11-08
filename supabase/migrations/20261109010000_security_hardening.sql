-- Закрыть внутренние функции от прямого вызова через Data API и убрать
-- из клиентского приложения исходный xcconfig (изменение Xcode-проекта отдельно).

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

alter default privileges revoke execute on functions from public;
alter default privileges in schema public revoke execute on functions from anon, authenticated;
alter default privileges in schema private revoke execute on functions from anon, authenticated;

create or replace function private.is_blocked_between(a uuid, b uuid)
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

revoke execute on function private.is_blocked_between(uuid, uuid) from public, anon;
grant execute on function private.is_blocked_between(uuid, uuid) to authenticated;

create or replace function public.get_feed(p_limit int default 20)
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

drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select" on public.profiles for select to authenticated
  using (id = auth.uid() or not private.is_blocked_between(auth.uid(), id));

drop policy if exists "swipes_insert" on public.swipes;
create policy "swipes_insert" on public.swipes for insert to authenticated
  with check (swiper = auth.uid() and not private.is_blocked_between(swiper, target));

drop policy if exists "messages_select" on public.messages;
create policy "messages_select" on public.messages for select to authenticated
  using (exists (
    select 1 from public.matches m
    where m.id = match_id
      and auth.uid() in (m.user_a, m.user_b)
      and not private.is_blocked_between(m.user_a, m.user_b)
  ));

drop policy if exists "messages_insert" on public.messages;
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

drop function public.is_blocked_between(uuid, uuid);

revoke execute on function public.get_feed(int) from public, anon;
grant execute on function public.get_feed(int) to authenticated;

do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke execute on function public.rls_auto_enable() from public, anon, authenticated';
  end if;
end
$$;
