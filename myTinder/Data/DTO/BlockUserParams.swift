//
//  BlockUserParams.swift
//  myTinder
//
//  Created by Ismail on 31.10.2026.
//

import Foundation

/// Параметры вызова `block_user`.
struct BlockUserParams: Encodable, Sendable {
    /// Кого блокируем.
    let target: UUID
    
    enum CodingKeys: String, CodingKey {
        case target = "p_target"
    }
}
