//
//  myTinderApp.swift
//  myTinder
//
//  Created by Ismail on 16.10.2026.
//

import SwiftUI

@main
struct myTinderApp: App {
    
    private let appContainer = AppContainer()
    @State private var session: SessionStore

    init() {
        _session = State(initialValue: SessionStore(authRepository: appContainer.authRepository))
    }

    var body: some Scene {
        WindowGroup {
            RootView(session: session, container: appContainer)
                .task { await session.start() }
        }
    }
}
