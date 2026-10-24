//
//  LocalPhoto.swift
//  myTinder
//
//  Created by Ismail on 24.10.2026.
//

import UIKit

/// Фото, выбранное в онбординге, но ещё не загруженное на сервер.
/// Хранит готовый JPEG для загрузки и превью, чтобы не декодировать картинку на каждую перерисовку.
struct LocalPhoto: Identifiable, Equatable {
    
    let id = UUID()
    
    /// Уменьшенный JPEG, который уйдёт в Storage.
    let jpegData: Data
    
    /// Картинка для показа в сетке.
    let preview: UIImage
    
    /// - Returns: `nil`, если данные не удалось декодировать.
    init?(jpegData: Data) {
        guard let preview = UIImage(data: jpegData) else { return nil }
        
        self.jpegData = jpegData
        self.preview = preview
    }
    
    static func == (lhs: LocalPhoto, rhs: LocalPhoto) -> Bool {
        lhs.id == rhs.id
    }
}
