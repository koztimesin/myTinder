//
//  DeleteAccountView.swift
//  myTinder
//
//  Created by Codex on 07.11.2026.
//

import SwiftUI

/// Экран окончательного подтверждения удаления аккаунта.
struct DeleteAccountView<ViewModel: DeleteAccountViewModelProtocol>: View {

    @State private var viewModel: ViewModel
    @State private var isConfirmationPresented = false

    /// - Parameter viewModel: модель удаления аккаунта.
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                    warningHeader
                    deletedDataSection

                    if let errorMessage = viewModel.errorMessage {
                        ErrorBannerView(
                            viewModel: ErrorBannerViewModel(message: errorMessage)
                        )
                    }

                    Button("Удалить аккаунт навсегда", role: .destructive) {
                        isConfirmationPresented = true
                    }
                    .buttonStyle(.app(.destructive))
                    .disabled(viewModel.isDeleting)
                }
                .padding(AppTheme.Spacing.m)
            }

            if viewModel.isDeleting {
                AppTheme.Colors.background.opacity(0.88)
                    .ignoresSafeArea()

                LoadingIndicatorView(
                    viewModel: LoadingIndicatorViewModel(title: "Удаляем аккаунт")
                )
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Удаление аккаунта")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isDeleting)
        .alert("Удалить аккаунт?", isPresented: $isConfirmationPresented) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить навсегда", role: .destructive) {
                Task { await viewModel.deleteAccount() }
            }
        } message: {
            Text("Аккаунт, анкета, фотографии, матчи и переписки будут удалены без возможности восстановления.")
        }
    }

    /// Главное предупреждение перед необратимым действием.
    private var warningHeader: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 54))
                .foregroundStyle(AppTheme.Colors.danger)
                .accessibilityHidden(true)

            Text("Это действие необратимо")
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Аккаунт и все связанные с ним данные будут удалены без возможности восстановления.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// Перечень данных, которые исчезнут вместе с аккаунтом.
    private var deletedDataSection: some View {
        ProfileFormSection("Что будет удалено") {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                deletedDataRow("Анкета и фотографии", systemImage: "person.crop.circle")
                deletedDataRow("Матчи и переписки", systemImage: "bubble.left.and.bubble.right")
            }
        }
    }

    /// Одна строка перечня удаляемых данных.
    private func deletedDataRow(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(AppTheme.Typography.body)
            .foregroundStyle(AppTheme.Colors.textPrimary)
    }
}
