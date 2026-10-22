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
        
        switch session.state {
            
        case .loading:
            ProgressView()
            
        case .signedOut:
            AuthView(viewModel: AuthViewModel(auth: container.authRepository))
            
        case .signedIn(let user):
            ProfileGateView(session: session, container: container)
                .id(user.id)
        }
    }
}
