# delete-account

Защищённая Edge Function для удаления аккаунта текущего пользователя. ID берётся
из проверенного JWT, а не из тела запроса. Функция сначала удаляет фотографии из
приватного бакета `photos`, затем удаляет `auth.users`; внешние ключи из
`schema.sql` каскадно очищают профиль, свайпы, матчи и сообщения.

После привязки локального проекта к Supabase развернуть функцию можно командой:

```sh
supabase functions deploy delete-account
```

`SUPABASE_URL`, `SUPABASE_SECRET_KEYS` и остальные системные переменные Supabase
добавляет в hosted Edge Functions автоматически. `verify_jwt` намеренно оставлен
включённым в `supabase/config.toml`.
