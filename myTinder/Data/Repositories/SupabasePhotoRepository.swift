//
//  SupabasePhotoRepository.swift
//  myTinder
//
//  Created by Ismail on 23.10.2026.
//

import Foundation
import Supabase

struct SupabasePhotoRepository {
    
    let client: SupabaseClient
    
    private var bucket: StorageFileApi {
        client.storage.from("photos")
    }
}

extension SupabasePhotoRepository: PhotoRepositoryProtocol {
    
    func upload(_ jpegData: Data) async throws -> String {
        let uid = try await client.auth.session.user.id
        let path = "\(uid.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        
        _ = try await bucket.upload(
            path, data: jpegData,
            options: FileOptions(contentType: "image/jpeg", upsert: false)
        )
        
        return path
    }
    
    func delete(path: String) async throws {
        _ = try await bucket.remove(paths: [path])
    }
    
    func signedURLs(for paths: [String], expiresIn: Int) async throws -> [String: URL] {
        guard !paths.isEmpty else { return [:] }
        
        let results = try await bucket.createSignedURLs(paths: paths, expiresIn: expiresIn)
        
        var urls: [String: URL] = [:]
        
        for result in results {
            switch result {
            case .success(let path, let url):
                urls[path] = url
            case .failure:
                continue
            }
        }
        return urls
    }
}
