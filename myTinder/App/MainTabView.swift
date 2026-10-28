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
            onSelectMatch: { _ in /* ToDo */ }
        ))
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            
            Tab("Лента", systemImage: "rectangle.stack", value: MainTab.feed) {
                FeedView(viewModel: feedViewModel)
            }

            Tab("Матчи", systemImage: "heart", value: MainTab.matches) {
                MatchesView(viewModel: matchesViewModel)
            }

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
                router.selectedTab = .matches
                store.dismissCelebration(id: match.id)
            },
            onDismiss: {
                store.dismissCelebration(id: match.id)
            }
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
