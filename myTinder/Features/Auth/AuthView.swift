//
//  AuthView.swift
//  myTinder
//
//  Created by Ismail on 16.10.2026.
//

import SwiftUI

/// Экран входа и регистрации пользователя.
struct AuthView<ViewModel: AuthViewModelProtocol>: View {
    
    @State private var viewModel: ViewModel
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.l) {
                header

                VStack(spacing: AppTheme.Spacing.m) {
                    Picker("Режим", selection: $viewModel.modeState) {
                        Text("Вход").tag(AuthViewModel.Mode.signIn)
                        Text("Регистрация").tag(AuthViewModel.Mode.signUp)
                    }
                    .pickerStyle(.segmented)
                    .tint(AppTheme.Colors.accent)

                    AppTextFieldView(
                        viewModel: AppTextFieldViewModel(
                            title: "Email",
                            placeholder: "name@example.com",
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress
                        ),
                        text: $viewModel.emailText
                    )

                    AppTextFieldView(
                        viewModel: AppTextFieldViewModel(
                            title: "Пароль",
                            placeholder: "Минимум 6 символов",
                            isSecure: true,
                            textContentType: viewModel.modeState == .signUp ? .newPassword : .password
                        ),
                        text: $viewModel.passwordText
                    )

                    errorMessageView
                    infoMessageView
                    signInOrCreateButton
                }
                .padding(AppTheme.Spacing.m)
                .background(AppTheme.Colors.surface, in: formShape)
                .overlay(formShape.stroke(AppTheme.Colors.separator, lineWidth: 1))
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.vertical, AppTheme.Spacing.xl)
            .frame(maxWidth: .infinity, minHeight: 600)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.Colors.background)
    }

    /// Название приложения и пояснение к форме.
    private var header: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            Image(systemName: "heart.fill")
                .font(.system(size: 46, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.Colors.accent)
                .accessibilityHidden(true)

            Text("myTinder")
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Знакомства начинаются здесь")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }
    
    /// Основное действие формы; во время запроса показывает индикатор.
    private var signInOrCreateButton: some View {
        Button {
            Task { await viewModel.submit() }
        } label: {
            signInOrCreateButtonLabel
        }
        .buttonStyle(.app(.primary))
        .disabled(!viewModel.canSubmit)
    }
    
    /// Подпись или индикатор основной кнопки.
    private var signInOrCreateButtonLabel: some View {
        Group {
            if viewModel.isLoadingState {
                ProgressView().tint(AppTheme.Colors.onAccent)
            } else {
                Text(viewModel.modeState == .signIn ? "Войти" : "Создать аккаунт")
            }
        }
    }
    
    /// Ошибка последней попытки авторизации.
    @ViewBuilder
    private var errorMessageView: some View {
        if let error = viewModel.errorMessageText {
            ErrorBannerView(viewModel: ErrorBannerViewModel(message: error))
        }
    }
    
    /// Информационное сообщение, например просьба подтвердить почту.
    @ViewBuilder
    private var infoMessageView: some View {
        if let info = viewModel.infoMessageText {
            HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
                Image(systemName: "envelope.badge")
                    .accessibilityHidden(true)

                Text(info)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(AppTheme.Typography.caption)
            .foregroundStyle(AppTheme.Colors.accentText)
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.vertical, AppTheme.Spacing.s + AppTheme.Spacing.xs)
            .background(AppTheme.Colors.accentTint, in: formShape)
            .accessibilityElement(children: .combine)
        }
    }

    /// Форма карточки авторизации и информационной плашки.
    private var formShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
    }
}

#if DEBUG
/// Заглушка авторизации для проверки состояний и обеих цветовых схем.
@MainActor
@Observable
private final class AuthPreviewViewModel: AuthViewModelProtocol {
    var modeState: AuthViewModel.Mode = .signIn
    var emailText = ""
    var passwordText = ""
    var canSubmit: Bool { emailText.contains("@") && passwordText.count >= 6 }
    var isLoadingState = false
    var errorMessageText: String?
    var infoMessageText: String?

    /// Имитирует отправку формы в превью.
    func submit() async {}
}

#Preview("Авторизация — светлая") {
    AuthView(viewModel: AuthPreviewViewModel())
        .preferredColorScheme(.light)
}

#Preview("Авторизация — тёмная") {
    let model = AuthPreviewViewModel()
    model.infoMessageText = "Мы отправили письмо. Подтвердите почту и войдите."
    return AuthView(viewModel: model)
        .preferredColorScheme(.dark)
}

#Preview("Авторизация — ошибка") {
    let model = AuthPreviewViewModel()
    model.errorMessageText = "Не удалось войти. Проверьте email и пароль."
    return AuthView(viewModel: model)
        .preferredColorScheme(.dark)
}
#endif
