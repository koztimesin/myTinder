//
//  PhotoRepositoryProtocol.swift
//  myTinder
//
//  Created by Ismail on 09.11.2026.
//

import Foundation

protocol PhotoRepositoryProtocol: Sendable {
    
    func upload(_ jpegData: Data) async throws -> String
    func delete(path: String) async throws
    func signedURLs(for paths: [String], expiresIn: Int) async throws -> [String: URL]
}
