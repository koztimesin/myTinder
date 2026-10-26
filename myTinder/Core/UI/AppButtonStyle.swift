//
//  AppButtonStyle.swift
//  myTinder
//
//  Created by Ismail on 26.10.2026.
//

import SwiftUI

struct AppButtonStyle: ButtonStyle {
    
    enum Kind {
        /// Главное действие экрана: заливка акцентом.
        case primary
        /// Второстепенное действие: рамка без заливки.
        case secondary
        /// Малозаметное действие без рамки и заливки, например «Выйти».
        case text
        /// Необратимое действие, например «Удалить навсегда»: красная заливка.
        case destructive
        /// Опасное, но не финальное действие: красная рамка, например «Удалить аккаунт» в настройках.
        case destructiveOutline
    }
    
    let kind: Kind
    
    /// Собирает внешний вид кнопки.
    /// - Parameter configuration: состояние кнопки и её содержимое.
    /// - Returns: оформленная кнопка.
    func makeBody(configuration: Configuration) -> some View {
        AppButtonBody(kind: kind, configuration: configuration)
    }
}

extension ButtonStyle where Self == AppButtonStyle {
    
    /// Короткая запись стиля: `.buttonStyle(.app(.primary))`.
    /// - Parameter kind: вид кнопки.
    /// - Returns: стиль кнопки приложения.
    static func app(_ kind: AppButtonStyle.Kind) -> AppButtonStyle {
        AppButtonStyle(kind: kind)
    }
}

private struct AppButtonBody: View {
    
    let kind: AppButtonStyle.Kind
    let configuration: ButtonStyleConfiguration
    
    /// Доступна ли кнопка для нажатия.
    @Environment(\.isEnabled) private var isEnabled
    
    var body: some View {
        configuration.label
            .font(AppTheme.Typography.button)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(.horizontal, AppTheme.Spacing.m)
            .background(backgroundColor, in: shape)
            .overlay(shape.stroke(borderColor, lineWidth: borderWidth))
            .contentShape(shape)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
    
    /// Форма кнопки.
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
    }
    
    /// Минимальная высота кнопки (растёт вместе с Dynamic Type).
    private var minHeight: CGFloat {
        kind == .text ? AppTheme.Size.textButtonHeight : AppTheme.Size.buttonHeight
    }
    
    /// Цвет текста и иконок.
    private var foregroundColor: Color {
        switch kind {
        case .primary: AppTheme.Colors.onAccent
        case .secondary: AppTheme.Colors.textPrimary
        case .text: AppTheme.Colors.accentText
        case .destructive: AppTheme.Colors.onDanger
        case .destructiveOutline: AppTheme.Colors.danger
        }
    }
    
    /// Цвет заливки.
    private var backgroundColor: Color {
        switch kind {
        case .primary: AppTheme.Colors.accent
        case .secondary: AppTheme.Colors.surface
        case .text, .destructiveOutline: Color.clear
        case .destructive: AppTheme.Colors.danger
        }
    }
    
    /// Цвет рамки.
    private var borderColor: Color {
        switch kind {
        case .secondary: AppTheme.Colors.border
        case .destructiveOutline: AppTheme.Colors.danger
        case .primary, .text, .destructive: Color.clear
        }
    }
    
    /// Толщина рамки.
    private var borderWidth: CGFloat {
        switch kind {
        case .secondary, .destructiveOutline: 1.5
        case .primary, .text, .destructive: 0
        }
    }
}

#Preview("Кнопки") {
    VStack(spacing: AppTheme.Spacing.s) {
        Button("Основная") {}.buttonStyle(.app(.primary))
        Button("Вторичная") {}.buttonStyle(.app(.secondary))
        Button("Текстовая") {}.buttonStyle(.app(.text))
        Button("Удалить навсегда") {}.buttonStyle(.app(.destructive))
        Button("Удалить аккаунт") {}.buttonStyle(.app(.destructiveOutline))
        Button("Недоступная") {}.buttonStyle(.app(.primary)).disabled(true)
    }
    .padding(AppTheme.Spacing.m)
    .background(AppTheme.Colors.background)
}
