//
//  MessageBubbleView.swift
//  myTinder
//
//  Created by Ismail on 29.10.2026.
//

import SwiftUI

/// Пузырь сообщения: свои акцентные справа, чужие на поверхности слева.
struct MessageBubbleView: View {
    
    let viewModel: MessageBubbleViewModel
    
    private var alignment: HorizontalAlignment { viewModel.isFromMe ? .trailing : .leading }
    
    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            
            Text(viewModel.text)
                .font(AppTheme.Typography.body)
                .foregroundStyle(viewModel.isFromMe ? AppTheme.Colors.onAccent : AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.m)
                .padding(.vertical, 10)
                .background { bubbleShape.fill(viewModel.isFromMe ? AppTheme.Colors.accent : AppTheme.Colors.surface) }
                .overlay {
                    if !viewModel.isFromMe {
                        bubbleShape.strokeBorder(AppTheme.Colors.separator, lineWidth: 1)
                    }
                }
                .textSelection(.enabled)
            
            footer
        }
        .frame(maxWidth: .infinity, alignment: viewModel.isFromMe ? .trailing : .leading)
        .padding(viewModel.isFromMe ? .leading : .trailing, 48)
        .contextMenu {
            if viewModel.delivery == .failed {
                Button("Повторить") { viewModel.onRetry() }
                Button("Удалить", role: .destructive) { viewModel.onDiscard() }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityActions {
            if viewModel.delivery == .failed {
                Button("Повторить") { viewModel.onRetry() }
                Button("Удалить") { viewModel.onDiscard() }
            }
        }
    }
    
    /// Форма пузыря.
    private var bubbleShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
    }
    
    /// Подпись под пузырём: время, «Отправляется…» или «Не отправлено».
    @ViewBuilder
    private var footer: some View {
        switch viewModel.delivery {
        case .sent:
            Text(viewModel.timeText)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        case .sending:
            Text("Отправляется…")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        case .failed:
            Button("Не отправлено · Повторить") { viewModel.onRetry() }
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.danger)
                .frame(minHeight: AppTheme.Size.minTapTarget)
        }
    }
    
    /// Текст для VoiceOver: «Вы, 14:32: текст».
    private var accessibilityText: String {
        let author = viewModel.isFromMe ? "Вы" : viewModel.senderName
        switch viewModel.delivery {
        case .sent: return "\(author), \(viewModel.timeText): \(viewModel.text)"
        case .sending: return "\(author), отправляется: \(viewModel.text)"
        case .failed: return "\(author), не отправлено: \(viewModel.text)"
        }
    }
}

/// Разделитель дня в списке сообщений.
struct DaySeparatorView: View {
    
    let viewModel: DaySeparatorViewModel
    
    var body: some View {
        Text(viewModel.title)
            .font(AppTheme.Typography.caption)
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.s)
            .accessibilityAddTraits(.isHeader)
    }
}
