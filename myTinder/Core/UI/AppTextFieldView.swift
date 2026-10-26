//
//  AppTextFieldView.swift
//  myTinder
//
//  Created by Ismail on 26.10.2026.
//

import SwiftUI

struct AppTextFieldViewModel: Equatable {
    
    /// Подпись над полем.
    let title: String
    /// Подсказка внутри пустого поля.
    let placeholder: String
    /// Текст ошибки. Если он есть, поле подсвечивается и под ним показывается сообщение.
    let errorMessage: String?
    /// Скрывать ли вводимый текст (пароль).
    let isSecure: Bool
    /// Тип клавиатуры.
    let keyboardType: UIKeyboardType
    /// Подсказка системе, что вводится (для автозаполнения), например `.emailAddress`.
    let textContentType: UITextContentType?
    
    /// Создаёт модель поля.
    /// - Parameters:
    ///   - title: подпись над полем.
    ///   - placeholder: подсказка внутри пустого поля.
    ///   - errorMessage: текст ошибки или `nil`.
    ///   - isSecure: скрывать ли вводимый текст.
    ///   - keyboardType: тип клавиатуры.
    ///   - textContentType: тип содержимого для автозаполнения.
    init(
        title: String,
        placeholder: String = "",
        errorMessage: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self.errorMessage = errorMessage
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
    }
}

/// Поле ввода с подписью сверху и сообщением об ошибке снизу.
/// Состояние ошибки отличается не только цветом: толще рамка, есть иконка и текст.
struct AppTextFieldView: View {
    
    /// Модель поля.
    let viewModel: AppTextFieldViewModel
    /// Вводимый текст. Владелец состояния — экран (его ViewModel).
    @Binding var text: String
    
    /// Подпись, поле и (при ошибке) сообщение.
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs + 2) {
            Text(viewModel.title)
                .font(AppTheme.Typography.sectionTitle)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.leading, AppTheme.Spacing.xs)
            
            field
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .keyboardType(viewModel.keyboardType)
                .textContentType(viewModel.textContentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, AppTheme.Spacing.m)
                .frame(minHeight: AppTheme.Size.fieldHeight)
                .background(AppTheme.Colors.surface, in: shape)
                .overlay(shape.stroke(borderColor, lineWidth: hasError ? 2 : 1.5))
                .accessibilityLabel(Text(viewModel.title))
                .accessibilityHint(Text(viewModel.errorMessage ?? ""))
            
            if let errorMessage = viewModel.errorMessage {
                ErrorBannerView(viewModel: ErrorBannerViewModel(message: errorMessage))
            }
        }
    }
    
    /// Обычное или защищённое поле в зависимости от модели.
    @ViewBuilder
    private var field: some View {
        if viewModel.isSecure {
            SecureField(viewModel.placeholder, text: $text)
        } else {
            TextField(viewModel.placeholder, text: $text)
        }
    }
    
    /// Есть ли ошибка у поля.
    private var hasError: Bool {
        viewModel.errorMessage != nil
    }
    
    /// Форма поля.
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppTheme.Radius.small, style: .continuous)
    }
    
    /// Цвет рамки: красный при ошибке, иначе обычный.
    private var borderColor: Color {
        hasError ? AppTheme.Colors.danger : AppTheme.Colors.border
    }
}

#Preview("Поля ввода") {
    @Previewable @State var email = "name@mail.com"
    @Previewable @State var password = "1234"
    
    VStack(spacing: AppTheme.Spacing.m) {
        AppTextFieldView(
            viewModel: AppTextFieldViewModel(
                title: "Email",
                placeholder: "name@mail.com",
                keyboardType: .emailAddress,
                textContentType: .emailAddress
            ),
            text: $email
        )
        AppTextFieldView(
            viewModel: AppTextFieldViewModel(
                title: "Пароль",
                errorMessage: "Минимум 8 символов",
                isSecure: true,
                textContentType: .password
            ),
            text: $password
        )
    }
    .padding(AppTheme.Spacing.m)
    .background(AppTheme.Colors.background)
}
