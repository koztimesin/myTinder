-- Приватно уведомлять участников об удалении матча, чтобы клиент сразу
-- обновил список и закрыл открытый диалог.

create or replace function public.broadcast_match_deleted()
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

drop trigger if exists on_match_deleted_broadcast on public.matches;
create trigger on_match_deleted_broadcast
after delete on public.matches
for each row execute function public.broadcast_match_deleted();

drop policy if exists "users_receive_own_match_events" on realtime.messages;
create policy "users_receive_own_match_events"
on realtime.messages for select to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and (select realtime.topic()) = 'user:' || (select auth.uid())::text
);

revoke execute on function public.broadcast_match_deleted() from public, anon, authenticated;
