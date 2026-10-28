//
//  MatchCelebrationView.swift
//  myTinder
//
//  Created by Ismail on 28.10.2026.
//

import SwiftUI

/// Окно «Это матч»: фото двух пользователей и две кнопки.
struct MatchCelebrationView<ViewModel: MatchCelebrationViewModelProtocol>: View {
    
    let viewModel: ViewModel
    
    /// Фокус VoiceOver на заголовке при показе окна.
    @AccessibilityFocusState private var isTitleFocused: Bool
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.l) {
            
            Spacer()
            
            HStack(spacing: -AppTheme.Spacing.xl) {
                MatchAvatarView(viewModel: viewModel.myAvatar)
                MatchAvatarView(viewModel: viewModel.partnerAvatar)
            }
            
            VStack(spacing: AppTheme.Spacing.s) {
                
                Text(viewModel.title)
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isTitleFocused)
                
                Text(viewModel.subtitle)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            VStack(spacing: AppTheme.Spacing.s) {
                
                Button("Написать") {
                    viewModel.write()
                }
                .buttonStyle(.app(.primary))
                
                Button("Продолжить") {
                    viewModel.dismiss()
                }
                .buttonStyle(.app(.text))
            }
        }
        .padding(.horizontal, AppTheme.Spacing.l)
        .padding(.bottom, AppTheme.Spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .accessibilityAddTraits(.isModal)
        .task { await viewModel.loadPhotos() }
        .onAppear { isTitleFocused = true }
    }
}

#if DEBUG
/// Заглушка модели для превью.
@MainActor
@Observable
final class MatchCelebrationPreviewViewModel {
    var title = "Это матч!"
    var subtitle = "Вы и Алина понравились друг другу"
    var myAvatar = MatchAvatarViewModel(name: "Вы", photoURL: nil, diameter: 150, showsRing: true)
    var partnerAvatar = MatchAvatarViewModel(name: "Алина", photoURL: nil, diameter: 150, showsRing: true)
}

extension MatchCelebrationPreviewViewModel: MatchCelebrationViewModelProtocol {
    func loadPhotos() async {}
    func write() {}
    func dismiss() {}
}

#Preview("Это матч") {
    MatchCelebrationView(viewModel: MatchCelebrationPreviewViewModel())
}
#endif
