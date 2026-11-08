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

/// Маршруты внутри вкладки профиля.
enum ProfileRoute: Hashable {
    /// Настройки выдачи ленты.
    case settings
    /// Подготовка к удалению аккаунта.
    case deleteAccount
}

/// Хранит выбранную вкладку, чтобы её могли переключать модели экранов.
@MainActor
@Observable
final class MainTabRouter {
    
    /// Выбранная вкладка.
    var selectedTab: MainTab = .feed
    
    /// Открытые чаты во вкладке «Матчи» (идентификаторы матчей).
    var matchesPath: [UUID] = []
    /// Открытые экраны во вкладке «Профиль».
    var profilePath: [ProfileRoute] = []
    
    func openChat(_ matchID: UUID) {
        selectedTab = .matches
        matchesPath = [matchID]
    }

    /// Закрывает открытый чат, если соответствующего матча больше нет.
    /// - Parameter matchIDs: актуальные идентификаторы матчей пользователя.
    func closeMissingChat(matchIDs: Set<UUID>) {
        guard let openMatchID = matchesPath.last, !matchIDs.contains(openMatchID) else { return }
        matchesPath = []
    }

    /// Открывает настройки во вкладке профиля.
    func openSettings() {
        profilePath.append(.settings)
    }

    /// Открывает экран удаления аккаунта.
    func openDeleteAccount() {
        profilePath.append(.deleteAccount)
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
    /// Модель профиля живёт вместе с хостом и принимает изменения из настроек.
    @State private var editProfileViewModel: EditProfileViewModel
    
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

        let feedViewModel = container.makeFeedViewModel()
        _feedViewModel = State(initialValue: feedViewModel)
        
        let router = MainTabRouter()
        let store = container.makeMatchesStore()
        _router = State(initialValue: router)
        _matchesStore = State(initialValue: store)
        _matchesViewModel = State(initialValue: container.makeMatchesViewModel(
            store: store,
            onOpenFeed: { router.selectedTab = .feed },
            onSelectMatch: { id in router.openChat(id) }
        ))
        _editProfileViewModel = State(initialValue: container.makeEditProfileViewModel(
            profile: profile,
            onUpdated: onProfileUpdated,
            onDiscoveryUpdated: { Task { await feedViewModel.reload() } },
            onOpenSettings: { router.openSettings() },
            onSignOut: onSignOut
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
                NavigationStack(path: $router.profilePath) {
                    EditProfileView(viewModel: editProfileViewModel)
                        .navigationDestination(for: ProfileRoute.self) { route in
                            profileDestination(for: route)
                        }
                }
            }
        }
        .tint(AppTheme.Colors.accentText)
        .task { await matchesStore.run() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await matchesStore.reload() }
            }
        }
        .onChange(of: matchesStore.matches.map(\.id)) { _, matchIDs in
            guard matchesStore.isLoaded else { return }
            router.closeMissingChat(matchIDs: Set(matchIDs))
        }
        .fullScreenCover(item: celebrationBinding) { match in
            CelebrationPresenter { makeCelebrationViewModel(for: match) }
                .id(match.id)
                .interactiveDismissDisabled()
        }
    }
    
    // MARK: - Окно «Это матч»

    /// Экран для маршрута вкладки профиля.
    /// - Parameter route: выбранный маршрут.
    @ViewBuilder
    private func profileDestination(for route: ProfileRoute) -> some View {
        switch route {
        case .settings:
            SettingsPresenter { makeSettingsViewModel() }
        case .deleteAccount:
            DeleteAccountPresenter { container.makeDeleteAccountViewModel() }
        }
    }

    /// Собирает общие настройки приложения.
    /// - Returns: модель с маршрутом удаления аккаунта.
    private func makeSettingsViewModel() -> SettingsViewModel {
        container.makeSettingsViewModel(onOpenDeleteAccount: router.openDeleteAccount)
    }
    
    /// Привязка к текущему окну. Обычно оно закрывается кнопками;
    /// setter оставляет store согласованным при принудительном системном закрытии.
    private var celebrationBinding: Binding<MatchSummary?> {
        Binding(
            get: { matchesStore.currentCelebration },
            set: { value in
                guard value == nil, let current = matchesStore.currentCelebration else { return }
                matchesStore.dismissCelebration(id: current.id)
            }
        )
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
            onRead: { Task { await store.reload() } },
            onBlocked: {
                router.matchesPath = []
                Task { await store.reload() }
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

/// Создаёт модель настроек один раз на открытие экрана.
private struct SettingsPresenter: View {

    @State private var viewModel: SettingsViewModel

    /// - Parameter makeViewModel: фабрика модели, вызываемая один раз при создании.
    init(makeViewModel: () -> SettingsViewModel) {
        _viewModel = State(initialValue: makeViewModel())
    }

    var body: some View {
        SettingsView(viewModel: viewModel)
    }
}

/// Создаёт модель удаления аккаунта один раз на открытие экрана.
private struct DeleteAccountPresenter: View {

    @State private var viewModel: DeleteAccountViewModel

    /// - Parameter makeViewModel: фабрика модели, вызываемая один раз при создании.
    init(makeViewModel: () -> DeleteAccountViewModel) {
        _viewModel = State(initialValue: makeViewModel())
    }

    var body: some View {
        DeleteAccountView(viewModel: viewModel)
    }
}
