//
//  ImageProcessor.swift
//  myTinder
//
//  Created by Ismail on 24.10.2026.
//

import UIKit

/// Готовит фото к загрузке: уменьшает и перекодирует в JPEG.
/// Перерисовка в новый битмап убирает EXIF (в том числе геометки), а ориентацию
/// «зашивает» в пиксели, поэтому снимки с телефона не будут лежать боком.
enum ImageProcessor {
    
    /// Максимальная длина длинной стороны в пикселях.
    nonisolated static let maxSide: CGFloat = 1440
    
    /// Качество JPEG от 0 до 1.
    nonisolated static let quality: CGFloat = 0.8
    
    /// Превращает исходные данные изображения (PNG, JPEG и т.д) в уменьшенный JPEG.
    /// Тяжёлая операция: вызывай не на главном потоке (`nonisolated` для этого).
    /// - Parameter data: исходные данные, полученные из `PhotosPicker`.
    /// - Returns: JPEG-данные или `nil`, если это не изображение.
    nonisolated static func makeJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longSide = max(image.size.width, image.size.height)
        guard longSide > 0 else { return nil }
        
        let scale = min(1, maxSide / longSide)   // маленькие фото не увеличиваем
        let target = CGSize(
            width: (image.size.width * scale).rounded(),
            height: (image.size.height * scale).rounded()
        )
        
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1        // размер в пикселях, а не в points
        format.opaque = true    // JPEG без прозрачности
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
