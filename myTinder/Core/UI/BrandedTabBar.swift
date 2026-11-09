import SwiftUI

/// Фирменная панель навигации для трёх основных разделов.
struct BrandedTabBar: View {

    @Binding var selection: MainTab
    let unreadCount: Int

    var body: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            item(.feed, title: "Лента", systemImage: "sparkles")
            item(.matches, title: "Матчи", systemImage: "bubble.left.fill", badge: unreadCount)
            item(.profile, title: "Профиль", systemImage: "person.fill")
        }
        .padding(AppTheme.Spacing.s)
        .background(AppTheme.Colors.secondaryAccent, in: Capsule())
        .accessibilityElement(children: .contain)
    }

    private func item(
        _ tab: MainTab,
        title: String,
        systemImage: String,
        badge: Int = 0
    ) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: systemImage)
                    .font(.system(.headline, weight: .bold))
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 {
                            Text("\(min(badge, 99))")
                                .font(.caption2.bold())
                                .foregroundStyle(AppTheme.Colors.onAccent)
                                .padding(4)
                                .background(AppTheme.Colors.accent, in: Capsule())
                                .offset(x: 12, y: -10)
                        }
                    }
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(selection == tab ? AppTheme.Colors.accent : AppTheme.Colors.background)
            .frame(maxWidth: .infinity, minHeight: AppTheme.Size.minTapTarget)
            .background(selection == tab ? AppTheme.Colors.background : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }
}
