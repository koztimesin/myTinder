# myTinder

Приложения для знакомств на SwiftUI и Supabase.

## Локальная настройка

1. Скопируйте `Secrets.example.xcconfig` в `Secrets.xcconfig`.
2. Укажите Project URL и publishable key из Supabase Dashboard.
3. Откройте `myTinder.xcodeproj` и запустите схему `myTinder`.

## CI

GitHub Actions собирает приложение для iOS Simulator при каждом Pull Request и при отправке изменений в `main`.
Workflow использует только тестовые placeholder-значения из `Secrets.example.xcconfig`; доступ к Supabase и repository secrets ему не требуется.
