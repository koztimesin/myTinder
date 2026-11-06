//
//  ProfileFormComponents.swift
//  myTinder
//
//  Created by Codex on 07.11.2026.
//

import SwiftUI

/// Тематизированная секция формы профиля с заголовком и карточкой содержимого.
struct ProfileFormSection<Content: View>: View {

    /// Заголовок секции.
    let title: String
    /// Необязательное пояснение под заголовком.
    let subtitle: String?
    /// Содержимое карточки.
    private let content: Content

    /// Создаёт секцию формы.
    /// - Parameters:
    ///   - title: заголовок.
    ///   - subtitle: необязательное пояснение.
    ///   - content: элементы формы.
    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            content
                .padding(AppTheme.Spacing.m)
                .background(AppTheme.Colors.surface, in: cardShape)
                .overlay(cardShape.stroke(AppTheme.Colors.separator, lineWidth: 1))
        }
    }

    /// Форма карточки секции.
    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
    }
}

/// Многострочное поле «О себе» со счётчиком и явным состоянием ошибки.
struct ProfileBioEditor: View {

    /// Текст, которым владеет ViewModel экрана.
    @Binding var text: String
    /// Превышен ли лимит.
    let isTooLong: Bool
    /// Максимальное число символов.
    let limit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            TextField("Расскажите о себе", text: $text, axis: .vertical)
                .lineLimit(4...8)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .textInputAutocapitalization(.sentences)
                .padding(AppTheme.Spacing.m)
                .background(AppTheme.Colors.surfaceMuted, in: fieldShape)
                .overlay(fieldShape.stroke(borderColor, lineWidth: isTooLong ? 2 : 1))
                .accessibilityHint(isTooLong ? "Превышен лимит в \(limit) символов" : "")

            Text("\(text.count) / \(limit)")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(isTooLong ? AppTheme.Colors.danger : AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }

    /// Форма поля ввода.
    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppTheme.Radius.small, style: .continuous)
    }

    /// Цвет рамки поля.
    private var borderColor: Color {
        isTooLong ? AppTheme.Colors.danger : AppTheme.Colors.separator
    }
}

/// Строка неизменяемого поля профиля.
struct ProfileReadOnlyRow: View {

    /// Название поля.
    let title: String
    /// Текущее значение.
    let value: String

    var body: some View {
        LabeledContent {
            Text(value)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
        } label: {
            Text(title)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }
}
