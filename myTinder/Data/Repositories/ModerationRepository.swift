//
//  ModerationRepository.swift
//  myTinder
//
//  Created by Ismail on 31.10.2026.
//

import Foundation
import Supabase

struct ModerationRepository {
    /// Клиент Supabase.
    let client: SupabaseClient
}

extension ModerationRepository: ModerationRepositoryProtocol {
    
    func report(userID: UUID, category: ReportCategory, details: String?) async throws {
        let session = try await client.auth.session
        let dto = ReportDTO(
            reporter: session.user.id,
            reported: userID,
            category: category.rawValue,
            reason: details
        )
        try await client.from("reports").insert(dto).execute()
    }
    
    func block(userID: UUID) async throws {
        try await client
            .rpc("block_user", params: BlockUserParams(target: userID))
            .execute()
    }
}
