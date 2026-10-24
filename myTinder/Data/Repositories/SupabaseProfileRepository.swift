//
//  SupabaseProfileRepository.swift
//  myTinder
//
//  Created by Ismail on 22.10.2026.
//

import Foundation
import Supabase

/// Коды ошибок PostgreSQL, которые приходят от Supabase в `PostgrestError.code`
enum PostgresErrorCode {
    
    /// Нарушена уникальность (например, профиль с таким `id` уже существует)
    static let uniqueViolation = "23505"
    
    /// Не прошёл проверку (например, возраст меньше 18)
    static let checkViolation = "23514"
}

struct SupabaseProfileRepository {
    
    let client: SupabaseClient
    
    private func currentUserID() async throws -> UUID {
        try await client.auth.session.user.id
    }
    
    private static func map(_ error: PostgrestError) -> Error {
        
        switch error.code {
            
        case PostgresErrorCode.uniqueViolation: ProfileError.alreadyExists
            
        case PostgresErrorCode.checkViolation: error.message.contains("birth_date") ? ProfileError.underage : error
            
        default: error
        }
    }
}

extension SupabaseProfileRepository: ProfileRepositoryProtocol {
    
    func fetchMyProfile() async throws -> Profile? {
        let uid = try await currentUserID()
        let rows: [ProfileDTO] = try await client
            .from("profiles").select()
            .eq("id", value: uid)
            .limit(1)
            .execute().value
        return try rows.first?.toDomain()
    }
    
    func create(_ new: NewProfile) async throws -> Profile {
        let uid = try await currentUserID()
        
        let dto = ProfileInsertDTO(
            id: uid,
            name: new.name,
            birthDate: DateOnly.formatter.string(from: new.birthDate),
            bio: new.bio,
            gender: new.gender.rawValue,
            interestedIn: new.interestedIn.map(\.rawValue),
            photoPaths: new.photoPaths
        )
        
        do {
            let row: ProfileDTO = try await client
                .from("profiles").insert(dto).select().single().execute().value
            
            return try row.toDomain()
        } catch let error as PostgrestError {
            throw Self.map(error)
        }
    }
    
    func update(_ changes: ProfileChanges) async throws -> Profile {
        let uid = try await currentUserID()
        
        let dto = ProfileUpdateDTO(
            name: changes.name, bio: changes.bio,
            gender: changes.gender.rawValue,
            interestedIn: changes.interestedIn.map(\.rawValue),
            photoPaths: changes.photoPaths
        )
        
        let row: ProfileDTO = try await client
            .from("profiles").update(dto).eq("id", value: uid)
            .select().single().execute().value
        
        return try row.toDomain()
    }
}
