//
//  MatchCelebrationView.swift
//  myTinder
//
//  Created by Ismail on 28.10.2026.
//

import SwiftUI

/// Окно «Это матч»: декоративная композиция, быстрое сообщение и закрытие снизу.
struct MatchCelebrationView<ViewModel: MatchCelebrationViewModelProtocol>: View {
    
    let viewModel: ViewModel
    
    /// Фокус VoiceOver на заголовке при показе окна.
    @AccessibilityFocusState private var isTitleFocused: Bool
    @FocusState private var isMessageFocused: Bool
    
    var body: some View {
        @Bindable var vm = viewModel

        ZStack {
            MatchCelebrationDecor()

            VStack(spacing: AppTheme.Spacing.l) {
                Spacer()
                    .frame(height: 80)

                let text = vm.title.components(separatedBy: " ")
                
                HStack {
                    
                    makeItsMatchText(with: getUnwrappedText(from: text, index: 0), color: AppTheme.Colors.textPrimary)
                    
                    makeItsMatchText(with: getUnwrappedText(from: text, index: 1), color: AppTheme.Colors.surfaceMuted)
                }
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($isTitleFocused)
                
                
                Spacer()
                    .frame(height: 50)

                HStack(spacing: -AppTheme.Spacing.m) {
                    MatchAvatarView(viewModel: vm.myAvatar)
                        .rotationEffect(.degrees(-7))
                    MatchAvatarView(viewModel: vm.partnerAvatar)
                        .rotationEffect(.degrees(7))
                }

                Text(vm.subtitle)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Spacer()

                VStack(spacing: AppTheme.Spacing.s) {
                    HStack(spacing: AppTheme.Spacing.s) {
                        TextField("Написать сообщение", text: $vm.draft, axis: .vertical)
                            .lineLimit(1...3)
                            .focused($isMessageFocused)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .padding(.horizontal, AppTheme.Spacing.m)
                            .frame(minHeight: 52)

                        Button {
                            Task { await vm.send() }
                        } label: {
                            Group {
                                if vm.isSending {
                                    ProgressView().tint(AppTheme.Colors.onAccent)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                }
                            }
                            .frame(width: AppTheme.Size.minTapTarget, height: AppTheme.Size.minTapTarget)
                            .foregroundStyle(AppTheme.Colors.onAccent)
                            .background(AppTheme.Colors.accent, in: Circle())
                        }
                        .disabled(!vm.canSend)
                        .accessibilityLabel("Отправить сообщение")
                    }
                    .padding(6)
                    .background(AppTheme.Colors.surface, in: Capsule())

                    if let message = vm.errorMessage {
                        Text(message)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.dangerText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
                    .frame(height: 110)

                Button(action: vm.dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .frame(width: 56, height: 56)
                        .background(AppTheme.Colors.surface, in: Circle())
                        .overlay(Circle().stroke(AppTheme.Colors.secondaryAccent, lineWidth: 1))
                }
                .accessibilityLabel("Закрыть")
            }
            .padding(.horizontal, AppTheme.Spacing.l)
            .padding(.bottom, AppTheme.Spacing.m)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .accessibilityAddTraits(.isModal)
        .task { await viewModel.loadPhotos() }
        .onAppear { isTitleFocused = true }
    }
    
    private func makeItsMatchText(with text: String, color: Color) -> some View {
        
        Text(text)
            .font(AppTheme.Typography.cardTitle)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
    }
    
    private func getUnwrappedText(from string: [String], index: Int) -> String {
        
        guard let text = string[safe: index] else { return "" }
        
        return text
    }
}

/// Геометрический декор, намеренно сосредоточенный только на экране матча.
private struct MatchCelebrationDecor: View {
    var body: some View {
        ZStack {
            AppTheme.Colors.background
            
            Circle()
                .fill(AppTheme.Colors.accent)
                .frame(width: 190, height: 190)
                .offset(x: 80, y: -260)
            
            Circle()
                .fill(AppTheme.Colors.accent)
                .frame(width: 100)
                .offset(x: -53, y: 355)
            
            Circle()
                .fill(AppTheme.Colors.accent)
                .frame(width: 50)
                .offset(x: 29, y: 445)
            
            Rectangle()
                .fill(AppTheme.Colors.secondaryAccent)
                .rotationEffect(.degrees(-60))
                .frame(width: 30, height: 120)
                .offset(x: 50, y: 411)
            
            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(30))
                .foregroundColor(AppTheme.Colors.secondaryAccent)
                .offset(x: -19, y: 266)
            
            makeEllipses(with: .red)
                .rotationEffect(.degrees(-20))
                .offset(x: 100, y: 327)
            
            Image(systemName: "triangle.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .foregroundColor(.red)
                .rotationEffect(.degrees(-70))
                .offset(x: -150, y: 328)
            
            Rectangle()
                .fill(AppTheme.Colors.secondaryAccent)
                .rotationEffect(.degrees(-80))
                .frame(width: 100, height: 200)
                .offset(x: -100, y: 450)
                
            Image(systemName: "sparkle")
                .resizable()
                .scaledToFit()
                .frame(height: 50)
                .foregroundColor(AppTheme.Colors.accent)
                .offset(x: 124, y: 420)
            
            Rectangle()
                .fill(AppTheme.Colors.secondaryAccent)
                .rotationEffect(.degrees(-38))
                .frame(width: 100, height: 200)
                .offset(x: 238, y: 450)
            
            makeEllipses(with: AppTheme.Colors.secondaryAccent)
                .rotationEffect(.degrees(20))
                .offset(x: -170, y: -220)
            
            Image(systemName: "sparkle")
                .resizable()
                .scaledToFit()
                .rotationEffect(.degrees(15))
                .frame(height: 100)
                .foregroundColor(.red)
                .offset(x: -110, y: -321)
            
            Rectangle()
                .fill(AppTheme.Colors.accent)
                .rotationEffect(.degrees(18))
                .frame(width: 120, height: 200)
                .offset(x: 30, y: -470)
            
            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80)
                .rotationEffect(.degrees(-30))
                .foregroundColor(.red)
                .offset(x: 169, y: -358)
            
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
    
    private func makeEllipses(with color: Color, count: Int = 3) -> some View {
        
        HStack(spacing: -25) {
            ForEach(0..<count) { _ in
                Ellipse()
                    .fill(color)
                    .frame(width: 65, height: 140)
            }
        }
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
    var draft = ""
    var canSend: Bool { !draft.isEmpty }
    var isSending = false
    var errorMessage: String?
}

extension MatchCelebrationPreviewViewModel: MatchCelebrationViewModelProtocol {
    func loadPhotos() async {}
    func send() async {}
    func dismiss() {}
}

#Preview("Это матч") {
    MatchCelebrationView(viewModel: MatchCelebrationPreviewViewModel())
}
#endif
