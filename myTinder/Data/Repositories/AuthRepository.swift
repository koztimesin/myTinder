//
//  AuthRepository.swift
//  myTinder
//
//  Created by Ismail on 16.10.2026.
//

import Foundation
import Supabase

enum SignUpResult {
    
    case signedIn
    case needsEmailConfirmation
}

protocol AuthRepositoryProtocol: Sendable {
    
    func userStream() -> AsyncStream<AppUser?>
    func signUp(email: String, password: String) async throws -> SignUpResult
    func signIn(email: String, password: String) async throws
    func signOut() async throws
}

final class AuthRepository {
    
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
}

extension AuthRepository: AuthRepositoryProtocol {
    
    func userStream() -> AsyncStream<AppUser?> {
        
        AsyncStream { continuation in
            let task = Task {
                for await (_, session) in client.auth.authStateChanges {
                    if let session, !session.isExpired {
                        continuation.yield(AppUser(id: session.user.id, email: session.user.email))
                    } else {
                        continuation.yield(nil)
                    }
                }
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    func signUp(email: String, password: String) async throws -> SignUpResult {
        let response = try await client.auth.signUp(email: email, password: password)
        
        return response.session == nil ? .needsEmailConfirmation : .signedIn
    }
    
    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
}
