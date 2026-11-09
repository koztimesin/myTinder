//
//  AuthRepositoryProtocol.swift
//  myTinder
//
//  Created by Ismail on 09.11.2026.
//

import Foundation

protocol AuthRepositoryProtocol: Sendable {
    
    func userStream() -> AsyncStream<AppUser?>
    func signUp(email: String, password: String) async throws -> SignUpResult
    func signIn(email: String, password: String) async throws
    func signOut() async throws
}
