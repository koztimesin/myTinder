import PhotosUI
import SwiftUI

/// Пошаговое создание профиля: один понятный вопрос на каждом из шести экранов.
struct OnboardingView<ViewModel: OnboardingViewModelProtocol>: View {

    @State private var viewModel: ViewModel
    @State private var pickerItems: [PhotosPickerItem] = []
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case bio
    }

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 0) {
            progressHeader

            ScrollView {
                stepContent(
                    name: $vm.name,
                    birthDate: $vm.birthDate,
                    gender: $vm.gender,
                    interest: $vm.interest,
                    bio: $vm.bio
                )
                .frame(maxWidth: 520, alignment: .leading)
                .padding(.horizontal, AppTheme.Spacing.l)
                .padding(.top, AppTheme.Spacing.l)
                .padding(.bottom, AppTheme.Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .top)
                .id(vm.currentStep)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { bottomBar }
        .disabled(vm.isSubmitting)
        .animation(.easeInOut(duration: 0.2), value: vm.currentStep)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await vm.addPhotos(from: items)
                pickerItems = []
            }
        }
    }

    private var progressHeader: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            if viewModel.currentStep == .name {
                Button("Выйти", role: .destructive, action: viewModel.signOut)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.danger)
                    .frame(minWidth: AppTheme.Size.minTapTarget, minHeight: AppTheme.Size.minTapTarget)
            } else {
                Button(action: viewModel.goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(.headline, weight: .bold))
                        .frame(width: AppTheme.Size.minTapTarget, height: AppTheme.Size.minTapTarget)
                        .background(AppTheme.Colors.surface, in: Circle())
                }
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .accessibilityLabel("Назад")
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Шаг \(viewModel.currentStep.rawValue) из \(viewModel.totalSteps)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                ProgressView(
                    value: Double(viewModel.currentStep.rawValue),
                    total: Double(viewModel.totalSteps)
                )
                .tint(AppTheme.Colors.accent)
                .accessibilityLabel("Прогресс заполнения профиля")
                .accessibilityValue("Шаг \(viewModel.currentStep.rawValue) из \(viewModel.totalSteps)")
            }
        }
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.vertical, AppTheme.Spacing.s)
        .background(AppTheme.Colors.background)
    }

    @ViewBuilder
    private func stepContent(
        name: Binding<String>,
        birthDate: Binding<Date>,
        gender: Binding<Gender?>,
        interest: Binding<InterestOption?>,
        bio: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
            switch viewModel.currentStep {
            case .name:
                stepHeading("Как вас зовут?", subtitle: "Это имя увидят другие пользователи.")
                TextField("Имя", text: name)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .font(AppTheme.Typography.title)
                    .padding(.horizontal, AppTheme.Spacing.m)
                    .frame(minHeight: 64)
                    .background(AppTheme.Colors.surface, in: fieldShape)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { viewModel.advance() }

            case .birthDate:
                stepHeading("Когда вы родились?", subtitle: "Возраст будет указан в профиле. Дату рождения потом изменить нельзя.")
                DatePicker(
                    "Дата рождения",
                    selection: birthDate,
                    in: ...viewModel.latestBirthDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .tint(AppTheme.Colors.accent)
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.s)
                .background(AppTheme.Colors.surface, in: fieldShape)

            case .gender:
                stepHeading("Ваш пол", subtitle: "Эту информацию нельзя будет изменить после создания профиля.")
                optionList(
                    options: Gender.allCases,
                    selection: gender,
                    title: \Gender.title
                )

            case .interest:
                stepHeading("Кого показывать?", subtitle: "Настройку можно будет изменить позже в фильтрах ленты.")
                optionList(
                    options: InterestOption.allCases,
                    selection: interest,
                    title: \InterestOption.title
                )

            case .photos:
                stepHeading("Добавьте фотографии", subtitle: "Нужно хотя бы одно фото. Первое станет главным, максимум — четыре.")
                ProfilePhotoComposition(
                    tiles: viewModel.tiles,
                    remainingSlots: viewModel.remainingSlots,
                    pickerItems: $pickerItems
                )

                if viewModel.isLoadingPhotos {
                    HStack(spacing: AppTheme.Spacing.s) {
                        ProgressView().tint(AppTheme.Colors.accent)
                        Text("Обрабатываем фотографии…")
                    }
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                }

            case .bio:
                stepHeading("Расскажите о себе", subtitle: "Описание необязательное — его можно добавить или изменить позже.")
                ProfileBioEditor(text: bio, isTooLong: viewModel.isBioTooLong, limit: 500)
                    .focused($focusedField, equals: .bio)
            }

            if let message = viewModel.errorMessage {
                ErrorBannerView(viewModel: .init(message: message))
            }
        }
    }

    private func stepHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text(title)
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    private func optionList<Option: Hashable>(
        options: [Option],
        selection: Binding<Option?>,
        title: KeyPath<Option, String>
    ) -> some View {
        VStack(spacing: AppTheme.Spacing.s) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection.wrappedValue = option
                } label: {
                    HStack {
                        Text(option[keyPath: title])
                        Spacer()
                        Image(systemName: selection.wrappedValue == option ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selection.wrappedValue == option
                                             ? AppTheme.Colors.accent
                                             : AppTheme.Colors.textSecondary)
                    }
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, AppTheme.Spacing.m)
                    .frame(minHeight: 58)
                    .background(AppTheme.Colors.surface, in: fieldShape)
                    .overlay {
                        if selection.wrappedValue == option {
                            fieldShape.stroke(AppTheme.Colors.accent, lineWidth: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection.wrappedValue == option ? .isSelected : [])
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            if viewModel.isSubmitting {
                ProgressView(
                    value: Double(viewModel.uploadedCount),
                    total: Double(max(viewModel.tiles.count, 1))
                ) {
                    Text("Загружаем фото: \(viewModel.uploadedCount) из \(viewModel.tiles.count)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .tint(AppTheme.Colors.accent)
            }

            if viewModel.currentStep == .bio {
                Button {
                    focusedField = nil
                    Task { await viewModel.submit() }
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView().tint(AppTheme.Colors.onAccent)
                    } else {
                        Text("Создать профиль")
                    }
                }
                .buttonStyle(.app(.primary))
                .disabled(!viewModel.canSubmit)

                Button("Пропустить описание") {
                    viewModel.bio = ""
                    focusedField = nil
                    Task { await viewModel.submit() }
                }
                .buttonStyle(.app(.text))
                .disabled(viewModel.isSubmitting)
            } else {
                Button("Продолжить", action: viewModel.advance)
                    .buttonStyle(.app(.primary))
                    .disabled(!viewModel.canAdvance)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.vertical, AppTheme.Spacing.s)
        .background(AppTheme.Colors.background)
    }

    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
    }
}
