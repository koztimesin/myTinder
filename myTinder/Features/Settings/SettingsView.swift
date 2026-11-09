//
//  SettingsView.swift
//  myTinder
//
//  Created by Codex on 07.11.2026.
//

import SwiftUI

/// Экран общих настроек приложения.
struct SettingsView<ViewModel: SettingsViewModelProtocol>: View {

    @State private var viewModel: ViewModel

    /// Создаёт экран с подготовленной моделью представления.
    /// - Parameter viewModel: модель настроек.
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                accountSection
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.top, AppTheme.Spacing.s)
            .padding(.bottom, AppTheme.Spacing.l)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Раздел опасных действий с аккаунтом.
    private var accountSection: some View {
        ProfileFormSection("Аккаунт") {
            Button(action: viewModel.openDeleteAccount) {
                HStack(spacing: AppTheme.Spacing.m) {
                    Image(systemName: "trash")
                        .frame(width: AppTheme.Size.minTapTarget, height: AppTheme.Size.minTapTarget)

                    Text("Удалить аккаунт")
                        .font(AppTheme.Typography.body)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(AppTheme.Colors.danger)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
