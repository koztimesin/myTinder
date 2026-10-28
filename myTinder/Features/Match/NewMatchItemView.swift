//
//  NewMatchItemView.swift
//  myTinder
//
//  Created by Ismail on 28.10.2026.
//

import SwiftUI

struct NewMatchItemView: View {
    
    let viewModel: NewMatchItemViewModel
    
    var body: some View {
        Button {
            viewModel.onTap()
        } label: {
            VStack(spacing: AppTheme.Spacing.xs) {
                
                MatchAvatarView(viewModel: viewModel.avatar)
                
                Text(viewModel.name)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .frame(width: viewModel.avatar.diameter)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Новый матч: \(viewModel.name)"))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    let matchAvatarViewModel = MatchAvatarViewModel(name: "Anya",
                                                    photoURL: nil,
                                                    diameter: 128,
                                                    showsRing: true)
    
    NewMatchItemView(viewModel: .init(id: .init(),
                                      name: "Anya",
                                      avatar: matchAvatarViewModel,
                                      onTap: { }
                                     ))
}
