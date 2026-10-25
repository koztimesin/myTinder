//
//  PhotoTileViewModel.swift
//  myTinder
//
//  Created by Ismail on 25.10.2026.
//

import SwiftUI

/// Откуда берётся картинка плитки.
enum PhotoSource {
    /// Фото, выбранное на устройстве и ещё не загруженное.
    case local(UIImage)
    /// Фото на сервере; `nil`, если ссылка пока не получена.
    case remote(URL?)
}

/// Модель плитки фото: данные для показа и действия по нажатиям.
/// Структура без протоколов: плитку собирает модель экрана и отдаёт готовой.
struct PhotoTileViewModel: Identifiable {
    
    /// Стабильный идентификатор для `ForEach` (путь файла или id локального фото).
    let id: String
    /// Номер фото в списке с единицы (для подписей VoiceOver).
    let position: Int
    /// Это главное фото.
    let isMain: Bool
    /// Показывать ли кнопку удаления.
    let canRemove: Bool
    /// Откуда брать картинку.
    let source: PhotoSource
    /// Нажатие на крестик.
    let onRemove: @MainActor () -> Void
    /// Нажатие на звёздочку «Сделать главным».
    let onMakeMain: @MainActor () -> Void
}
