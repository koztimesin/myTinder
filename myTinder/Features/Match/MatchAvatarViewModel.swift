//
//  MatchAvatarViewModel.swift
//  myTinder
//
//  Created by Ismail on 28.10.2026.
//

import Foundation

struct MatchAvatarViewModel: Equatable {
    /// Имя (первая буква показывается, пока нет фото).
    let name: String
    /// Ссылка на фото, если уже получена.
    let photoURL: URL?
    /// Диаметр вместе с кольцом.
    let diameter: CGFloat
    /// Рисовать ли кольцо акцента вокруг фото.
    let showsRing: Bool
}
