import PhotosUI
import SwiftUI

/// Редактор профиля в фирменной композиции: фотографии 1+3 и отдельные крупные поля.
struct EditProfileView<ViewModel: EditProfileViewModelProtocol>: View {

    @State private var viewModel: ViewModel
    @State private var pickerItems: [PhotosPickerItem] = []
    @Environment(\.dismiss) private var dismiss

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                    photoSection

                    readOnlyField(title: "Имя", value: vm.name)
                    readOnlyField(title: "Пол", value: vm.genderTitle)
                    readOnlyField(title: "Дата рождения", value: vm.birthDateText)
                    bioField(text: $vm.bio, isTooLong: vm.isBioTooLong)

                    if let message = vm.errorMessage {
                        ErrorBannerView(viewModel: .init(message: message))
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.m)
                .padding(.bottom, AppTheme.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .toolbarVisibility(.hidden, for: .navigationBar)
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

    private var header: some View {
        HStack {
            Button(action: dismiss.callAsFunction) {
                Image(systemName: "chevron.left")
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .frame(width: AppTheme.Size.minTapTarget, height: AppTheme.Size.minTapTarget)
                    .background(AppTheme.Colors.surface, in: Circle())
            }
            .accessibilityLabel("Назад")

            Spacer()

            Button {
                Task {
                    await viewModel.save()
                    if viewModel.errorMessage == nil { dismiss() }
                }
            } label: {
                if viewModel.isBusy {
                    ProgressView().tint(AppTheme.Colors.accent)
                } else {
                    Text("Сохранить")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }
            }
            .foregroundStyle(AppTheme.Colors.accentText)
            .frame(minWidth: AppTheme.Size.minTapTarget, minHeight: AppTheme.Size.minTapTarget)
            .disabled(!viewModel.canSave)
        }
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.vertical, AppTheme.Spacing.s)
        .background(AppTheme.Colors.background)
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            ProfilePhotoComposition(
                tiles: viewModel.tiles,
                remainingSlots: viewModel.remainingSlots,
                pickerItems: $pickerItems
            )

            Text("До четырёх фото. Первое показывается главным")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func readOnlyField(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            Text(value)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.vertical, AppTheme.Spacing.s + AppTheme.Spacing.xs)
        .frame(minHeight: 76)
        .background(AppTheme.Colors.surface, in: fieldShape)
        .accessibilityElement(children: .combine)
    }

    private func bioField(text: Binding<String>, isTooLong: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("О себе")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            TextField("Расскажите о себе", text: text, axis: .vertical)
                .lineLimit(4...8)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .textInputAutocapitalization(.sentences)

            Text("\(text.wrappedValue.count) / 500")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(isTooLong ? AppTheme.Colors.danger : AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityHidden(true)
        }
        .padding(AppTheme.Spacing.m)
        .background(AppTheme.Colors.surface, in: fieldShape)
        .overlay {
            if isTooLong {
                fieldShape.stroke(AppTheme.Colors.danger, lineWidth: 2)
            }
        }
        .accessibilityHint(isTooLong ? "Превышен лимит в 500 символов" : "")
    }

    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
    }

    @ViewBuilder
    private var busyOverlay: some View {
        if viewModel.isBusy {
            LoadingIndicatorView(viewModel: .init(title: "Обновляем профиль"))
                .padding(AppTheme.Spacing.l)
                .appGlass(in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous))
        }
    }
}
