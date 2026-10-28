//
//  MatchAvatarView.swift
//  myTinder
//
//  Created by Ismail on 28.10.2026.
//

import SwiftUI

struct MatchAvatarView: View {

    let viewModel: MatchAvatarViewModel

    private let ringWidth: CGFloat = 3
    private let ringGap: CGFloat = 3

    var body: some View {
        
        ZStack {
            
            if viewModel.showsRing {
                Circle()
                    .strokeBorder(AppTheme.Colors.accent, lineWidth: ringWidth)
            }
            
            photoCircle
                .padding(viewModel.showsRing ? ringWidth + ringGap : 0)
        }
        .frame(width: viewModel.diameter, height: viewModel.diameter)
        .accessibilityHidden(true)
    }

    /// Фото в круге; пока фото нет, показывается заглушка.
    private var photoCircle: some View {
        Circle()
            .fill(AppTheme.Colors.surfaceMuted)
            .overlay { photoContent }
            .clipShape(Circle())
    }

    /// Фото, если оно загрузилось, иначе заглушка с первой буквой имени.
    @ViewBuilder
    private var photoContent: some View {
        if let url = viewModel.photoURL {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    initial
                }
            }
        } else {
            initial
        }
    }

    /// Первая буква имени.
    private var initial: some View {
        Text(String(viewModel.name.prefix(1)).uppercased())
            .font(.system(.title2, design: .rounded, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.textSecondary)
    }
}

#Preview {
    MatchAvatarView(viewModel: .init(name: "Anya",
                                     photoURL: nil,
                                     diameter: 128,
                                     showsRing: true))
}
