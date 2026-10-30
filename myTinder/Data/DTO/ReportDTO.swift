//
//  ReportDTO.swift
//  myTinder
//
//  Created by Ismail on 31.10.2026.
//

import Foundation

struct ReportDTO: Encodable, Sendable {
    /// Кто жалуется (текущий пользователь; RLS проверяет совпадение с `auth.uid()`).
    let reporter: UUID
    /// На кого жалоба.
    let reported: UUID
    /// Значение `ReportCategory.rawValue`.
    let category: String
    /// Комментарий; `nil` не попадает в JSON, и в базе остаётся `null`.
    let reason: String?
}
