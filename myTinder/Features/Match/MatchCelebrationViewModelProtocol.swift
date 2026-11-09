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
    /// Быстрое сообщение собеседнику.
    var draft: String { get set }
    var canSend: Bool { get }
    var isSending: Bool { get }
    var errorMessage: String? { get }
    /// Получает ссылки на оба фото.
    func loadPhotos() async
    /// Отправляет быстрое сообщение и при успехе открывает диалог.
    func send() async
    /// Закрывает окно без сообщения.
    func dismiss()
}
