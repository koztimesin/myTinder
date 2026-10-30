//
//  MessageBubbleViewModel.swift
//  myTinder
//
//  Created by Ismail on 29.10.2026.
//

import Foundation

/// Модель пузыря сообщения.
struct MessageBubbleViewModel: Identifiable {
    /// Идентификатор сообщения.
    let id: UUID
    /// Текст.
    let text: String
    /// Время отправки.
    let timeText: String
    /// Своё ли сообщение.
    let isFromMe: Bool
    /// Статус доставки.
    let delivery: MessageDelivery
    /// Имя собеседника (для озвучки VoiceOver).
    let senderName: String
    /// Повтор отправки.
    let onRetry: @MainActor () -> Void
    /// Удаление не доставленного сообщения.
    let onDiscard: @MainActor () -> Void
}

/// Модель разделителя дня.
struct DaySeparatorViewModel {
    /// Идентификатор строки.
    let id: String
    /// Подпись: «Сегодня», «Вчера» или дата.
    let title: String
}
