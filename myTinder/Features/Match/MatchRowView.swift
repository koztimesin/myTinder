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
                
                VStack(alignment: .trailing, spacing: AppTheme.Spacing.xs) {
                    
                    Text(viewModel.timeText)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    
                    if viewModel.unreadCount > 0 {
                        Text(viewModel.unreadCount > 99 ? "99+" : "\(viewModel.unreadCount)")
                            .font(.system(.caption2, design: .rounded, weight: .heavy))
                            .foregroundStyle(AppTheme.Colors.onAccent)
                            .padding(.horizontal, 6)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(AppTheme.Colors.accent, in: Capsule())
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.vertical, AppTheme.Spacing.s)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(viewModel.name). \(viewModel.preview). \(viewModel.timeText)" + (viewModel.unreadCount > 0 ? ". Непрочитанных: \(viewModel.unreadCount)" : "")))
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
                                  unreadCount: 1,
                                  onTap: { }
                                 ))
}
