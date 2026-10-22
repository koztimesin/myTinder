//
//  SupabaseProfileRepository.swift
//  myTinder
//
//  Created by Ismail on 22.10.2026.
//

import Foundation
import Supabase

struct SupabaseProfileRepository {
    
    let client: SupabaseClient
    
    private func currentUserID() async throws -> UUID {
        try await client.auth.session.user.id
    }
    
    private static func map(_ e: PostgrestError) -> Error {
        if e.code == "23505" { return ProfileError.alreadyExists }
        if e.code == "23514" { return ProfileError.underage }
        
        return e
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
