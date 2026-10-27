//
//  FeedRepository.swift
//  myTinder
//
//  Created by Ismail on 26.10.2026.
//

import Foundation
import Supabase

/// Доступ к ленте и свайпам.
protocol FeedRepositoryProtocol: Sendable {
    /// Запрашивает пакет анкет, которых пользователь ещё не свайпал.
    /// - Parameter limit: сколько анкет запросить (сервер ограничивает 50).
    /// - Returns: профили в случайном порядке; пустой массив, если анкеты закончились.
    func fetchFeed(limit: Int) async throws -> [Profile]

    /// Записывает свайп текущего пользователя.
    /// - Parameters:
    ///   - targetID: профиль, на который свайпнули.
    ///   - liked: `true` — лайк, `false` — дизлайк.
    func sendSwipe(targetID: UUID, liked: Bool) async throws
}

/// Реализация `FeedRepositoryProtocol` поверх Supabase.
struct SupabaseFeedRepository {
    /// Клиент Supabase.
    let client: SupabaseClient
}

extension SupabaseFeedRepository: FeedRepositoryProtocol {
    func fetchFeed(limit: Int) async throws -> [Profile] {
        let dtos: [ProfileDTO] = try await client
            .rpc("get_feed", params: GetFeedParams(limit: limit))
            .execute()
            .value
        
        return dtos.compactMap { try? $0.toDomain() }
    }

    func sendSwipe(targetID: UUID, liked: Bool) async throws {
        let session = try await client.auth.session
        let dto = SwipeDTO(swiper: session.user.id, target: targetID, liked: liked)
        
        do {
            try await client.from("swipes").insert(dto).execute()
        } catch let error as PostgrestError where error.code == PostgresErrorCode.uniqueViolation {
            // Свайп уже записан (повторная отправка): для клиента это успех.
            return
        }
    }
}
