//
//  MatchSummary.swift
//  myTinder
//
//  Created by Ismail on 28.10.2026.
//

import Foundation

/// Собеседник по матчу: то, что нужно для списка и окна «Это матч».
struct MatchPartner: Equatable, Sendable {
    /// Идентификатор профиля собеседника.
    let id: UUID
    /// Имя собеседника.
    let name: String
    /// Путь главного фото в Storage (первый элемент `photo_paths`), если фото есть.
    let photoPath: String?
}

/// Последнее сообщение в диалоге.
struct LastMessage: Equatable, Sendable {
    /// Текст сообщения.
    let body: String
    /// Когда сообщение отправлено.
    let sentAt: Date
    /// `true`, если сообщение написал текущий пользователь.
    let isFromMe: Bool
}

/// Матч в списке: собеседник и последнее сообщение.
struct MatchSummary: Identifiable, Equatable, Sendable {
    /// Идентификатор матча.
    let id: UUID
    /// Когда случился матч.
    let matchedAt: Date
    /// Собеседник.
    let partner: MatchPartner
    /// Последнее сообщение; `nil`, пока в диалоге никто ничего не написал.
    let lastMessage: LastMessage?
    /// Сколько сообщений собеседника ещё не прочитано.
    let unreadCount: Int
    /// Новый матч: сообщений ещё нет (такие матчи показываются в ряду «Новые»).
    var isNew: Bool { lastMessage == nil }
}
