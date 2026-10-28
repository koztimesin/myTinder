//
//  MatchRowView.swift
//  myTinder
//
//  Created by Ismail on 28.10.2026.
//

import SwiftUI

struct MatchRowView: View {
    
    let viewModel: MatchRowViewModel
    
    var body: some View {
        Button {
            viewModel.onTap()
        } label: {
            HStack(spacing: AppTheme.Spacing.m) {
                
                MatchAvatarView(viewModel: viewModel.avatar)
                
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    
                    Text(viewModel.name)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(viewModel.preview)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: AppTheme.Spacing.s)
                
                Text(viewModel.timeText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.vertical, AppTheme.Spacing.s)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(viewModel.name). \(viewModel.preview). \(viewModel.timeText)"))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    let matchAvatarViewModel = MatchAvatarViewModel(name: "Anya",
                                                    photoURL: nil,
                                                    diameter: 64,
                                                    showsRing: true)
    
    MatchRowView(viewModel: .init(id: .init(),
                                  name: "Anya",
                                  preview: "Hello",
                                  timeText: "11:30",
                                  avatar: matchAvatarViewModel,
                                  onTap: { }
                                 ))
}
