//
//  ImageProcessor.swift
//  myTinder
//
//  Created by Ismail on 24.10.2026.
//

import ImageIO
import UIKit

/// Готовит фото к загрузке: уменьшает и перекодирует в JPEG.
/// Перерисовка в новый битмап убирает EXIF (в том числе геометки), а ориентацию
/// «зашивает» в пиксели, поэтому снимки с телефона не будут лежать боком.
enum ImageProcessor {
    
    /// Максимальная длина длинной стороны в пикселях.
    nonisolated static let maxSide: CGFloat = 2048
    
    /// Качество JPEG от 0 до 1.
    nonisolated static let quality: CGFloat = 0.9
    
    /// Превращает исходные данные изображения (PNG, JPEG и т.д) в уменьшенный JPEG.
    /// Тяжёлая операция: вызывай не на главном потоке (`nonisolated` для этого).
    /// - Parameter data: исходные данные, полученные из `PhotosPicker`.
    /// - Returns: JPEG-данные или `nil`, если это не изображение.
    nonisolated static func makeJPEG(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxSide),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else { return nil }

        // Новая JPEG-кодировка не переносит EXIF и геометки, но сохраняет
        // реальные пиксельные размеры и корректную ориентацию исходника.
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: quality)
    }
}
