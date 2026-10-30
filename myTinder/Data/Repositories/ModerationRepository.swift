//
//  ModerationRepository.swift
//  myTinder
//
//  Created by Ismail on 31.10.2026.
//

import Foundation
import Supabase

/// Жалобы и блокировка пользователей.
protocol ModerationRepositoryProtocol: Sendable {
    /// Отправляет жалобу от текущего пользователя.
    /// - Parameters:
    ///   - userID: на кого жалоба.
    ///   - category: причина.
    ///   - details: комментарий; `nil`, если его нет.
    func report(userID: UUID, category: ReportCategory, details: String?) async throws
    
    /// Блокирует пользователя и удаляет матч с ним (одной транзакцией на сервере).
    /// Повторная блокировка того же человека считается успехом.
    /// - Parameter userID: кого блокируем.
    func block(userID: UUID) async throws
}

struct SupabaseModerationRepository {
    /// Клиент Supabase.
    let client: SupabaseClient
}

extension SupabaseModerationRepository: ModerationRepositoryProtocol {
    
    func report(userID: UUID, category: ReportCategory, details: String?) async throws {
        let session = try await client.auth.session
        let dto = ReportDTO(
            reporter: session.user.id,
            reported: userID,
            category: category.rawValue,
            reason: details
        )
        try await client.from("reports").insert(dto).execute()
    }
    
    func block(userID: UUID) async throws {
        try await client
            .rpc("block_user", params: BlockUserParams(target: userID))
            .execute()
    }
}
