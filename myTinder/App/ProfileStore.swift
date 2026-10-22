//
//  ProfileStore.swift
//  myTinder
//
//  Created by Ismail on 22.10.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class ProfileStore {
    
    enum State {
        case checking
        case needsProfile
        case ready(Profile)
        case failed(String)
    }
    
    private(set) var state: State = .checking
    
    private let profiles: ProfileRepositoryProtocol
    
    init(profiles: ProfileRepositoryProtocol) {
        self.profiles = profiles
    }
    
    func load() async {
        state = .checking
        
        do {
            let profile = try await profiles.fetchMyProfile()
            
            state = profile.map { .ready($0) } ?? .needsProfile
        } catch {
            guard !Task.isCancelled else { return }
            
            state = .failed("Не удалось загрузить профиль. Проверьте соединение.")
        }
    }
    
    func didCreate(_ profile: Profile) {
        state = .ready(profile)
    }
    
    func didUpdate(_ profile: Profile) {
        state = .ready(profile)
    }
}
