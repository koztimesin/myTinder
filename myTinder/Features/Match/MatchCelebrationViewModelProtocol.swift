//
//  MatchCelebrationViewModelProtocol.swift
//  myTinder
//
//  Created by Ismail on 28.10.2026.
//

import Foundation
import Observation

@MainActor
protocol MatchCelebrationViewModelProtocol: AnyObject, Observable {
    /// Заголовок окна.
    var title: String { get }
    /// Поясняющий текст.
    var subtitle: String { get }
    /// Аватар текущего пользователя.
    var myAvatar: MatchAvatarViewModel { get }
    /// Аватар собеседника.
    var partnerAvatar: MatchAvatarViewModel { get }
    /// Получает ссылки на оба фото.
    func loadPhotos() async
    /// Нажали «Написать».
    func write()
    /// Нажали «Продолжить».
    func dismiss()
}
