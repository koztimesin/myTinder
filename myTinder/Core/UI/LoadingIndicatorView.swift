//
//  LoadingIndicatorView.swift
//  myTinder
//
//  Created by Ismail on 26.10.2026.
//

import SwiftUI

struct LoadingIndicatorViewModel: Equatable {
    
    /// Подпись под индикатором. Если `nil`, показывается только индикатор.
    let title: String?
}

struct LoadingIndicatorView: View {
    
    let viewModel: LoadingIndicatorViewModel
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppTheme.Colors.accent)
                .controlSize(.large)
            if let title = viewModel.title {
                Text(title)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(viewModel.title ?? "Загрузка"))
    }
}

#Preview("Загрузка") {
    LoadingIndicatorView(viewModel: LoadingIndicatorViewModel(title: "Загружаем анкеты"))
        .padding(AppTheme.Spacing.xl)
        .background(AppTheme.Colors.background)
}
