//
//  MatchesStore.swift
//  myTinder
//
//  Created by Ismail on 28.10.2026.
//

import Foundation
import Observation

/// Общее состояние матчей: список, очередь окон «Это матч», подписка на новые матчи.
/// Живёт столько же, сколько хост вкладок.
@MainActor
@Observable
final class MatchesStore {
    
    /// Все матчи в порядке сервера.
    private(set) var matches: [MatchSummary] = []
    /// `true`, когда список загружен хотя бы раз.
    private(set) var isLoaded = false
    /// Текст последней ошибки загрузки; `nil` после успешной загрузки.
    private(set) var errorMessage: String?
    /// Очередь матчей, для которых нужно показать окно «Это матч».
    private(set) var celebrations: [MatchSummary] = []
    
    /// Матч, для которого сейчас нужно показать окно.
    var currentCelebration: MatchSummary? { celebrations.first }
    
    private let repository: MatchRepositoryProtocol
    private var isReloading = false
    private var needsReload = false
    
    /// - Parameter repository: источник матчей и событий о новых матчах.
    init(repository: MatchRepositoryProtocol) {
        self.repository = repository
    }
    
    /// Загружает список и слушает новые матчи, пока задача не отменена.
    /// Если подписка оборвалась, через 5 секунд подключается заново.
    func run() async {
        
        while !Task.isCancelled {
            
            await reload()
            
            for await _ in repository.newMatchSignals() {
                await reload()
            }
            guard !Task.isCancelled else { return }
            
            try? await Task.sleep(for: .seconds(5))
        }
    }
    
    /// Перезагружает список. Вызовы во время загрузки не дублируют запрос,
    /// а ставят одну повторную загрузку после текущей.
    func reload() async {
        
        if isReloading {
            needsReload = true
            return
        }
        
        isReloading = true
        
        repeat {
            needsReload = false
            await loadOnce()
        } while needsReload
        isReloading = false
    }
    
    /// Убирает из очереди окно «Это матч» для указанного матча.
    /// - Parameter id: матч, окно которого закрыли. Если он уже не первый в очереди, ничего не делает.
    func dismissCelebration(id: UUID) {
        guard celebrations.first?.id == id else { return }
        
        celebrations.removeFirst()
    }
    
    /// Один запрос списка и применение результата.
    private func loadOnce() async {
        do {
            let fresh = try await repository.fetchMatches()
            apply(fresh)
            errorMessage = nil
        } catch {
            guard !Task.isCancelled else { return }
            
            errorMessage = "Не удалось загрузить матчи. Проверьте соединение."
        }
    }
    
    /// Сохраняет свежий список; после первой загрузки новые `id` попадают в очередь окон.
    /// - Parameter fresh: список с сервера.
    private func apply(_ fresh: [MatchSummary]) {
        if isLoaded {
            let known = Set(matches.map(\.id))
            celebrations.append(contentsOf: fresh.filter { !known.contains($0.id) })
        }
        matches = fresh
        isLoaded = true
    }
}
