//
//  SessionStore.swift
//  myTinder
//
//  Created by Ismail on 16.10.2026.
//

import Observation

@MainActor
@Observable
final class SessionStore {
    
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(AppUser)
    }
    
    private(set) var state: State = .loading
    private let authRepository: AuthRepositoryProtocol
    
    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }
    
    func start() async {
        for await user in authRepository.userStream() {
            state = user.map { .signedIn($0) } ?? .signedOut
        }
    }
    
    func signOut() async {
        try? await authRepository.signOut()
    }
}
