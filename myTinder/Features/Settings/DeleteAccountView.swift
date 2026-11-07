//
//  DeleteAccountView.swift
//  myTinder
//
//  Created by Codex on 07.11.2026.
//

import SwiftUI

/// Информационный экран перед подключением серверного удаления аккаунта.
struct DeleteAccountView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                VStack(spacing: AppTheme.Spacing.m) {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.system(size: 54))
                        .foregroundStyle(AppTheme.Colors.danger)
                        .accessibilityHidden(true)

                    Text("Удалить аккаунт?")
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Text("Профиль, фотографии, матчи и сообщения будут удалены без возможности восстановления.")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)

                ErrorBannerView(
                    viewModel: ErrorBannerViewModel(
                        message: "Серверное удаление будет подключено отдельным этапом через Supabase Edge Function."
                    )
                )
            }
            .padding(AppTheme.Spacing.m)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Удаление аккаунта")
        .navigationBarTitleDisplayMode(.inline)
    }
}
