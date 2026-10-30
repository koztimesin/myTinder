//
//  AppTheme.swift
//  myTinder
//
//  Created by Ismail on 26.10.2026.
//

import SwiftUI
import UIKit

enum AppTheme {
    
    enum Colors {
        /// Акцент: кнопка «Нравится», основная кнопка, индикаторы.
        static let accent = Color(light: 0xD9304A, dark: 0xFF6B76)
        /// Цвет контента на акцентном фоне. В тёмной теме тёмный: белый на коралловом не проходит контраст.
        static let onAccent = Color(light: 0xFFFFFF, dark: 0x2B0B12)
        /// Акцентный цвет для текста и иконок на светлом или тёмном фоне (активная вкладка).
        static let accentText = Color(light: 0xB11F37, dark: 0xFF8A93)
        /// Полупрозрачная подложка активной вкладки.
        static let accentTint = Color(light: 0xD9304A, dark: 0xFF6B76).opacity(0.15)
        
        /// Фон экранов.
        static let background = Color(light: 0xFFF8F5, dark: 0x14101A)
        /// Фон карточек, плиток и полей ввода.
        static let surface = Color(light: 0xFFFFFF, dark: 0x1F1A28)
        /// Фон полей только для чтения и неактивных элементов.
        static let surfaceMuted = Color(light: 0xF3EBE8, dark: 0x2A2336)
        
        /// Основной текст.
        static let textPrimary = Color(light: 0x211B1E, dark: 0xF5F0FA)
        /// Вторичный текст: подписи, подсказки.
        static let textSecondary = Color(light: 0x6E6469, dark: 0xB6ABC4)
        
        /// Разделители и рамки карточек.
        static let separator = Color(light: 0xEADFE0, dark: 0x3A3248)
        /// Рамки полей ввода и вторичных кнопок.
        static let border = Color(light: 0xCDBFC2, dark: 0x4A4058)
        
        /// Ошибки и опасные действия (текст, рамки, кнопка удаления).
        static let danger = Color(light: 0xB42323, dark: 0xFF6B6B)
        /// Цвет контента на фоне `danger`.
        static let onDanger = Color(light: 0xFFFFFF, dark: 0x2B0B12)
        /// Фон плашки ошибки.
        static let dangerSurface = Color(light: 0xFBE9E9, dark: 0x3A1B22)
        /// Текст на плашке ошибки.
        static let dangerText = Color(light: 0x8F1A1A, dark: 0xFF9A9A)
        
        /// Успех, например «это матч».
        static let success = Color(light: 0x1F7A52, dark: 0x4CC38A)
        
        /// Рамка стеклянных элементов в версиях до iOS 26 (на iOS 26 рамку рисует система).
        static let glassBorder = Color.white.opacity(0.35)
        
        /// Градиент под текстом на фото в ленте и анкете (сверху прозрачный, снизу тёмный).
        static let photoGradient = LinearGradient(
            colors: [Color.black.opacity(0), Color.black.opacity(0.78)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Шрифты. Системные текстовые стили, поэтому поддерживают Dynamic Type.
    enum Typography {
        /// Заголовок экрана.
        static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .heavy)
        /// Заголовок секции или крупный заголовок карточки.
        static let title = Font.system(.title2, design: .rounded, weight: .bold)
        /// Имя на карточке в ленте и в анкете.
        static let cardTitle = Font.system(.largeTitle, design: .rounded, weight: .heavy)
        /// Обычный текст.
        static let body = Font.system(.body, design: .rounded, weight: .medium)
        /// Текст кнопок.
        static let button = Font.system(.headline, design: .rounded, weight: .heavy)
        /// Подписи и вторичный текст.
        static let caption = Font.system(.footnote, design: .rounded, weight: .semibold)
        /// Подписи секций в верхнем регистре.
        static let sectionTitle = Font.system(.footnote, design: .rounded, weight: .heavy)
    }
    
    enum Spacing {
        
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }
    
    enum Radius {
        
        /// Поля ввода, плашки ошибок.
        static let small: CGFloat = 12
        /// Кнопки, плитки фото, строки списков.
        static let medium: CGFloat = 16
        /// Крупные карточки и шторки.
        static let card: CGFloat = 28
        /// Фото-карточка в ленте.
        static let photoCard: CGFloat = 38
    }
    
    enum Size {
        
        /// Минимальная область нажатия.
        static let minTapTarget: CGFloat = 44
        /// Высота основной и вторичной кнопок.
        static let buttonHeight: CGFloat = 52
        /// Высота текстовой кнопки.
        static let textButtonHeight: CGFloat = 48
        /// Высота поля ввода.
        static let fieldHeight: CGFloat = 52
        /// Диаметр кнопки «Пропустить» в ленте.
        static let dislikeButton: CGFloat = 64
        /// Диаметр кнопки «Нравится» в ленте.
        static let likeButton: CGFloat = 76
    }
}

// MARK: - Динамические цвета
private extension Color {
    
    /// Создаёт динамический цвет из двух HEX-значений: для светлой и тёмной темы.
    /// - Parameters:
    ///   - light: цвет светлой темы в формате `0xRRGGBB`.
    ///   - dark: цвет тёмной темы в формате `0xRRGGBB`.
    nonisolated init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { @Sendable traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    
    /// Создаёт цвет из HEX-значения без прозрачности.
    /// - Parameter hex: значение в формате `0xRRGGBB`.
    nonisolated convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
