//
//  FeedUseCase.swift
//  myTinder
//
//  Created by Ismail on 26.10.2026.
//

import Foundation

/// Подготовка ленты: пакеты без дублей и отправка свайпов.
@MainActor
protocol FeedUseCaseProtocol: AnyObject {
    
    /// Загружает следующий пакет, отбрасывая анкеты, уже выданные в этой сессии.
    /// - Returns: новые карточки; пустой массив, если показывать больше нечего.
    func loadNextBatch() async throws -> [FeedCard]

    /// Отправляет свайп.
    /// - Parameters:
    ///   - card: карточка, на которую свайпнули.
    ///   - liked: `true` — лайк, `false` — дизлайк.
    func swipe(on card: FeedCard, liked: Bool) async throws

    /// Забывает выданные анкеты (для «Обновить»).
    func reset()
}

/// Реализация `FeedUseCaseProtocol`. Нужна из-за дублей: свайп уходит в фоне,
/// и сервер может вернуть анкету, свайп на которую ещё не дошёл.
@MainActor
final class FeedUseCase {
    /// Репозиторий ленты.
    private let repository: FeedRepositoryProtocol
    /// Размер запрашиваемого пакета.
    private let batchSize: Int
    /// Идентификаторы анкет, уже выданных в этой сессии.
    private var servedIDs: Set<UUID> = []

    /// - Parameters:
    ///   - repository: репозиторий ленты.
    ///   - batchSize: размер пакета (по умолчанию 20).
    init(repository: any FeedRepositoryProtocol, batchSize: Int = 20) {
        self.repository = repository
        self.batchSize = batchSize
    }
}

extension FeedUseCase: FeedUseCaseProtocol {
    
    func loadNextBatch() async throws -> [FeedCard] {
        let profiles = try await repository.fetchFeed(limit: batchSize)
        let fresh = profiles.filter { !servedIDs.contains($0.id) }
        servedIDs.formUnion(fresh.map(\.id))
        return fresh.map { FeedCard(profile: $0) }
    }

    func swipe(on card: FeedCard, liked: Bool) async throws {
        try await repository.sendSwipe(targetID: card.id, liked: liked)
    }

    func reset() {
        servedIDs.removeAll()
    }
}
