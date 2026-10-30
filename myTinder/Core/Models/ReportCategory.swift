//
//  ReportCategory.swift
//  myTinder
//
//  Created by Ismail on 31.10.2026.
//

import Foundation

/// Причина жалобы. Значения `rawValue` совпадают с `check` в колонке `reports.category`.
enum ReportCategory: String, CaseIterable, Identifiable, Sendable {
    /// Фейковый профиль.
    case fake
    /// Неприемлемые фото.
    case inappropriatePhotos = "inappropriate_photos"
    /// Оскорбления или домогательства.
    case harassment
    /// Спам или мошенничество.
    case spam
    /// Несовершеннолетний.
    case underage
    /// Другое.
    case other
    
    var id: String { rawValue }
    
    /// Название причины для списка.
    var title: String {
        switch self {
        case .fake: "Фейковый профиль"
        case .inappropriatePhotos: "Неприемлемые фото"
        case .harassment: "Оскорбления или домогательства"
        case .spam: "Спам или мошенничество"
        case .underage: "Несовершеннолетний"
        case .other: "Другое"
        }
    }
}
