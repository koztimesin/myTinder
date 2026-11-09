# myTinder

Приложения для знакомств в стиле Tinder, написанный на SwiftUI и Supabase. Проект охватывает полный MVP-сценарий: создание профиля, персонализированную ленту, свайпы, матчи, realtime-чат и инструменты безопасности.

## Стек

- Swift 6 и Swift Concurrency;
- SwiftUI и Observation (`@Observable`);
- Supabase Auth, Postgres, Storage, Realtime и Edge Functions;
- Swift Testing;
- GitHub Actions.

Минимальная версия системы — iOS 18.6.

## Архитектура

Проект разделён на UI, модели экрана, доменные модели и слой данных:

```text
SwiftUI View
    ↓
@Observable ViewModel / Store
    ↓
Use Case / Repository Protocol
    ↓
Supabase Repository
    ↓
Auth · Postgres · Storage · Realtime · Edge Functions
```

- `AppContainer` собирает зависимости и не позволяет экранам создавать сетевые сервисы напрямую.
- ViewModel изолированы на `MainActor`; сетевые границы описаны `Sendable`-протоколами.
- `FeedUseCase` удаляет дубли между пакетами, а `FeedViewModel` защищается от устаревших ответов через generation token.
- `ProfileStore` и `MatchesStore` хранят общее состояние между экранами.
- Репозитории скрывают DTO, PostgREST, Storage и Realtime от UI-слоя.
- Приватные фотографии выдаются приложению через временные signed URL.

## Настройка Supabase

Для нового проекта достаточно полной схемы [`schema.sql`](schema.sql). Она создаёт таблицы, ограничения, индексы, RLS-политики, функции, триггеры, realtime-настройки и приватный bucket `photos`.

1. Создайте проект в Supabase.
2. Откройте **SQL Editor** и выполните содержимое `schema.sql`.
3. Установите [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) и войдите в аккаунт.
4. Свяжите репозиторий с проектом:

   ```bash
   supabase link --project-ref <project-ref>
   ```

5. Разверните защищённую функцию удаления аккаунта:

   ```bash
   supabase functions deploy delete-account
   ```

Edge Function получает ID пользователя только из проверенного JWT, сначала удаляет его файлы из Storage, а затем Auth-пользователя. Внешние ключи с `on delete cascade` очищают профиль, свайпы, матчи и сообщения.

## Локальный запуск

1. Скопируйте пример конфигурации:

   ```bash
   cp Secrets.example.xcconfig Secrets.xcconfig
   ```

2. В `Secrets.xcconfig` укажите Project URL и **publishable key** из Supabase Dashboard:

   ```xcconfig
   SUPABASE_URL = https:/$()/your-project.supabase.co
   SUPABASE_PUBLISHABLE_KEY = your-publishable-key
   ```

3. Откройте `myTinder.xcodeproj`, выберите схему `myTinder` и запустите приложение.

`Secrets.xcconfig` исключён из Git. Secret/service-role ключи не должны добавляться в iOS-приложение или репозиторий.

## Тесты

Unit-тесты используют Swift Testing и управляемые заглушки репозиториев. Они не обращаются к реальному Supabase и не зависят от сетевых задержек.

Покрыты:

- валидация, создание и редактирование профиля;
- rollback загруженных фотографий и восстановление после неоднозначных ошибок;
- дедупликация, пополнение и конкурентные состояния ленты;
- очередь новых матчей и непрочитанные сообщения;
- загрузка, пагинация, realtime и optimistic send в чате;
- жалобы, блокировка, темы и удаление аккаунта.

Запуск из терминала:

```bash
xcodebuild \
  -project myTinder.xcodeproj \
  -scheme myTinder \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -only-testing:myTinderTests \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## CI

GitHub Actions при каждом pull request и push в `main`:

1. создаёт безопасную конфигурацию из `Secrets.example.xcconfig`;
2. восстанавливает кэш Swift Package Manager;
3. собирает приложение для iOS Simulator;
4. запускает только unit-тесты `myTinderTests`.

CI не подключается к Supabase и не требует repository secrets.
