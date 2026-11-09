//
//  AccountRepository.swift
//  myTinder
//
//  Created by Codex on 07.11.2026.
//

import Supabase

/// Удаляет аккаунт через защищённую Supabase Edge Function.
struct AccountRepository {

    let client: SupabaseClient
}

extension AccountRepository: AccountRepositoryProtocol {

    func deleteAccount() async throws {
        try await client.functions.invoke("delete-account")

        // Edge Function уже удалила пользователя и все его сессии. Локальный
        // signOut нужен, чтобы auth stream немедленно вернул приложение ко входу.
        try? await client.auth.signOut(scope: .local)
    }
}
