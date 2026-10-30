//
//  MatchView.swift
//  myTinder
//
//  Created by Ismail on 28.10.2026.
//

import SwiftUI

/// Экран «Матчи»: ряд «Новые» и список диалогов.
struct MatchesView<ViewModel: MatchesViewModelProtocol>: View {
    
    let viewModel: ViewModel
    
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.background)
            .navigationTitle("Матчи")
            .task(id: viewModel.photoPaths) {
                await viewModel.loadPhotos()
            }
    }
    
    // MARK: - Состояния
    
    /// Содержимое по состоянию экрана.
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .tint(AppTheme.Colors.accent)
        case .failed:
            failedState
        case .empty:
            emptyState
        case .content:
            list
        }
    }
    
    /// Первая загрузка не удалась: текст и кнопка «Повторить».
    private var failedState: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            
            Text(viewModel.errorMessage ?? "Не удалось загрузить матчи.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Повторить") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.app(.secondary))
        }
        .padding(AppTheme.Spacing.l)
    }
    
    /// Матчей пока нет.
    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            
            Image(systemName: "heart")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.accent)
                .accessibilityHidden(true)
            
            Text("Пока нет матчей")
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text("Когда симпатия окажется взаимной, она появится здесь.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Открыть ленту") {
                viewModel.openFeed()
            }
            .buttonStyle(.app(.primary))
        }
        .padding(AppTheme.Spacing.l)
    }
    
    /// Ряд «Новые» и список диалогов.
    private var list: some View {
        ScrollView {
            
            LazyVStack(alignment: .leading, spacing: 0) {
                
                if let message = viewModel.errorMessage {
                    errorBanner(message)
                }
                
                if !viewModel.newItems.isEmpty {
                    sectionHeader("Новые")
                    newRow
                }
                
                if !viewModel.dialogRows.isEmpty {
                    sectionHeader("Сообщения")
                    
                    ForEach(viewModel.dialogRows) { row in
                        
                        MatchRowView(viewModel: row)
                        
                        if row.id != viewModel.dialogRows.last?.id {
                            Rectangle()
                                .fill(AppTheme.Colors.separator)
                                .frame(height: 1)
                                .padding(.leading, AppTheme.Spacing.m)
                        }
                    }
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    /// Горизонтальный ряд новых матчей.
    private var newRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            
            HStack(spacing: AppTheme.Spacing.m) {
                
                ForEach(viewModel.newItems) { item in
                    NewMatchItemView(viewModel: item)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.m)
        }
        .padding(.bottom, AppTheme.Spacing.l)
    }
    
    /// Заголовок секции.
    /// - Parameter title: текст заголовка.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.vertical, AppTheme.Spacing.s)
            .accessibilityAddTraits(.isHeader)
    }
    
    /// Плашка с ошибкой над списком (список при этом остаётся прежним).
    /// - Parameter message: текст ошибки.
    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(AppTheme.Typography.body)
            .foregroundStyle(AppTheme.Colors.dangerText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.Spacing.m)
            .background(AppTheme.Colors.dangerSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous))
            .padding(AppTheme.Spacing.m)
    }
}

#if DEBUG
/// Заглушка модели для превью.
@MainActor
@Observable
final class MatchesPreviewViewModel {
    var state: MatchesScreenState = .content
    var errorMessage: String?
    var newItems: [NewMatchItemViewModel] = ["Алина", "Мария", "Ева"].map { name in
        NewMatchItemViewModel(
            id: UUID(),
            name: name,
            avatar: MatchAvatarViewModel(name: name, photoURL: nil, diameter: 72, showsRing: true),
            onTap: {}
        )
    }
    var dialogRows: [MatchRowViewModel] = [
        MatchRowViewModel(
            id: UUID(),
            name: "Дарья",
            preview: "Вы: Привет! Как проходят выходные?",
            timeText: "12:40",
            avatar: MatchAvatarViewModel(name: "Дарья", photoURL: nil, diameter: 56, showsRing: false),
            onTap: {}
        )
    ]
    var photoPaths: [String] = []
}

extension MatchesPreviewViewModel: MatchesViewModelProtocol {
    func loadPhotos() async {}
    func refresh() async {}
    func openFeed() {}
}

#Preview("Матчи") {
    
    NavigationStack {
        MatchesView(viewModel: MatchesPreviewViewModel())
    }
}
#endif
