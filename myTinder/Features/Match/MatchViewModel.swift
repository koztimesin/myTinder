//
//  MatchViewModel.swift
//  myTinder
//
//  Created by Ismail on 28.10.2026.
//

import Foundation
import Observation

enum MatchesScreenState: Equatable {
    /// Первая загрузка идёт.
    case loading
    /// Первая загрузка не удалась.
    case failed
    /// Загрузка прошла, матчей нет.
    case empty
    /// Есть матчи.
    case content
}

@MainActor
@Observable
final class MatchesViewModel {
    
    private let store: MatchesStore
    private let photoURLProvider: PhotoURLProviderProtocol
    private let onOpenFeed: @MainActor () -> Void
    private let onSelectMatch: @MainActor (UUID) -> Void
    private var photoURLs: [String: URL] = [:]
    
    /// - Parameters:
    ///   - store: общее хранилище матчей.
    ///   - photoURLProvider: выдача ссылок на фото.
    ///   - onOpenFeed: переход на вкладку «Лента».
    ///   - onSelectMatch: открытие диалога (чат появится на этапе 5).
    init(
        store: MatchesStore,
        photoURLProvider: PhotoURLProviderProtocol,
        onOpenFeed: @escaping @MainActor () -> Void,
        onSelectMatch: @escaping @MainActor (UUID) -> Void
    ) {
        self.store = store
        self.photoURLProvider = photoURLProvider
        self.onOpenFeed = onOpenFeed
        self.onSelectMatch = onSelectMatch
    }
    
    /// Собирает модель аватара собеседника.
    private func avatar(for partner: MatchPartner, diameter: CGFloat, showsRing: Bool) -> MatchAvatarViewModel {
        MatchAvatarViewModel(
            name: partner.name,
            photoURL: partner.photoPath.flatMap { photoURLs[$0] },
            diameter: diameter,
            showsRing: showsRing
        )
    }
    
    /// Формирует подпись времени: время для сегодняшних, «Вчера» или дата.
    private func timeText(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(date) {
            return "Вчера"
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

extension MatchesViewModel: MatchesViewModelProtocol {
    
    var state: MatchesScreenState {
        if !store.isLoaded {
            return store.errorMessage == nil ? .loading : .failed
        }
        return store.matches.isEmpty ? .empty : .content
    }
    
    var errorMessage: String? { store.errorMessage }
    
    var newItems: [NewMatchItemViewModel] {
        let onSelect = onSelectMatch
        return store.matches.filter(\.isNew).map { match in
            NewMatchItemViewModel(
                id: match.id,
                name: match.partner.name,
                avatar: avatar(for: match.partner, diameter: 72, showsRing: true),
                onTap: { onSelect(match.id) }
            )
        }
    }
    
    var dialogRows: [MatchRowViewModel] {
        let onSelect = onSelectMatch
        return store.matches.compactMap { match in
            
            guard let message = match.lastMessage else { return nil }
            
            return MatchRowViewModel(
                id: match.id,
                name: match.partner.name,
                preview: message.isFromMe ? "Вы: \(message.body)" : message.body,
                timeText: timeText(for: message.sentAt),
                avatar: avatar(for: match.partner, diameter: 56, showsRing: false),
                onTap: { onSelect(match.id) }
            )
        }
    }
    
    var photoPaths: [String] {
        store.matches.compactMap { $0.partner.photoPath }
    }
    
    func loadPhotos() async {
        let paths = photoPaths
        
        guard !paths.isEmpty else { return }
        
        let urls = await photoURLProvider.urls(for: paths)
        photoURLs.merge(urls) { _, new in new }
    }
    
    func refresh() async {
        await store.reload()
        await loadPhotos()
    }
    
    func openFeed() {
        onOpenFeed()
    }
}
