//
//  AccountRepository.swift
//  myTinder
//
//  Created by Codex on 07.11.2026.
//

import Supabase

/// Необратимые операции над аккаунтом текущего пользователя.
protocol AccountRepositoryProtocol: Sendable {

    /// Удаляет аккаунт и связанные с ним данные на сервере.
    func deleteAccount() async throws
}

/// Удаляет аккаунт через защищённую Supabase Edge Function.
struct SupabaseAccountRepository {

    let client: SupabaseClient
}

extension SupabaseAccountRepository: AccountRepositoryProtocol {

    func deleteAccount() async throws {
        try await client.functions.invoke("delete-account")

        // Edge Function уже удалила пользователя и все его сессии. Локальный
        // signOut нужен, чтобы auth stream немедленно вернул приложение ко входу.
        try? await client.auth.signOut(scope: .local)
    }
}
