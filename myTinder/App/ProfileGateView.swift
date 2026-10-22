//
//  ProfileGateView.swift
//  myTinder
//
//  Created by Ismail on 23.10.2026.
//

import SwiftUI

struct ProfileGateView: View {
    
    let session: SessionStore
    @State private var store: ProfileStore
    
    init(session: SessionStore, container: AppContainer) {
        self.session = session
        _store = State(initialValue: ProfileStore(profiles: container.profileRepository))
    }
    
    var body: some View {
        Group {
            switch store.state {
                
            case .checking:
                ProgressView()
                
            case .needsProfile:
                Text("Онбординг")
                
            case .ready(let profile):
                VStack(spacing: 16) {
                    
                    Text("Привет, \(profile.name)")
                    
                    Button("Выйти") {
                        Task {
                            await session.signOut()
                        }
                    }
                }
                
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
