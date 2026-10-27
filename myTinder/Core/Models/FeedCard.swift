//
//  FeedCard.swift
//  myTinder
//
//  Created by Ismail on 26.10.2026.
//

import Foundation

/// Анкета в ленте: только то, что нужно для показа карточки.
struct FeedCard: Identifiable, Equatable, Sendable {
    /// Идентификатор профиля, он же `target` при свайпе.
    let id: UUID
    /// Имя.
    let name: String
    /// Возраст в полных годах.
    let age: Int
    /// Описание «о себе», если заполнено.
    let bio: String?
    /// Пути к фото в Storage, главное первое.
    let photoPaths: [String]
}

extension FeedCard {
    
    /// Собирает карточку из профиля.
    /// - Parameters:
    ///   - profile: профиль из `get_feed`.
    ///   - now: момент, на который считается возраст.
    ///   - calendar: календарь для расчёта возраста.
    init(profile: Profile, now: Date = .now, calendar: Calendar = .current) {
        self.init(
            id: profile.id,
            name: profile.name,
            age: calendar.dateComponents([.year], from: profile.birthDate, to: now).year ?? 0,
            bio: profile.bio,
            photoPaths: profile.photoPaths
        )
    }
}
