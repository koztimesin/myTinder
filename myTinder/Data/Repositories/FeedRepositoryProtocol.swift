//
//  FeedRepositoryProtocol.swift
//  myTinder
//
//  Created by Ismail on 09.11.2026.
//

import Foundation

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
