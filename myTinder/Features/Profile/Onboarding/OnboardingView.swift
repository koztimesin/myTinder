//
//  OnboardingView.swift
//  myTinder
//
//  Created by Ismail on 24.10.2026.
//

import SwiftUI
import PhotosUI

struct OnboardingView<ViewModel: OnboardingViewModelProtocol>: View {
    
    @State private var viewModel: ViewModel
    @State private var pickerItems: [PhotosPickerItem] = []
    
    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: AppTheme.Spacing.s),
        count: 3
    )
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        // @Bindable даёт привязки ($vm.name) к полям @Observable-модели.
        @Bindable var vm = viewModel
        
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                    introduction
                    photoSection
                    identitySection(name: $vm.name, birthDate: $vm.birthDate, latestDate: vm.latestBirthDate)
                    genderSection(selection: $vm.gender)
                    interestSection(selection: $vm.interest)

                    ProfileFormSection("О себе", subtitle: "Пара фраз поможет найти общие интересы") {
                        ProfileBioEditor(text: $vm.bio, isTooLong: vm.isBioTooLong, limit: 500)
                    }

                    if let message = vm.errorMessage {
                        ErrorBannerView(viewModel: ErrorBannerViewModel(message: message))
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.m)
                .padding(.top, AppTheme.Spacing.s)
                .padding(.bottom, AppTheme.Spacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.Colors.background)
            .navigationTitle("Новый профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Выйти", role: .destructive) { vm.signOut() }
                        .foregroundStyle(AppTheme.Colors.danger)
                        .disabled(vm.isSubmitting)
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            // Пока идёт отправка, форму трогать нельзя.
            .disabled(vm.isSubmitting)
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                
                Task {
                    await vm.addPhotos(from: items)
                    pickerItems = []
                }
            }
        }
    }
    
    // MARK: Части экрана

    /// Кратко объясняет, зачем нужно заполнить профиль.
    private var introduction: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Расскажите о себе")
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Добавьте фотографии и заполните анкету — это займёт пару минут.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// Секция фотографий.
    private var photoSection: some View {
        ProfileFormSection(
            "Фотографии",
            subtitle: "До \(ProfileValidation.maxPhotos) фото. Первое будет главным"
        ) {
            photoGrid
        }
    }

    /// Имя и дата рождения.
    /// - Parameters:
    ///   - name: привязка имени.
    ///   - birthDate: привязка даты рождения.
    ///   - latestDate: самая поздняя допустимая дата.
    private func identitySection(
        name: Binding<String>,
        birthDate: Binding<Date>,
        latestDate: Date
    ) -> some View {
        ProfileFormSection("О вас", subtitle: "Имя, пол и дату рождения потом изменить нельзя") {
            VStack(spacing: AppTheme.Spacing.m) {
                TextField("Имя", text: name)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .font(AppTheme.Typography.body)
                    .padding(.horizontal, AppTheme.Spacing.m)
                    .frame(minHeight: AppTheme.Size.fieldHeight)
                    .background(AppTheme.Colors.surfaceMuted, in: fieldShape)

                DatePicker(
                    "Дата рождения",
                    selection: birthDate,
                    in: ...latestDate,
                    displayedComponents: .date
                )
                .font(AppTheme.Typography.body)
                .tint(AppTheme.Colors.accent)
            }
        }
    }

    /// Выбор пола.
    /// - Parameter selection: текущий выбор.
    private func genderSection(selection: Binding<Gender?>) -> some View {
        ProfileFormSection("Ваш пол") {
            Picker("Ваш пол", selection: selection) {
                ForEach(Gender.allCases, id: \.self) { gender in
                    Text(gender.title).tag(Gender?.some(gender))
                }
            }
            .pickerStyle(.segmented)
            .tint(AppTheme.Colors.accent)
        }
    }

    /// Выбор интереса.
    /// - Parameter selection: текущий выбор.
    private func interestSection(selection: Binding<InterestOption?>) -> some View {
        ProfileFormSection("Кого ищете") {
            Picker("Кого ищете", selection: selection) {
                ForEach(InterestOption.allCases) { option in
                    Text(option.title).tag(InterestOption?.some(option))
                }
            }
            .pickerStyle(.segmented)
            .tint(AppTheme.Colors.accent)
        }
    }

    /// Нижняя панель с основным действием и прогрессом.
    private var bottomBar: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            uploadProgress
            submitButton
        }
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.vertical, AppTheme.Spacing.s)
        .background(AppTheme.Colors.background)
    }
    
    private var submitButton: some View {
        Button {
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
    }
    
    @ViewBuilder
    private var uploadProgress: some View {
        if viewModel.isSubmitting {
            ProgressView(
                value: Double(viewModel.uploadedCount),
                total: Double(max(viewModel.tiles.count, 1))
            ) {
                Text("Загружаем фото: \(viewModel.uploadedCount) из \(viewModel.tiles.count)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }
    
    /// Сетка выбранных фото, индикатор обработки и кнопка «Добавить».
    private var photoGrid: some View {
        let surfaceColor = AppTheme.Colors.surfaceMuted
        let borderColor = AppTheme.Colors.separator
        let accentColor = AppTheme.Colors.accentText
        let tileShape = RoundedRectangle(
            cornerRadius: PhotoTileMetrics.cornerRadius,
            style: .continuous
        )

        return LazyVGrid(columns: columns, spacing: AppTheme.Spacing.s) {
            ForEach(viewModel.tiles) { tile in
                PhotoTileView(viewModel: tile)
            }
            
            if viewModel.isLoadingPhotos {
                Color.clear
                    .aspectRatio(PhotoTileMetrics.aspectRatio, contentMode: .fit)
                    .overlay { ProgressView().tint(accentColor) }
                    .background(surfaceColor, in: tileShape)
                    .overlay(tileShape.stroke(borderColor, style: StrokeStyle(lineWidth: 1, dash: [5])))
            }
            
            if viewModel.remainingSlots > 0 {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: viewModel.remainingSlots,
                    matching: .images
                ) {
                    Color.clear
                        .aspectRatio(PhotoTileMetrics.aspectRatio, contentMode: .fit)
                        .overlay {
                        Image(systemName: "plus")
                            .font(.system(.title2, weight: .semibold))
                            .foregroundStyle(accentColor)
                        }
                        .background(surfaceColor, in: tileShape)
                        .overlay(tileShape.stroke(borderColor, style: StrokeStyle(lineWidth: 1, dash: [5])))
                }
                .accessibilityLabel("Добавить фото")
                
            }
        }
        // Не даём внешнему окружению сетки переопределять стили кнопок плиток.
        .buttonStyle(.borderless)
    }

    /// Форма полей и плиток.
    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PhotoTileMetrics.cornerRadius, style: .continuous)
    }
}
