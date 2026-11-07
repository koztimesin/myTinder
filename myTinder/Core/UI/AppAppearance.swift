//
//  AppAppearance.swift
//  myTinder
//
//  Created by Codex on 07.11.2026.
//

import SwiftUI

/// Пользовательский режим оформления приложения.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    /// Ключ сохранённого значения в `UserDefaults`.
    static let storageKey = "appAppearance"

    var id: Self { self }

    /// Название режима в интерфейсе.
    var title: String {
        switch self {
        case .system: "Системная"
        case .light: "Светлая"
        case .dark: "Тёмная"
        }
    }

    /// Цветовая схема SwiftUI; `nil` оставляет выбор системе.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
