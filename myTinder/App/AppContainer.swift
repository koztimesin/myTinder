//
//  AppContainer.swift
//  myTinder
//
//  Created by Ismail on 16.10.2026.
//

import Supabase
import Foundation

@MainActor
final class AppContainer {
    
    private let client = SupabaseClient(supabaseURL: AppConfig.supabaseURL, supabaseKey: AppConfig.supabaseKey)
    
    let authRepository: AuthRepositoryProtocol
    let profileRepository: ProfileRepositoryProtocol
    private let photoRepository: PhotoRepositoryProtocol
    private let photoURLProvider: PhotoURLProviderProtocol
    private let feedRepository: FeedRepositoryProtocol
    private let matchRepository: MatchRepositoryProtocol
    private let chatRepository: ChatRepositoryProtocol
    private let moderationRepository: ModerationRepositoryProtocol
    private let accountRepository: AccountRepositoryProtocol
    
    
    init() {
        authRepository = AuthRepository(client: client)
        profileRepository = ProfileRepository(client: client)
        photoRepository = PhotoRepository(client: client)
        photoURLProvider = PhotoURLCache(repository: photoRepository)
        feedRepository = FeedRepository(client: client)
        matchRepository = MatchRepository(client: client)
        chatRepository = ChatRepository(client: client)
        moderationRepository = ModerationRepository(client: client)
        accountRepository = AccountRepository(client: client)
    }
    
    @MainActor
    func makeOnboardingViewModel(
        onCreated: @escaping @MainActor (Profile) -> Void,
        onSignOut: @escaping @MainActor () -> Void
    ) -> OnboardingViewModel {
        OnboardingViewModel(
            profiles: profileRepository,
            photoRepository: photoRepository,
            onCreated: onCreated,
            onSignOut: onSignOut
        )
    }
    
    /// Собирает модель экрана «Мой профиль».
    /// - Parameters:
    ///   - profile: текущий профиль.
    ///   - onUpdated: что делать после успешного изменения профиля.
    @MainActor
    func makeEditProfileViewModel(
        profile: Profile,
        onUpdated: @escaping @MainActor (Profile) -> Void
    ) -> EditProfileViewModel {
        EditProfileViewModel(
            profile: profile,
            profiles: profileRepository,
            photoRepository: photoRepository,
            urlProvider: photoURLProvider,
            onUpdated: onUpdated
        )
    }
    
    /// Собирает отдельную модель фильтров выдачи.
    func makeDiscoveryFilterViewModel(
        profile: Profile,
        onApplied: @escaping @MainActor (Profile) -> Void
    ) -> DiscoveryFilterViewModel {
        DiscoveryFilterViewModel(
            profile: profile,
            profiles: profileRepository,
            onApplied: onApplied
        )
    }
    
    /// Собирает модель общих настроек приложения.
    /// - Parameter onOpenDeleteAccount: открывает экран удаления аккаунта.
    /// - Returns: модель экрана настроек.
    func makeSettingsViewModel(onOpenDeleteAccount: @escaping @MainActor () -> Void) -> SettingsViewModel {
        SettingsViewModel(onOpenDeleteAccount: onOpenDeleteAccount)
    }
    
    /// Собирает модель окончательного удаления аккаунта.
    func makeDeleteAccountViewModel() -> DeleteAccountViewModel {
        DeleteAccountViewModel(repository: accountRepository)
    }
    
    /// Собирает модель экрана ленты.
    func makeFeedViewModel() -> FeedViewModel {
        let useCase = FeedUseCase(repository: feedRepository)
        
        return FeedViewModel(
            useCase: useCase,
            photoURLProvider: photoURLProvider,
            moderation: moderationRepository,
            makeReportViewModel: { userID, name, onFinished in
                self.makeReportViewModel(partnerID: userID, partnerName: name, onFinished: onFinished)
            }
        )
    }
    
    /// Собирает общее хранилище матчей.
    func makeMatchesStore() -> MatchesStore {
        MatchesStore(repository: matchRepository)
    }
    
    /// Собирает модель экрана «Матчи».
    /// - Parameters:
    ///   - store: общее хранилище матчей.
    ///   - onOpenFeed: переход на вкладку «Лента».
    ///   - onSelectMatch: открытие диалога.
    func makeMatchesViewModel(
        store: MatchesStore,
        onOpenFeed: @escaping @MainActor () -> Void,
        onSelectMatch: @escaping @MainActor (UUID) -> Void
    ) -> MatchesViewModel {
        MatchesViewModel(
            store: store,
            photoURLProvider: photoURLProvider,
            onOpenFeed: onOpenFeed,
            onSelectMatch: onSelectMatch
        )
    }
    
    /// Собирает модель окна «Это матч».
    /// - Parameters:
    ///   - match: новый матч.
    ///   - myPhotoPath: путь главного фото текущего пользователя.
    ///   - onSent: открыть чат после успешной отправки.
    ///   - onDismiss: закрыть окно без отправки сообщения.
    func makeMatchCelebrationViewModel(
        match: MatchSummary,
        myPhotoPath: String?,
        onSent: @escaping @MainActor () -> Void,
        onDismiss: @escaping @MainActor () -> Void
    ) -> MatchCelebrationViewModel {
        MatchCelebrationViewModel(
            match: match,
            myPhotoPath: myPhotoPath,
            photoURLProvider: photoURLProvider,
            chatRepository: chatRepository,
            onSent: onSent,
            onDismiss: onDismiss
        )
    }
    
    /// Собирает модель экрана чата.
    /// - Parameters:
    ///   - matchID: матч диалога.
    ///   - partner: собеседник.
    ///   - currentUserID: id текущего пользователя.
    ///   - onRead: что делать, когда диалог отмечен прочитанным.
    func makeChatViewModel(
        matchID: UUID,
        partner: MatchPartner,
        currentUserID: UUID,
        onRead: @escaping @MainActor () -> Void,
        onBlocked: @escaping @MainActor () -> Void
    ) -> ChatViewModel {
        ChatViewModel(
            matchID: matchID,
            partner: partner,
            currentUserID: currentUserID,
            repository: chatRepository,
            photoURLProvider: photoURLProvider,
            moderation: moderationRepository,
            makeReportViewModel: { onFinished in
                self.makeReportViewModel(partnerID: partner.id,
                                         partnerName: partner.name,
                                         onFinished: onFinished)
            },
            onBlocked: onBlocked,
            onRead: onRead
        )
    }
    
    /// Собирает модель экрана жалобы.
    func makeReportViewModel(
        partnerID: UUID,
        partnerName: String,
        onFinished: @escaping @MainActor (Bool) -> Void
    ) -> ReportViewModel {
        ReportViewModel(
            userID: partnerID,
            name: partnerName,
            repository: moderationRepository,
            onFinished: onFinished
        )
    }
}
