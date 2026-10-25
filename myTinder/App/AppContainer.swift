//
//  AppContainer.swift
//  myTinder
//
//  Created by Ismail on 16.10.2026.
//

import Supabase

@MainActor
final class AppContainer {
    
    private let supabase = SupabaseClient(supabaseURL: AppConfig.supabaseURL, supabaseKey: AppConfig.supabaseKey)
    
    let authRepository: AuthRepositoryProtocol
    lazy var profileRepository: ProfileRepositoryProtocol = SupabaseProfileRepository(client: supabase)
    lazy var photoRepository: PhotoRepositoryProtocol = SupabasePhotoRepository(client: supabase)
    lazy var photoURLProvider: PhotoURLProviderProtocol = PhotoURLCache(repository: photoRepository)
    
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
}
