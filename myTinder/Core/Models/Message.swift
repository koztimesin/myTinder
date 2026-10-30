//
//  Message.swift
//  myTinder
//
//  Created by Ismail on 29.10.2026.
//

import Foundation

/// Сообщение в диалоге.
nonisolated struct Message: Identifiable, Equatable, Sendable {
    /// Идентификатор; клиент задаёт его сам, поэтому повторная отправка не создаёт дубль.
    let id: UUID
    /// Матч, к которому относится сообщение.
    let matchID: UUID
    /// Автор сообщения.
    let senderID: UUID
    /// Текст сообщения.
    let body: String
    /// Время отправки по часам сервера (до подтверждения сервером — по часам телефона).
    let sentAt: Date
}
