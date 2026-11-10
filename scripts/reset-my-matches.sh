#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd -- "$script_dir/.." && pwd)"
env_file="$project_root/supabase/.env"

if ! command -v supabase >/dev/null 2>&1; then
  echo "Supabase CLI не найден. Установите его и выполните supabase login."
  exit 1
fi

user_id="${MYTINDER_DEV_USER_ID:-}"

if [[ -z "$user_id" && -f "$env_file" ]]; then
  user_id="$(sed -n 's/^MYTINDER_DEV_USER_ID=//p' "$env_file" | tail -n 1 | tr -d '\r')"
fi

if [[ ! "$user_id" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$ ]]; then
  echo "Добавьте MYTINDER_DEV_USER_ID=<uuid> в supabase/.env."
  exit 1
fi

echo "Будут удалены все матчи и свайпы пользователя $user_id."
echo "Сообщения и отметки прочтения в удалённых матчах также удалятся каскадно."
read -r -p "Продолжить? [y/N] " confirmation

if [[ "$confirmation" != "y" && "$confirmation" != "Y" ]]; then
  echo "Отменено."
  exit 0
fi

sql="$(cat <<SQL
with deleted_matches as (
  delete from public.matches
  where '$user_id'::uuid in (user_a, user_b)
  returning id
),
deleted_swipes as (
  delete from public.swipes
  where (swiper = '$user_id'::uuid or target = '$user_id'::uuid)
    and (select count(*) from deleted_matches) >= 0
  returning swiper, target
)
select
  (select count(*) from deleted_matches) as deleted_matches,
  (select count(*) from deleted_swipes) as deleted_swipes;
SQL
)"

supabase db query \
  --workdir "$project_root" \
  --remote \
  --yes \
  "$sql"
