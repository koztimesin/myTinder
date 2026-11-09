//
//  FeedActionButtonStyle.swift
//  myTinder
//
//  Created by Ismail on 27.10.2026.
//

import SwiftUI

struct FeedActionButtonStyle: ButtonStyle {
    
    enum Kind {
        case dislike
        case like
    }
    
    let kind: Kind
    
    /// Собирает внешний вид кнопки.
    /// - Parameter configuration: состояние кнопки и её содержимое (иконка).
    /// - Returns: круглая кнопка нужного вида.
    func makeBody(configuration: Configuration) -> some View {
        FeedActionButtonBody(kind: kind, configuration: configuration)
    }
}

private struct FeedActionButtonBody: View {

    let kind: FeedActionButtonStyle.Kind
    let configuration: ButtonStyleConfiguration

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    var body: some View {
        let content = configuration.label
            .font(.system(size: iconSize, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.white)
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
        
        switch kind {
        case .like:
            content
                .background(AppTheme.Colors.coral, in: Circle())
                .shadow(color: AppTheme.Colors.coral.opacity(0.28), radius: 14, y: 6)
        case .dislike:
            content
                .background(AppTheme.Colors.surface, in: Circle())
                .overlay(Circle().stroke(AppTheme.Colors.secondaryAccent.opacity(0.6), lineWidth: 1))
        }
    }
    
    private var diameter: CGFloat {
        kind == .like ? AppTheme.Size.likeButton : AppTheme.Size.dislikeButton
    }
    
    private var iconSize: CGFloat {
        kind == .like ? 32 : 26
    }
}

extension ButtonStyle where Self == FeedActionButtonStyle {
    
    /// Короткая запись стиля: `.buttonStyle(.feedAction(.like))`.
    /// - Parameter kind: вид кнопки.
    /// - Returns: стиль круглой кнопки ленты.
    static func feedAction(_ kind: FeedActionButtonStyle.Kind) -> FeedActionButtonStyle {
        FeedActionButtonStyle(kind: kind)
    }
}
