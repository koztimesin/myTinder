//
//  ProfileGateView.swift
//  myTinder
//
//  Created by Ismail on 23.10.2026.
//

import SwiftUI

struct ProfileGateView: View {
    
    let session: SessionStore
    let container: AppContainer
    @State private var store: ProfileStore
    
    init(session: SessionStore, container: AppContainer) {
        self.session = session
        _store = State(initialValue: ProfileStore(profiles: container.profileRepository))
        self.container = container
    }
    
    var body: some View {
        Group {
            switch store.state {
                
            case .checking:
                ProgressView()
                
            case .needsProfile:
                OnboardingView(
                    viewModel: container.makeOnboardingViewModel(
                        onCreated: { store.didCreate($0) },
                        onSignOut: { Task { await session.signOut() } }
                    )
                )
                
            case .ready(let profile):
                EditProfileView(
                    viewModel: container.makeEditProfileViewModel(
                        profile: profile,
                        onUpdated: { store.didUpdate($0) },
                        onSignOut: { Task { await session.signOut() } }
                    )
                )
                
            case .failed(let message):
                VStack(spacing: 16) {
                    
                    Text(message)
                    
                    Button("Повторить") {
                        Task {
                            await store.load()
                        }
                    }
                    
                    Button("Выйти", role: .destructive) {
                        Task {
                            await session.signOut()
                        }
                    }
                }
            }
        }
        .task {
            await store.load()
        }
    }
}
