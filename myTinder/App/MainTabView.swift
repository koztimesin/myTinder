//
//  MainTabView.swift
//  myTinder
//
//  Created by Ismail on 27.10.2026.
//

import SwiftUI

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
    }
    
    var body: some View {
        TabView {
            Tab("Лента", systemImage: "rectangle.stack") {
                FeedView(viewModel: feedViewModel)
            }
            
            Tab("Профиль", systemImage: "person.crop.circle") {
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
    }
}
