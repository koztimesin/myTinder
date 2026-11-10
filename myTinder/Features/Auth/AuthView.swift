import SwiftUI

/// Авторизация в фирменной тёмной теме с отдельным состоянием подтверждения email.
struct AuthView<ViewModel: AuthViewModelProtocol>: View {

    @State private var viewModel: ViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case password
        case passwordConfirmation
    }

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Group {
            if viewModel.isAwaitingEmailConfirmation {
                confirmationView
            } else {
                formView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.22), value: viewModel.isAwaitingEmailConfirmation)
    }

    private var formView: some View {
        @Bindable var vm = viewModel

        return ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                wordmark

                VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                    Text(vm.modeState == .signIn ? "С возвращением" : "Создайте аккаунт")
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Text(vm.modeState == .signIn
                         ? "Войдите, чтобы продолжить знакомства."
                         : "Заполнить профиль можно будет сразу после регистрации.")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .accessibilityElement(children: .combine)

                VStack(spacing: AppTheme.Spacing.m) {
                    AppTextFieldView(
                        viewModel: .init(
                            title: "Email",
                            placeholder: "name@example.com",
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress
                        ),
                        text: $vm.emailText
                    )
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                    AppTextFieldView(
                        viewModel: .init(
                            title: "Пароль",
                            placeholder: vm.modeState == .signUp ? "Минимум 8 символов" : "Введите пароль",
                            isSecure: true,
                            textContentType: vm.modeState == .signUp ? .newPassword : .password
                        ),
                        text: $vm.passwordText
                    )
                    .focused($focusedField, equals: .password)
                    .submitLabel(vm.modeState == .signUp ? .next : .go)
                    .onSubmit {
                        if vm.modeState == .signUp {
                            focusedField = .passwordConfirmation
                        } else {
                            submitIfPossible()
                        }
                    }

                    if vm.modeState == .signUp {
                        AppTextFieldView(
                            viewModel: .init(
                                title: "Подтвердите пароль",
                                placeholder: "Повторите пароль",
                                errorMessage: vm.passwordConfirmationError,
                                isSecure: true,
                                textContentType: .newPassword
                            ),
                            text: $vm.passwordConfirmationText
                        )
                        .focused($focusedField, equals: .passwordConfirmation)
                        .submitLabel(.go)
                        .onSubmit { submitIfPossible() }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if let error = vm.errorMessageText {
                        ErrorBannerView(viewModel: .init(message: error))
                    }

                    Button {
                        focusedField = nil
                        Task { await vm.submit() }
                    } label: {
                        if vm.isLoadingState {
                            ProgressView().tint(AppTheme.Colors.onAccent)
                        } else {
                            Text(vm.modeState == .signIn ? "Войти" : "Создать аккаунт")
                        }
                    }
                    .buttonStyle(.app(.primary))
                    .disabled(!vm.canSubmit)

                    Button(action: vm.switchMode) {
                        Text(vm.modeState == .signIn
                             ? "Нет аккаунта? Зарегистрироваться"
                             : "Уже есть аккаунт? Войти")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.app(.text))
                    .disabled(vm.isLoadingState)
                }
                .animation(.easeInOut(duration: 0.2), value: vm.modeState)
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, AppTheme.Spacing.l)
            .padding(.vertical, AppTheme.Spacing.xl)
            .frame(maxWidth: .infinity, minHeight: 680)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var wordmark: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            Image(systemName: "heart.fill")
                .foregroundStyle(AppTheme.Colors.accent)
                .accessibilityHidden(true)

            Text("myTinder")
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .font(.system(size: 38, weight: .heavy, design: .rounded))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var confirmationView: some View {
        VStack(spacing: AppTheme.Spacing.l) {
            Spacer()

            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(AppTheme.Colors.accent)
                .accessibilityHidden(true)

            VStack(spacing: AppTheme.Spacing.s) {
                Text("Проверьте почту")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("Мы отправили письмо на \(viewModel.emailText). Подтвердите адрес, затем вернитесь и войдите.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)

            Button("Перейти ко входу", action: viewModel.showSignIn)
                .buttonStyle(.app(.primary))

            Spacer()
        }
        .padding(AppTheme.Spacing.l)
        .frame(maxWidth: 520)
    }

    private func submitIfPossible() {
        guard viewModel.canSubmit else { return }
        focusedField = nil
        Task { await viewModel.submit() }
    }
}

#if DEBUG
@MainActor
@Observable
private final class AuthPreviewViewModel: AuthViewModelProtocol {
    var modeState: AuthViewModel.Mode = .signIn
    var emailText = ""
    var passwordText = ""
    var passwordConfirmationText = ""
    var isLoadingState = false
    var errorMessageText: String?
    var isAwaitingEmailConfirmation = false
    var passwordConfirmationError: String? {
        guard modeState == .signUp,
              !passwordConfirmationText.isEmpty,
              passwordConfirmationText != passwordText
        else { return nil }
        return "Пароли не совпадают."
    }

    var canSubmit: Bool {
        emailText.contains("@")
            && passwordText.count >= (modeState == .signUp ? 8 : 6)
            && (modeState == .signIn || passwordConfirmationText == passwordText)
    }

    func switchMode() {
        modeState = modeState == .signIn ? .signUp : .signIn
        passwordText = ""
        passwordConfirmationText = ""
        errorMessageText = nil
    }

    func showSignIn() {
        modeState = .signIn
        passwordText = ""
        passwordConfirmationText = ""
        isAwaitingEmailConfirmation = false
    }

    func submit() async {}
}

#Preview("Вход") {
    AuthView(viewModel: AuthPreviewViewModel())
}

#Preview("Подтверждение email") {
    let model = AuthPreviewViewModel()
    model.emailText = "name@example.com"
    model.isAwaitingEmailConfirmation = true
    return AuthView(viewModel: model)
}
#endif
