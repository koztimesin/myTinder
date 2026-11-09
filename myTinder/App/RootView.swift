//
//  RootView.swift
//  myTinder
//
//  Created by Ismail on 16.10.2026.
//

import SwiftUI

struct RootView: View {
    
    let session: SessionStore
    let container: AppContainer
    
    var body: some View {
        
        Group {
            switch session.state {
            case .loading:
                LoadingIndicatorView(
                    viewModel: LoadingIndicatorViewModel(title: "Проверяем сессию")
                )

            case .signedOut:
                AuthView(viewModel: AuthViewModel(auth: container.authRepository))

            case .signedIn(let user):
                ProfileGateView(session: session, container: container)
                    .id(user.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
        .preferredColorScheme(.dark)
    }
}
