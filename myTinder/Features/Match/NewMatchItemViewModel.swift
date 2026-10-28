//
//  NewMatchItemViewModel.swift
//  myTinder
//
//  Created by Ismail on 28.10.2026.
//

import Foundation

struct NewMatchItemViewModel: Identifiable {
    /// Идентификатор матча.
    let id: UUID
    /// Имя собеседника.
    let name: String
    /// Аватар с кольцом.
    let avatar: MatchAvatarViewModel
    /// Нажатие на элемент.
    let onTap: @MainActor () -> Void
}
