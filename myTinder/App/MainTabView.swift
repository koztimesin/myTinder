//
//  MainTabView.swift
//  myTinder
//
//  Created by Ismail on 27.10.2026.
//

import SwiftUI

/// Вкладки хоста.
enum MainTab: Hashable {
    case feed, matches, profile
}

/// Хранит выбранную вкладку, чтобы её могли переключать модели экранов.
@MainActor
@Observable
final class MainTabRouter {
    
    /// Выбранная вкладка.
    var selectedTab: MainTab = .feed
    
    /// Открытые чаты во вкладке «Матчи» (идентификаторы матчей).
    var matchesPath: [UUID] = []
    
    func openChat(_ matchID: UUID) {
        selectedTab = .matches
        matchesPath = [matchID]
    }
}

struct MainTabView: View {
    
    /// Контейнер зависимостей.
    private let container: AppContainer
    /// Профиль текущего пользователя.
    private let profile: Profile
    /// Вызывается, когда профиль обновлён на экране «Профиль».
    private let onProfileUpdated: @MainActor (Profile) -> Void
    /// Вызывается при выходе из аккаунта.
    private let onSignOut: @MainActor () -> Void
    
    /// Модель ленты: создаётся один раз и живёт, пока жив хост.
    @State private var feedViewModel: FeedViewModel
    /// Выбранная вкладка.
    @State private var router: MainTabRouter
    /// Общее хранилище матчей.
    @State private var matchesStore: MatchesStore
    /// Модель экрана «Матчи».
    @State private var matchesViewModel: MatchesViewModel
    
    @Environment(\.scenePhase) private var scenePhase
    
    /// - Parameters:
    ///   - container: контейнер зависимостей.
    ///   - profile: профиль текущего пользователя.
    ///   - onProfileUpdated: колбэк обновления профиля.
    ///   - onSignOut: колбэк выхода.
    init(
        container: AppContainer,
        profile: Profile,
        onProfileUpdated: @escaping @MainActor (Profile) -> Void,
        onSignOut: @escaping @MainActor () -> Void
    ) {
        self.container = container
        self.profile = profile
        self.onProfileUpdated = onProfileUpdated
        self.onSignOut = onSignOut
        _feedViewModel = State(initialValue: container.makeFeedViewModel())
        
        let router = MainTabRouter()
        let store = container.makeMatchesStore()
        _router = State(initialValue: router)
        _matchesStore = State(initialValue: store)
        _matchesViewModel = State(initialValue: container.makeMatchesViewModel(
            store: store,
            onOpenFeed: { router.selectedTab = .feed },
            onSelectMatch: { id in router.openChat(id) }
        ))
    }
    
    var body: some View {
        TabView(selection: $router.selectedTab) {
            
            Tab("Лента", systemImage: "rectangle.stack", value: MainTab.feed) {
                FeedView(viewModel: feedViewModel)
            }
            
            Tab("Матчи", systemImage: "heart", value: MainTab.matches) {
                NavigationStack(path: $router.matchesPath) {
                    MatchesView(viewModel: matchesViewModel)
                        .navigationDestination(for: UUID.self) { matchID in
                            chatDestination(for: matchID)
                        }
                }
            }
            .badge(matchesStore.unreadTotal)
            
            Tab("Профиль", systemImage: "person.crop.circle", value: MainTab.profile) {
                EditProfileView(
                    viewModel: container.makeEditProfileViewModel(
                        profile: profile,
                        onUpdated: onProfileUpdated,
                        onSignOut: onSignOut
                    )
                )
            }
        }
        .tint(AppTheme.Colors.accentText)
        .task { await matchesStore.run() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await matchesStore.reload() }
            }
        }
        .fullScreenCover(item: celebrationBinding) { match in
            CelebrationPresenter { makeCelebrationViewModel(for: match) }
                .id(match.id)
        }
    }
    
    // MARK: - Окно «Это матч»
    
    /// Привязка к текущему окну. Закрывается только кнопками, поэтому запись игнорируется.
    private var celebrationBinding: Binding<MatchSummary?> {
        Binding(get: { matchesStore.currentCelebration }, set: { _ in })
    }
    
    /// Собирает модель окна «Это матч».
    /// - Parameter match: матч, для которого показывается окно.
    /// - Returns: модель с действиями «Написать» и «Продолжить».
    private func makeCelebrationViewModel(for match: MatchSummary) -> MatchCelebrationViewModel {
        let router = router
        let store = matchesStore
        
        return container.makeMatchCelebrationViewModel(
            match: match,
            myPhotoPath: profile.photoPaths.first,
            onWrite: {
                router.openChat(match.id)
                store.dismissCelebration(id: match.id)
            },
            onDismiss: {
                store.dismissCelebration(id: match.id)
            }
        )
    }
    
    /// Экран чата для матча из навигации.
    /// - Parameter matchID: матч диалога.
    @ViewBuilder
    private func chatDestination(for matchID: UUID) -> some View {
        if let match = matchesStore.matches.first(where: { $0.id == matchID }) {
            ChatPresenter { makeChatViewModel(for: match) }
                .id(matchID)
        }
    }
    
    /// Собирает модель чата.
    /// - Parameter match: матч диалога.
    private func makeChatViewModel(for match: MatchSummary) -> ChatViewModel {
        let store = matchesStore
        return container.makeChatViewModel(
            matchID: match.id,
            partner: match.partner,
            currentUserID: profile.id,
            onRead: { Task { await store.reload() } }
        )
    }
}

/// Создаёт модель окна «Это матч» один раз на показ, чтобы перерисовки не сбрасывали её состояние.
private struct CelebrationPresenter: View {
    
    @State private var viewModel: MatchCelebrationViewModel
    
    /// - Parameter makeViewModel: фабрика модели, вызывается один раз при создании.
    init(makeViewModel: () -> MatchCelebrationViewModel) {
        _viewModel = State(initialValue: makeViewModel())
    }
    
    var body: some View {
        MatchCelebrationView(viewModel: viewModel)
    }
}

/// Создаёт модель чата один раз на открытие, чтобы перерисовки не сбрасывали состояние.
private struct ChatPresenter: View {
    
    @State private var viewModel: ChatViewModel
    
    /// - Parameter makeViewModel: фабрика модели, вызывается при создании.
    init(makeViewModel: () -> ChatViewModel) {
        _viewModel = State(initialValue: makeViewModel())
    }
    
    var body: some View {
        ChatView(viewModel: viewModel)
    }
}
