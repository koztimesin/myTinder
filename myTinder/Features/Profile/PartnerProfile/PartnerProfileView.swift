import SwiftUI

/// Полноэкранная модальная анкета собеседника в том же виде, что раскрытая карточка ленты.
struct PartnerProfileView: View {

    @Bindable var viewModel: PartnerProfileViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingIndicatorView(viewModel: .init(title: "Загружаем анкету"))
            case .failed:
                failedState
            case .content:
                card
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .alert("Заблокировать пользователя?", isPresented: $viewModel.isBlockConfirmationPresented) {
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
        .task { await viewModel.load() }
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private var card: some View {
        if let card = viewModel.card {
            GeometryReader { proxy in
                let topInset = proxy.safeAreaInsets.top

                FeedCardView(
                    viewModel: card,
                    expansion: 1,
                    topInset: topInset,
                    reservesFeedActionSpace: false
                )
                .overlay(alignment: .top) {
                    actionsMenu
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, AppTheme.Spacing.m)
                        .padding(.top, topInset + AppTheme.Spacing.m + FeedCardView.indicatorHeight + AppTheme.Spacing.s)
                }
                .overlay(alignment: .bottom) {
                    if let error = viewModel.actionError {
                        ErrorBannerView(viewModel: .init(message: error))
                            .padding(AppTheme.Spacing.m)
                    }
                }
            }
        }
    }

    private var actionsMenu: some View {
        Menu {
            Button(action: viewModel.openReport) {
                Label("Пожаловаться", systemImage: "exclamationmark.bubble")
            }
            Button(role: .destructive, action: viewModel.requestBlock) {
                Label("Заблокировать", systemImage: "hand.raised")
            }
        } label: {
            circleLabel(systemImage: "ellipsis")
        }
        .disabled(viewModel.isModerationBusy)
        .accessibilityLabel("Действия с анкетой")
    }

    private func circleLabel(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: AppTheme.Size.minTapTarget, height: AppTheme.Size.minTapTarget)
            .background(Color.black.opacity(0.35), in: Circle())
            .appGlass(in: Circle())
    }

    private var failedState: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            Text("Не удалось загрузить анкету")
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Button("Повторить") { Task { await viewModel.retry() } }
                .buttonStyle(.app(.primary))

        }
        .padding(AppTheme.Spacing.l)
    }
}
