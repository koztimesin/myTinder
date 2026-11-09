//
//  ModerationRepositoryProtocol.swift
//  myTinder
//
//  Created by Ismail on 09.11.2026.
//

import Foundation

/// Жалобы и блокировка пользователей.
protocol ModerationRepositoryProtocol: Sendable {
    /// Отправляет жалобу от текущего пользователя.
    /// - Parameters:
    ///   - userID: на кого жалоба.
    ///   - category: причина.
    ///   - details: комментарий; `nil`, если его нет.
    func report(userID: UUID, category: ReportCategory, details: String?) async throws
    
    /// Блокирует пользователя и удаляет матч с ним (одной транзакцией на сервере).
    /// Повторная блокировка того же человека считается успехом.
    /// - Parameter userID: кого блокируем.
    func block(userID: UUID) async throws
}
