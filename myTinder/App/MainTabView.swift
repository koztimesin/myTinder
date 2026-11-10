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

/// Маршруты внутри вкладки матчей.
enum MatchesRoute: Hashable {
    case chat(UUID)

    var matchID: UUID {
        switch self {
        case .chat(let id): id
        }
    }
}

/// Маршруты внутри вкладки профиля.
enum ProfileRoute: Hashable {
    /// Редактирование данных и фотографий профиля.
    case editProfile
    /// Общие настройки аккаунта.
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
    
    /// Открытые экраны во вкладке «Матчи».
    var matchesPath: [MatchesRoute] = []
    /// Матч, чья анкета показана модально поверх чата.
    var presentedPartnerMatchID: UUID?
    /// Открытые экраны во вкладке «Профиль».
    var profilePath: [ProfileRoute] = []
    
    func openChat(_ matchID: UUID) {
        selectedTab = .matches
        matchesPath = [.chat(matchID)]
    }

    func openPartnerProfile(_ matchID: UUID) {
        presentedPartnerMatchID = matchID
    }

    /// Закрывает открытый чат, если соответствующего матча больше нет.
    /// - Parameter matchIDs: актуальные идентификаторы матчей пользователя.
    func closeMissingChat(matchIDs: Set<UUID>) {
        guard let openMatchID = matchesPath.last?.matchID, !matchIDs.contains(openMatchID) else { return }
        matchesPath = []
    }

    /// Открывает настройки во вкладке профиля.
    func openSettings() {
        profilePath.append(.settings)
    }

    /// Открывает редактор профиля.
    func openEditProfile() {
        profilePath.append(.editProfile)
    }

    /// Открывает экран удаления аккаунта.
    func openDeleteAccount() {
        profilePath.append(.deleteAccount)
    }
}

/// Сохраняет модели открывавшихся чатов до удаления матча или выхода из аккаунта.
@MainActor
private final class ChatViewModelCache {
    private var models: [UUID: ChatViewModel] = [:]

    func model(for matchID: UUID, make: () -> ChatViewModel) -> ChatViewModel {
        if let model = models[matchID] { return model }
        let model = make()
        models[matchID] = model
        return model
    }

    func remove(_ matchID: UUID) {
        models[matchID] = nil
    }

    func retain(matchIDs: Set<UUID>) {
        models = models.filter { matchIDs.contains($0.key) }
    }

    func removeAll() {
        models.removeAll()
    }
}

/// Сохраняет уже загруженные анкеты, чтобы sheet не начинала с `.loading` повторно.
@MainActor
private final class PartnerProfileViewModelCache {
    private var models: [UUID: PartnerProfileViewModel] = [:]

    func model(for matchID: UUID, make: () -> PartnerProfileViewModel) -> PartnerProfileViewModel {
        if let model = models[matchID] { return model }
        let model = make()
        models[matchID] = model
        return model
    }

    func remove(_ matchID: UUID) {
        models[matchID] = nil
    }

    func retain(matchIDs: Set<UUID>) {
        models = models.filter { matchIDs.contains($0.key) }
    }

    func removeAll() {
        models.removeAll()
    }
}

/// Единый актуальный профиль для экранов внутри главного хоста.
@MainActor
@Observable
private final class CurrentProfileState {
    var profile: Profile

    init(profile: Profile) {
        self.profile = profile
    }
}

struct MainTabView: View {
    
    /// Контейнер зависимостей.
    private let container: AppContainer
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
    /// Актуальная версия профиля после редактирования или применения фильтров.
    @State private var currentProfile: CurrentProfileState
    /// История и черновики чатов, уже открытых в текущей сессии.
    @State private var chatCache: ChatViewModelCache
    @State private var partnerProfileCache: PartnerProfileViewModelCache
    /// Показывается ли модальная шторка фильтров.
    @State private var isFilterPresented = false
    
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
        self.onProfileUpdated = onProfileUpdated
        self.onSignOut = onSignOut

