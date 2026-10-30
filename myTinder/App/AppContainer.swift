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
    
    private let supabase = SupabaseClient(supabaseURL: AppConfig.supabaseURL, supabaseKey: AppConfig.supabaseKey)
    
    let authRepository: AuthRepositoryProtocol
    lazy var profileRepository: ProfileRepositoryProtocol = SupabaseProfileRepository(client: supabase)
    lazy var photoRepository: PhotoRepositoryProtocol = SupabasePhotoRepository(client: supabase)
    lazy var photoURLProvider: PhotoURLProviderProtocol = PhotoURLCache(repository: photoRepository)
    lazy var feedRepository = SupabaseFeedRepository(client: supabase)
    lazy var matchRepository: MatchRepositoryProtocol = SupabaseMatchRepository(client: supabase)
    lazy var chatRepository: ChatRepositoryProtocol = SupabaseChatRepository(client: supabase)
    lazy var moderationRepository: ModerationRepositoryProtocol = SupabaseModerationRepository(client: supabase)

    
    init() {
        authRepository = AuthRepository(client: supabase)
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
    ///   - onSignOut: что делать при выходе.
    @MainActor
    func makeEditProfileViewModel(
        profile: Profile,
        onUpdated: @escaping @MainActor (Profile) -> Void,
        onSignOut: @escaping @MainActor () -> Void
    ) -> EditProfileViewModel {
        EditProfileViewModel(
            profile: profile,
            profiles: profileRepository,
            photoRepository: photoRepository,
            urlProvider: photoURLProvider,
            onUpdated: onUpdated,
            onSignOut: onSignOut
        )
    }
    
    /// Собирает модель экрана ленты.
    func makeFeedViewModel() -> FeedViewModel {
        
        let useCase = FeedUseCase(repository: feedRepository)
        return FeedViewModel(useCase: useCase, photoURLProvider: photoURLProvider)
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
    ///   - onWrite: что делать по «Написать».
    ///   - onDismiss: что делать по «Продолжить».
    func makeMatchCelebrationViewModel(
        match: MatchSummary,
        myPhotoPath: String?,
        onWrite: @escaping @MainActor () -> Void,
        onDismiss: @escaping @MainActor () -> Void
    ) -> MatchCelebrationViewModel {
        MatchCelebrationViewModel(
            match: match,
            myPhotoPath: myPhotoPath,
            photoURLProvider: photoURLProvider,
            onWrite: onWrite,
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
