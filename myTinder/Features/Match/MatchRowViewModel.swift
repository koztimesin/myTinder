//
//  MatchRowViewModel.swift
//  myTinder
//
//  Created by Ismail on 28.10.2026.
//

import Foundation

struct MatchRowViewModel: Identifiable {
    /// Идентификатор матча.
    let id: UUID
    /// Имя собеседника.
    let name: String
    /// Текст последнего сообщения (со словом «Вы:», если писал текущий пользователь).
    let preview: String
    /// Время последнего сообщения: время, «Вчера» или дата.
    let timeText: String
    /// Аватар без кольца.
    let avatar: MatchAvatarViewModel
    /// Нажатие на строку.
    let onTap: @MainActor () -> Void
}
