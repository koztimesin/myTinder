//
//  ErrorBannerView.swift
//  myTinder
//
//  Created by Ismail on 26.10.2026.
//

import SwiftUI

struct ErrorBannerViewModel: Equatable {
    
    /// Текст ошибки для пользователя.
    let message: String
}


struct ErrorBannerView: View {
    
    let viewModel: ErrorBannerViewModel
    
    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
            Image(systemName: "exclamationmark.circle")
                .font(AppTheme.Typography.caption)
                .accessibilityHidden(true)
            Text(viewModel.message)
                .font(AppTheme.Typography.caption)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(AppTheme.Colors.dangerText)
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.vertical, AppTheme.Spacing.s + AppTheme.Spacing.xs)
        .background(
            AppTheme.Colors.dangerSurface,
            in: RoundedRectangle(cornerRadius: AppTheme.Radius.small, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Ошибка: \(viewModel.message)"))
    }
}

#Preview("Плашка ошибки") {
    ErrorBannerView(viewModel: ErrorBannerViewModel(message: "Минимум 8 символов"))
        .padding(AppTheme.Spacing.m)
        .background(AppTheme.Colors.background)
}
