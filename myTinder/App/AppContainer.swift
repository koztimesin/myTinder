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
}
