//
//  ChatView.swift
//  myTinder
//
//  Created by Ismail on 29.10.2026.
//

import SwiftUI

struct ChatView<ViewModel: ChatViewModelProtocol>: View {
    
    @Bindable var viewModel: ViewModel
    
    @Environment(\.scenePhase) private var scenePhase
    /// Включается чуть позже появления списка, чтобы стартовая прокрутка вниз не запустила подгрузку истории.
    @State private var canLoadOlder = false
    
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { header }
                ToolbarItem(placement: .topBarTrailing) { actionsMenu }
            }
            .toolbarVisibility(.hidden, for: .tabBar)
            .task { await viewModel.run() }
            .task { await viewModel.loadPhotos() }
            .onChange(of: scenePhase) { _, phase in
                Task { await viewModel.sceneDidChange(isActive: phase == .active) }
            }
            .alert(
                "Заблокировать пользователя?",
                isPresented: $viewModel.isBlockConfirmationPresented
            ) {
                Button("Отмена", role: .cancel) {}
                Button("Заблокировать", role: .destructive) {
                    Task { await viewModel.confirmBlock() }
                }
            } message: {
                Text(viewModel.blockConfirmationMessage)
            }
            .sheet(isPresented: $viewModel.isReportPresented) {
                if let report = viewModel.report {
                    ReportView(viewModel: report)
                }
            }
    }
    private var header: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            MatchAvatarView(viewModel: viewModel.avatar)
            
            Text(viewModel.title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(viewModel.title))
        .accessibilityAddTraits(.isHeader)
    }
    
    private var actionsMenu: some View {
        Menu {
            Button {
                viewModel.openReport()
            } label: {
                Label("Пожаловаться", systemImage: "exclamationmark.bubble")
            }
            
            Button(role: .destructive) {
                viewModel.requestBlock()
            } label: {
                Label("Заблокировать", systemImage: "hand.raised")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .disabled(viewModel.isModerationBusy)
        .accessibilityLabel("Действия с диалогом")
    }
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .tint(AppTheme.Colors.accent)
        case .failed:
            failedState
        case .content:
            messagesList
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: AppTheme.Spacing.s) {
                        if let error = viewModel.actionError {
                            ErrorBannerView(viewModel: error)
                                .padding(.horizontal, AppTheme.Spacing.m)
                        }
                        
                        ChatInputBarView(viewModel: viewModel.inputBar)
                    }
                }
        }
    }
    
    private var failedState: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            
            Text("Не удалось загрузить сообщения. Проверьте соединение.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Повторить") {
                Task { await viewModel.retryLoad() }
            }
            .buttonStyle(.app(.secondary))
        }
        .padding(AppTheme.Spacing.l)
    }
    
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppTheme.Spacing.xs) {
                    
                    if viewModel.hasMoreHistory {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(AppTheme.Spacing.m)
                            .onAppear { loadOlder(proxy: proxy) }
                    }
                    
                    ForEach(viewModel.rows) { row in
                        rowView(row)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.m)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.lastRowID) { _, id in
                guard let id else { return }
                
                withAnimation { proxy.scrollTo(id, anchor: .bottom) }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(400))
                canLoadOlder = true
            }
        }
    }
    
    @ViewBuilder
    private func rowView(_ row: ChatRowViewModel) -> some View {
        switch row {
        case .daySeparator(let model):
            DaySeparatorView(viewModel: model)
        case .message(let model):
            MessageBubbleView(viewModel: model)
        }
    }
    
    /// Подгружает старые сообщения и возвращает прокрутку к строке, которая была первой.
    /// - Parameter proxy: прокси прокрутки.
    private func loadOlder(proxy: ScrollViewProxy) {
        guard canLoadOlder, let anchorID = viewModel.rows.first?.id else { return }
        
        Task {
            await viewModel.loadOlder()
            proxy.scrollTo(anchorID, anchor: .top)
        }
    }
}

#if DEBUG
/// Заглушка модели для превью.
@MainActor
@Observable
final class ChatPreviewViewModel {
    var title = "Алина"
    var avatar = MatchAvatarViewModel(name: "Алина", photoURL: nil, diameter: 32, showsRing: false)
    var state: ChatScreenState = .content
    var hasMoreHistory = false
    var draft = ""
    var report: ReportPreviewViewModel?
    var isReportPresented = false
    var isBlockConfirmationPresented = false
    var blockConfirmationMessage = "Вы больше не увидите друг друга, а диалог с «Алина» будет удалён без возможности восстановления."
    var isModerationBusy = false
    var actionError: ErrorBannerViewModel?
    var rows: [ChatRowViewModel] = [
        .daySeparator(DaySeparatorViewModel(id: "d1", title: "Сегодня")),
        .message(MessageBubbleViewModel(
            id: UUID(), text: "Привет! Как выходные?", timeText: "12:40", isFromMe: false,
            delivery: .sent, senderName: "Алина", onRetry: {}, onDiscard: {}
        )),
        .message(MessageBubbleViewModel(
            id: UUID(), text: "Отлично, ходил в горы", timeText: "12:41", isFromMe: true,
            delivery: .sending, senderName: "Алина", onRetry: {}, onDiscard: {}
        ))
    ]
    var lastRowID: String? { rows.last?.id }
    var inputBar: ChatInputBarViewModel {
        ChatInputBarViewModel(text: Binding(get: { self.draft }, set: { self.draft = $0 }), canSend: !draft.isEmpty, onSend: {})
    }
}

extension ChatPreviewViewModel: ChatViewModelProtocol {
    func run() async {}
    func retryLoad() async {}
    func loadOlder() async {}
    func loadPhotos() async {}
    func sceneDidChange(isActive: Bool) async {}
    func openReport() {
        report = ReportPreviewViewModel()
        isReportPresented = true
    }
    func requestBlock() { isBlockConfirmationPresented = true }
    func confirmBlock() async {}
}

#Preview("Чат") {
    NavigationStack {
        ChatView(viewModel: ChatPreviewViewModel())
    }
}

#Preview("Чат: ошибка действия") {
    let model = ChatPreviewViewModel()
    model.actionError = ErrorBannerViewModel(message: "Не удалось заблокировать. Проверьте соединение и попробуйте снова.")
    return NavigationStack {
        ChatView(viewModel: model)
    }
}
#endif
