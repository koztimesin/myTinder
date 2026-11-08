//
//  EditProfileView.swift
//  myTinder
//
//  Created by Ismail on 25.10.2026.
//

import PhotosUI
import SwiftUI

/// Экран просмотра и редактирования профиля текущего пользователя.
struct EditProfileView<ViewModel: EditProfileViewModelProtocol>: View {

    @State private var viewModel: ViewModel
    @State private var pickerItems: [PhotosPickerItem] = []
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// При специальных размерах текста оставляет плиткам фото достаточно места.
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: AppTheme.Spacing.s),
            count: dynamicTypeSize.isAccessibilitySize ? 2 : 3
        )
    }

    /// Создаёт экран с подготовленной моделью представления.
    /// - Parameter viewModel: модель представления профиля.
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                photoSection
                identitySection
                interestSection(selection: $vm.interest)
                ageSection(minAge: $vm.minAge, maxAge: $vm.maxAge)

                ProfileFormSection("О себе", subtitle: "Добавьте детали, с которых легко начать разговор") {
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
        .navigationTitle("Мой профиль")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Выйти", role: .destructive) { vm.signOut() }
                    .foregroundStyle(AppTheme.Colors.danger)
                    .disabled(vm.isBusy)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: vm.openSettings) {
                    Label("Настройки", systemImage: "gearshape")
                }
                .foregroundStyle(AppTheme.Colors.accentText)
                .disabled(vm.isBusy)
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .disabled(vm.isBusy)
        .overlay { busyOverlay }
        .task { await vm.load() }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }

            Task {
                await vm.addPhotos(from: items)
                pickerItems = []
            }
        }
    }

    // MARK: - Части экрана

    /// Секция фотографий профиля.
    private var photoSection: some View {
        ProfileFormSection(
            "Фотографии",
            subtitle: "До \(ProfileValidation.maxPhotos) фото. Первое показывается главным"
        ) {
            photoGrid
        }
    }

    /// Неизменяемые данные профиля.
    private var identitySection: some View {
        ProfileFormSection("О вас", subtitle: "Имя, пол и дату рождения изменить нельзя") {
            VStack(spacing: AppTheme.Spacing.m) {
                ProfileReadOnlyRow(title: "Имя", value: viewModel.name)
                Divider().overlay(AppTheme.Colors.separator)
                ProfileReadOnlyRow(title: "Пол", value: viewModel.genderTitle)
                Divider().overlay(AppTheme.Colors.separator)
                ProfileReadOnlyRow(title: "Дата рождения", value: viewModel.birthDateText)
            }
        }
    }

    /// Выбор пола кандидатов, показываемых в ленте.
    /// - Parameter selection: выбранный вариант.
    private func interestSection(selection: Binding<InterestOption?>) -> some View {
        ProfileFormSection("Кого показывать") {
            Picker("Кого показывать", selection: selection) {
                ForEach(InterestOption.allCases) { option in
                    Text(option.title).tag(InterestOption?.some(option))
                }
            }
            .pickerStyle(.segmented)
            .tint(AppTheme.Colors.accent)
        }
    }

    /// Выбор возрастного диапазона кандидатов.
    /// - Parameters:
    ///   - minAge: нижняя граница возраста.
    ///   - maxAge: верхняя граница возраста.
    private func ageSection(
        minAge: Binding<Double>,
        maxAge: Binding<Double>
    ) -> some View {
        ProfileFormSection(
            "Возраст",
            subtitle: "От \(Int(minAge.wrappedValue)) до \(Int(maxAge.wrappedValue)) лет"
        ) {
            AgeRangeSlider(
                lowerValue: minAge,
                upperValue: maxAge,
                in: Double(ProfileValidation.minimumDiscoveryAge)...Double(ProfileValidation.maximumDiscoveryAge)
            )
        }
    }

    /// Нижняя панель с основным действием.
    private var bottomBar: some View {
        Button {
            Task { await viewModel.save() }
        } label: {
            if viewModel.isBusy {
                ProgressView().tint(AppTheme.Colors.onAccent)
            } else {
                Text("Сохранить изменения")
            }
        }
        .buttonStyle(.app(.primary))
        .disabled(!viewModel.canSave)
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.vertical, AppTheme.Spacing.s)
        .background(AppTheme.Colors.background)
    }

    /// Индикатор, перекрывающий экран во время загрузки и сохранения.
    @ViewBuilder
    private var busyOverlay: some View {
        if viewModel.isBusy {
            LoadingIndicatorView(viewModel: LoadingIndicatorViewModel(title: "Обновляем профиль"))
                .padding(AppTheme.Spacing.l)
                .appGlass(in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous))
        }
    }

    /// Сетка фото профиля и кнопка «Добавить».
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
        .buttonStyle(.borderless)
    }
}
