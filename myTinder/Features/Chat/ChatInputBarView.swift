//
//  ChatInputBarView.swift
//  myTinder
//
//  Created by Ismail on 29.10.2026.
//

import SwiftUI

/// Модель панели ввода сообщения.
struct ChatInputBarViewModel {
    /// Текст черновика.
    let text: Binding<String>
    /// Можно ли отправлять (текст не пустой).
    let canSend: Bool
    /// Нажатие «Отправить».
    let onSend: @MainActor () -> Void
}

struct ChatInputBarView: View {
    
    let viewModel: ChatInputBarViewModel
    
    var body: some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.s) {
            
            TextField("Сообщение", text: viewModel.text, axis: .vertical)
                .lineLimit(1...5)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.m)
                .padding(.vertical, 12)
                .frame(minHeight: AppTheme.Size.minTapTarget)
                .appGlass(in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            
            Button {
                viewModel.onSend()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(.headline, weight: .heavy))
                    .foregroundStyle(viewModel.canSend ? AppTheme.Colors.onAccent : AppTheme.Colors.textSecondary)
                    .frame(width: AppTheme.Size.minTapTarget, height: AppTheme.Size.minTapTarget)
                    .background(viewModel.canSend ? AppTheme.Colors.accent : AppTheme.Colors.surfaceMuted, in: Circle())
            }
            .disabled(!viewModel.canSend)
            .accessibilityLabel("Отправить")
        }
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.vertical, AppTheme.Spacing.s)
    }
}