        let currentProfile = CurrentProfileState(profile: profile)
        _currentProfile = State(initialValue: currentProfile)

        let feedViewModel = container.makeFeedViewModel()
        _feedViewModel = State(initialValue: feedViewModel)
        
        let router = MainTabRouter()
        let store = container.makeMatchesStore()
        _chatCache = State(initialValue: ChatViewModelCache())
        _partnerProfileCache = State(initialValue: PartnerProfileViewModelCache())
        _router = State(initialValue: router)
        _matchesStore = State(initialValue: store)
        _matchesViewModel = State(initialValue: container.makeMatchesViewModel(
            store: store,
            onOpenFeed: { router.selectedTab = .feed },
            onSelectMatch: { id in router.openChat(id) }
        ))
        _editProfileViewModel = State(initialValue: container.makeEditProfileViewModel(
            profile: profile,
            onUpdated: { updated in
                currentProfile.profile = updated
                onProfileUpdated(updated)
            }
        ))
    }
    
    var body: some View {
        TabView(selection: $router.selectedTab) {
            
            Tab("Лента", systemImage: "sparkles", value: MainTab.feed) {
                FeedView(
                    viewModel: feedViewModel,
                    profilePhotoURL: editProfileViewModel.mainPhotoURL,
                    onOpenFilters: { isFilterPresented = true },
                    onOpenProfile: { router.selectedTab = .profile }
                )
            }
            
            Tab("Матчи", systemImage: "heart", value: MainTab.matches) {
                NavigationStack(path: $router.matchesPath) {
                    MatchesView(viewModel: matchesViewModel)
                        .navigationDestination(for: MatchesRoute.self) { route in
                            matchesDestination(for: route)
                        }
                }
                .toolbarVisibility(router.matchesPath.isEmpty ? .visible : .hidden, for: .tabBar)
                .sheet(isPresented: partnerProfilePresentation) {
                    partnerProfileCover
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(AppTheme.Radius.card)
                        .presentationBackground(AppTheme.Colors.background)
                }
            }
            .badge(matchesStore.unreadTotal)
            
            Tab("Профиль", systemImage: "person.crop.circle", value: MainTab.profile) {
                NavigationStack(path: $router.profilePath) {
                    ProfileOverviewView(
                        viewModel: editProfileViewModel,
                        onEdit: router.openEditProfile,
                        onOpenSettings: router.openSettings,
                        onSignOut: signOut
                    )
                        .navigationDestination(for: ProfileRoute.self) { route in
                            profileDestination(for: route)
                        }
                }
            }
        }
        .tint(AppTheme.Colors.accentText)
        .task { await matchesStore.run() }
        .task { await editProfileViewModel.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await matchesStore.reload() }
            }
        }
        .onChange(of: matchesStore.matches.map(\.id)) { _, matchIDs in
            guard matchesStore.isLoaded else { return }
            let ids = Set(matchIDs)
            chatCache.retain(matchIDs: ids)
            partnerProfileCache.retain(matchIDs: ids)
            router.closeMissingChat(matchIDs: ids)
        }
        .fullScreenCover(item: celebrationBinding) { match in
            CelebrationPresenter { makeCelebrationViewModel(for: match) }
                .id(match.id)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $isFilterPresented) {
            DiscoveryFilterView(
                viewModel: makeDiscoveryFilterViewModel(),
                onClose: { isFilterPresented = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(AppTheme.Radius.card)
            .presentationBackground(AppTheme.Colors.filterBackground)
        }
    }
    
    // MARK: - Окно «Это матч»

    /// Экран для маршрута вкладки профиля.
    /// - Parameter route: выбранный маршрут.
    @ViewBuilder
    private func profileDestination(for route: ProfileRoute) -> some View {
        switch route {
        case .editProfile:
            EditProfileView(viewModel: editProfileViewModel)
        case .settings:
            SettingsPresenter { makeSettingsViewModel() }
        case .deleteAccount:
            DeleteAccountPresenter { container.makeDeleteAccountViewModel() }
        }
    }

    /// Собирает фильтры из самой свежей версии профиля.
    private func makeDiscoveryFilterViewModel() -> DiscoveryFilterViewModel {
        container.makeDiscoveryFilterViewModel(profile: currentProfile.profile) { updated in
            currentProfile.profile = updated
            onProfileUpdated(updated)
            isFilterPresented = false

            Task {
                await editProfileViewModel.sync(profile: updated)
                await feedViewModel.reload()
            }
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
    /// - Returns: модель быстрой отправки сообщения и закрытия окна.
    private func makeCelebrationViewModel(for match: MatchSummary) -> MatchCelebrationViewModel {
        let router = router
        let store = matchesStore
        
        return container.makeMatchCelebrationViewModel(
            match: match,
            myPhotoPath: currentProfile.profile.photoPaths.first,
            onSent: {
                router.openChat(match.id)
                store.dismissCelebration(id: match.id)
            },
            onDismiss: {
                store.dismissCelebration(id: match.id)
            }
        )
    }
    
    /// Экран маршрута внутри вкладки матчей.
    @ViewBuilder
    private func matchesDestination(for route: MatchesRoute) -> some View {
        if let match = matchesStore.matches.first(where: { $0.id == route.matchID }) {
            switch route {
            case .chat:
                ChatPresenter(viewModel: cachedChatViewModel(for: match))
                    .id(match.id)
            }
        }
    }

    private var partnerProfilePresentation: Binding<Bool> {
        Binding(
            get: { router.presentedPartnerMatchID != nil },
            set: { if !$0 { router.presentedPartnerMatchID = nil } }
        )
    }

    @ViewBuilder
    private var partnerProfileCover: some View {
        if let matchID = router.presentedPartnerMatchID,
           let match = matchesStore.matches.first(where: { $0.id == matchID }) {
            PartnerProfileView(viewModel: cachedPartnerProfileViewModel(for: match))
            .id(match.partner.id)
        }
    }

    private func cachedChatViewModel(for match: MatchSummary) -> ChatViewModel {
        let model = chatCache.model(for: match.id) { makeChatViewModel(for: match) }
        let partnerProfile = cachedPartnerProfileViewModel(for: match)
        Task { await partnerProfile.load() }
        return model
    }
    
    /// Собирает модель чата.
    /// - Parameter match: матч диалога.
    private func makeChatViewModel(for match: MatchSummary) -> ChatViewModel {
        let store = matchesStore
        return container.makeChatViewModel(
            matchID: match.id,
            partner: match.partner,
            currentUserID: currentProfile.profile.id,
            onRead: { Task { await store.reload() } },
            onBlocked: {
                chatCache.remove(match.id)
                partnerProfileCache.remove(match.id)
                router.presentedPartnerMatchID = nil
                router.matchesPath = []
                Task { await store.reload() }
            },
            onOpenPartnerProfile: {
                let partnerProfile = cachedPartnerProfileViewModel(for: match)
                Task {
                    await partnerProfile.load()
                    router.openPartnerProfile(match.id)
                }
            }
        )
    }

    private func makePartnerProfileViewModel(for match: MatchSummary) -> PartnerProfileViewModel {
        container.makePartnerProfileViewModel(
            partnerID: match.partner.id,
            fallbackName: match.partner.name,
            onBlocked: {
                chatCache.remove(match.id)
                partnerProfileCache.remove(match.id)
                router.presentedPartnerMatchID = nil
                router.matchesPath = []
                Task { await matchesStore.reload() }
            }
        )
    }

    private func cachedPartnerProfileViewModel(for match: MatchSummary) -> PartnerProfileViewModel {
        partnerProfileCache.model(for: match.id) {
            makePartnerProfileViewModel(for: match)
        }
    }

    private func signOut() {
        chatCache.removeAll()
        partnerProfileCache.removeAll()
        PhotoImagePipeline.shared.removeAll()
        onSignOut()
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
    let viewModel: ChatViewModel
    
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
