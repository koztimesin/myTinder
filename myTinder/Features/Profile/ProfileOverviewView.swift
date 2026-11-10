import SwiftUI

/// Отдельный экран просмотра профиля без полей редактирования.
struct ProfileOverviewView<ViewModel: EditProfileViewModelProtocol>: View {

    @Bindable private var viewModel: ViewModel
    let onEdit: @MainActor () -> Void
    let onOpenSettings: @MainActor () -> Void
    let onSignOut: @MainActor () -> Void

    init(
        viewModel: ViewModel,
        onEdit: @escaping @MainActor () -> Void,
        onOpenSettings: @escaping @MainActor () -> Void,
        onSignOut: @escaping @MainActor () -> Void
    ) {
        self.viewModel = viewModel
        self.onEdit = onEdit
        self.onOpenSettings = onOpenSettings
        self.onSignOut = onSignOut
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.l) {
                profileHeader

                Button("Редактировать профиль", action: onEdit)
                    .buttonStyle(.app(.primary))
                    .fixedSize()

                VStack(spacing: AppTheme.Spacing.s) {
                    profileAction(
                        title: "Настройки",
                        systemImage: "gearshape.fill",
                        action: onOpenSettings
                    )

                    Button(role: .destructive, action: onSignOut) {
                        HStack(spacing: AppTheme.Spacing.m) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .frame(width: AppTheme.Size.minTapTarget, height: AppTheme.Size.minTapTarget)
                            Text("Выйти")
                                .font(AppTheme.Typography.body)
                            Spacer()
                        }
                        .foregroundStyle(AppTheme.Colors.danger)
                        .padding(.horizontal, AppTheme.Spacing.m)
                        .frame(minHeight: 64)
                        .background(AppTheme.Colors.surface, in: actionShape)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.top, AppTheme.Spacing.l)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private var profileHeader: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            CachedPhotoView(url: viewModel.mainPhotoURL) {
                ZStack {
                    placeholder
                    if viewModel.mainPhotoURL != nil {
                        ProgressView().tint(AppTheme.Colors.accent)
                    }
                }
            }
            .frame(width: 156, height: 196)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .accessibilityLabel("Главное фото профиля")

            Text("\(viewModel.name), \(viewModel.age)")
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
        }
    }

    private var placeholder: some View {
        AppTheme.Colors.surfaceMuted
            .overlay {
                Image(systemName: "person.crop.rectangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.Colors.secondaryAccent)
            }
    }

    private func profileAction(
        title: String,
        systemImage: String,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.m) {
                Image(systemName: systemImage)
                    .frame(width: AppTheme.Size.minTapTarget, height: AppTheme.Size.minTapTarget)
                Text(title)
                    .font(AppTheme.Typography.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .padding(.horizontal, AppTheme.Spacing.m)
            .frame(minHeight: 64)
            .background(AppTheme.Colors.surface, in: actionShape)
        }
        .buttonStyle(.plain)
    }

    private var actionShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
    }
}
