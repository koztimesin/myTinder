-- Настройки выдачи ленты: возрастной диапазон 18...99.
-- Выполнить один раз в Supabase Dashboard -> SQL Editor до запуска новой версии клиента.

alter table public.profiles
  add column if not exists min_age integer not null default 18,
  add column if not exists max_age integer not null default 99;

-- Существующим профилям задаём начальный диапазон ±5 лет от их полного возраста.
-- Условие сохраняет уже настроенные пользователем значения при повторном запуске.
update public.profiles
set
  min_age = greatest(
    18,
    least(99, greatest(18, extract(year from age(current_date, birth_date))::integer)) - 5
  ),
  max_age = least(
    99,
    least(99, greatest(18, extract(year from age(current_date, birth_date))::integer)) + 5
  )
where min_age = 18 and max_age = 99;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_age_range_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_age_range_check
      check (18 <= min_age and min_age <= max_age and max_age <= 99);
  end if;
end
$$;

-- Возрастные предпочтения взаимны, как и существующий фильтр пола.
create or replace function public.get_feed(p_limit int default 20)
returns setof public.profiles
language sql stable security definer set search_path = ''
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
    and not public.is_blocked_between(auth.uid(), p.id)
  order by random()
  limit least(p_limit, 50);
$$;

grant update (min_age, max_age) on public.profiles to authenticated;

revoke execute on function public.get_feed(int) from public, anon;
grant execute on function public.get_feed(int) to authenticated;
