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
        .navigationTitle("Редактирование")
        .navigationBarTitleDisplayMode(.inline)
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
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Фотографии")
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("До четырёх фото. Первое показывается главным")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            ProfilePhotoComposition(
                tiles: viewModel.tiles,
                remainingSlots: viewModel.remainingSlots,
                pickerItems: $pickerItems
            )
        }
    }

    /// Неизменяемые данные профиля.
    private var identitySection: some View {
        ProfileFormSection("О вас", subtitle: "Эти данные изменить нельзя") {
            VStack(spacing: AppTheme.Spacing.m) {
                ProfileReadOnlyRow(title: "Имя", value: viewModel.name)
                Divider().overlay(AppTheme.Colors.separator)
                ProfileReadOnlyRow(title: "Пол", value: viewModel.genderTitle)
                Divider().overlay(AppTheme.Colors.separator)
                ProfileReadOnlyRow(title: "Дата рождения", value: viewModel.birthDateText)
            }
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

}
