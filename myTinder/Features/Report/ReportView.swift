//
//  ReportView.swift
//  myTinder
//
//  Created by Ismail on 31.10.2026.
//

import SwiftUI

struct ReportView<ViewModel: ReportViewModelProtocol>: View {
    
    @Bindable var viewModel: ViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.Colors.background)
                .navigationTitle("Жалоба")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if viewModel.canCancel {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Отмена") { dismiss() }
                        }
                    }
                }
        }
        .interactiveDismissDisabled(viewModel.isDismissLocked)
    }
    
    // MARK: - Состояния
    
    /// Содержимое по состоянию экрана.
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .sending, .failed:
            form
        case .sent:
            sentState
        case .blockFailed:
            blockFailedState
        }
    }
    
    // MARK: - Форма
    
    /// Форма жалобы: причина, комментарий, блокировка.
    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                categorySection
                detailsSection
                blockSection
                
                if case .failed(let message) = viewModel.state {
                    ErrorBannerView(viewModel: ErrorBannerViewModel(message: message))
                }
            }
            .padding(AppTheme.Spacing.m)
        }
        .scrollDismissesKeyboard(.interactively)
        .disabled(viewModel.state == .sending)
        .safeAreaInset(edge: .bottom) { submitButton }
    }
    
    /// Список причин.
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            sectionTitle("Что не так?")
            
            VStack(spacing: 0) {
                ForEach(viewModel.categories) { category in
                    categoryRow(category)
                    
                    if category != viewModel.categories.last {
                        Divider().overlay(AppTheme.Colors.separator)
                    }
                }
            }
            .background(
                AppTheme.Colors.surface,
                in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
            )
        }
    }
    
    /// Строка причины с галочкой у выбранной.
    /// - Parameter category: причина.
    private func categoryRow(_ category: ReportCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category
        
        return Button {
            viewModel.selectedCategory = category
        } label: {
            HStack(spacing: AppTheme.Spacing.s) {
                Text(category.title)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                
                Spacer(minLength: AppTheme.Spacing.s)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.accentText)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .frame(minHeight: AppTheme.Size.buttonHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    /// Необязательный комментарий со счётчиком.
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            sectionTitle("Комментарий")
            
            TextField("Расскажите подробнее (необязательно)", text: $viewModel.details, axis: .vertical)
                .lineLimit(3...6)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(AppTheme.Spacing.m)
                .background(
                    AppTheme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                )
            
            Text(viewModel.detailsCounter)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }
    
    /// Переключатель «Также заблокировать».
    private var blockSection: some View {
        Toggle(isOn: $viewModel.alsoBlock) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Также заблокировать")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text(viewModel.alsoBlockHint)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .tint(AppTheme.Colors.accent)
        .padding(AppTheme.Spacing.m)
        .background(
            AppTheme.Colors.surface,
            in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
        )
    }
    
    /// Кнопка «Отправить» внизу экрана.
    private var submitButton: some View {
        Button {
            Task { await viewModel.submit() }
        } label: {
            if viewModel.state == .sending {
                ProgressView().tint(AppTheme.Colors.onAccent)
            } else {
                Text("Отправить")
            }
        }
        .buttonStyle(.app(.primary))
        .disabled(!viewModel.canSubmit)
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.vertical, AppTheme.Spacing.s)
        .background(AppTheme.Colors.background)
    }
    
    /// Заголовок раздела формы.
    /// - Parameter text: текст заголовка.
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }
    
    // MARK: - Результат
    
    /// Жалоба отправлена.
    private var sentState: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.Colors.success)
                .accessibilityHidden(true)
            
            resultText(title: "Жалоба отправлена", message: viewModel.sentMessage)
            
            Spacer()
            
            Button("Готово") { viewModel.finish() }
                .buttonStyle(.app(.primary))
        }
        .padding(AppTheme.Spacing.l)
    }
    
    /// Жалоба отправлена, блокировка не прошла.
    private var blockFailedState: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.Colors.danger)
                .accessibilityHidden(true)
            
            resultText(
                title: "Жалоба отправлена",
                message: "Но заблокировать не удалось. Проверьте соединение и повторите."
            )
            
            Spacer()
            
            Button("Повторить блокировку") {
                Task { await viewModel.submit() }
            }
            .buttonStyle(.app(.primary))
            
            Button("Закрыть") { viewModel.finish() }
                .buttonStyle(.app(.text))
        }
        .padding(AppTheme.Spacing.l)
    }
    
    /// Заголовок и пояснение экрана результата.
    private func resultText(title: String, message: String) -> some View {
        VStack(spacing: AppTheme.Spacing.s) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text(message)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
/// Заглушка модели для превью.
@MainActor
@Observable
final class ReportPreviewViewModel {
    var selectedCategory: ReportCategory? = .spam
    var details = ""
    var alsoBlock = true
    var state: ReportState = .idle
}

extension ReportPreviewViewModel: ReportViewModelProtocol {
    var categories: [ReportCategory] { ReportCategory.allCases }
    var detailsCounter: String { "\(details.count) / 1000" }
    var alsoBlockHint: String { "Вы больше не увидите друг друга, а диалог с «Алина» будет удалён без возможности восстановления." }
    var canSubmit: Bool { selectedCategory != nil }
    var canCancel: Bool { true }
    var isDismissLocked: Bool { false }
    var sentMessage: String { "Спасибо, мы рассмотрим её." }
    func submit() async {}
    func finish() {}
}

#Preview("Жалоба") {
    ReportView(viewModel: ReportPreviewViewModel())
}

#Preview("Жалоба: отправлена") {
    let model = ReportPreviewViewModel()
    model.state = .sent
    return ReportView(viewModel: model)
}

#Preview("Жалоба: сбой блокировки") {
    let model = ReportPreviewViewModel()
    model.state = .blockFailed
    return ReportView(viewModel: model)
}
#endif
