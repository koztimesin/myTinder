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
    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let content = configuration.label
            .font(.system(size: iconSize, weight: .heavy, design: .rounded))
            .foregroundStyle(kind == .like ? AppTheme.Colors.onAccent : Color.white)
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        
        switch kind {
        case .like:
            content
                .background(AppTheme.Colors.accent, in: Circle())
        case .dislike:
            content
                .appGlass(in: Circle())
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
