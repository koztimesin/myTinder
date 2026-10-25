//
//  PhotoURLCache.swift
//  myTinder
//
//  Created by Ismail on 25.10.2026.
//

import Foundation

/// Кэш временных ссылок на фото в памяти. Живёт в `AppContainer` в единственном экземпляре.
/// Запрашивает у репозитория только те ссылки, которых нет или которые скоро истекут,
/// причём одним батч-запросом.
actor PhotoURLCache {
    
    /// Ссылка и момент, когда она перестанет работать.
    private struct Entry {
        let url: URL
        let expiresAt: Date
    }
    
    private var entries: [String: Entry] = [:]
    private let repository: PhotoRepositoryProtocol
    /// Срок жизни выдаваемых ссылок в секундах.
    private let lifetime: Int
    /// За сколько секунд до истечения ссылка считается устаревшей и запрашивается заново.
    private let refreshMargin: TimeInterval
    
    /// - Parameters:
    ///   - repository: источник ссылок.
    ///   - lifetime: срок жизни ссылок в секундах (по умолчанию час).
    ///   - refreshMargin: запас до истечения в секундах (по умолчанию 5 минут).
    init(repository: PhotoRepositoryProtocol, lifetime: Int = 3600, refreshMargin: TimeInterval = 300) {
        self.repository = repository
        self.lifetime = lifetime
        self.refreshMargin = refreshMargin
    }
}

// MARK: - PhotoURLProviderProtocol

extension PhotoURLCache: PhotoURLProviderProtocol {
    
    /// Отдаёт ссылки из кэша, недостающие и скоро истекающие запрашивает заново.
    /// Если запрос не удался, возвращает то, что ещё действует в кэше.
    func urls(for paths: [String]) async -> [String: URL] {
        let now = Date.now
        let stale = paths.filter { path in
            guard let entry = entries[path] else { return true }
            return entry.expiresAt.timeIntervalSince(now) < refreshMargin
        }
        
        if !stale.isEmpty,
           let fresh = try? await repository.signedURLs(for: stale, expiresIn: lifetime) {
            let expiresAt = now.addingTimeInterval(TimeInterval(lifetime))
            for (path, url) in fresh {
                entries[path] = Entry(url: url, expiresAt: expiresAt)
            }
        }
        
        var result: [String: URL] = [:]
        for path in paths {
            if let entry = entries[path], entry.expiresAt > .now {
                result[path] = entry.url
            }
        }
        return result
    }
}
