//
//  FeedView.swift
//  myTinder
//
//  Created by Ismail on 27.10.2026.
//

import SwiftUI

struct FeedView<ViewModel: FeedViewModelProtocol>: View {
    
    /// Модель экрана.
    @State private var viewModel: ViewModel
    /// Смещение верхней карточки при перетаскивании.
    @State private var dragOffset: CGSize = .zero
    /// Летит ли карточка прочь: на это время новые жесты и нажатия игнорируются.
    @State private var isFlying = false
    
    /// Смещение, после которого отпускание засчитывается как свайп.
    private let swipeThreshold: CGFloat = 110
    /// Сколько карточек видно в стопке.
    private let stackDepth = 3
    /// Максимальная непрозрачность цветной подсветки (при смещении от порога и дальше).
    private let maxTintOpacity: Double = 0.3
    
    /// - Parameter viewModel: модель экрана, собирается снаружи (`AppContainer.makeFeedViewModel()`).
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            content
        }
        .overlay(alignment: .top) { swipeErrorBanner }
        .task { await viewModel.load() }
        .task(id: viewModel.swipeErrorMessage) {
            guard viewModel.swipeErrorMessage != nil else { return }
            
            try? await Task.sleep(for: .seconds(3))
            viewModel.dismissSwipeError()
        }
    }
    
    // MARK: - Состояния
    
    /// Содержимое по состоянию модели.
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            LoadingIndicatorView(viewModel: LoadingIndicatorViewModel(title: "Загружаем анкеты"))
        case .ready:
            GeometryReader { proxy in
                cardStack(width: proxy.size.width)
            }
        case .empty:
            emptyState
        case .failed(let message):
            failedState(message: message)
        }
    }
    
    /// Анкеты закончились.
    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .accessibilityHidden(true)
            
            Text("Анкеты закончились")
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text("Загляните позже: здесь появятся новые люди")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Обновить") {
                Task { await viewModel.reload() }
            }
            .buttonStyle(.app(.primary))
        }
        .padding(AppTheme.Spacing.l)
    }
    
    /// Не удалось загрузить ленту.
    /// - Parameter message: текст ошибки для пользователя.
    private func failedState(message: String) -> some View {
        VStack(spacing: AppTheme.Spacing.m) {
            ErrorBannerView(viewModel: ErrorBannerViewModel(message: message))
            
            Button("Повторить") {
                Task { await viewModel.reload() }
            }
            .buttonStyle(.app(.primary))
        }
        .padding(AppTheme.Spacing.l)
    }
    
    /// Плашка ошибки неудавшегося свайпа сверху экрана.
    @ViewBuilder
    private var swipeErrorBanner: some View {
        if let message = viewModel.swipeErrorMessage {
            ErrorBannerView(viewModel: ErrorBannerViewModel(message: message))
                .padding(.horizontal, AppTheme.Spacing.m)
                .padding(.top, AppTheme.Spacing.s)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { viewModel.dismissSwipeError() }
        }
    }
    
    /// Цветная подсветка верхней карточки с иконкой в центре: зелёная с сердечком вправо,
    /// красная с крестиком влево. Яркость подсветки и иконки растёт со смещением,
    /// иконка ещё и увеличивается; на пороге свайпа эффект максимальный.
    private var swipeTint: some View {
        let progress = Double(min(abs(dragOffset.width) / swipeThreshold, 1))
        let isLike = dragOffset.width >= 0
        let color = isLike ? AppTheme.Colors.success : AppTheme.Colors.danger
        return ZStack {
            RoundedRectangle(cornerRadius: AppTheme.Radius.photoCard, style: .continuous)
                .fill(color)
                .opacity(progress * maxTintOpacity)
            Image(systemName: isLike ? "heart.fill" : "xmark")
                .font(.system(size: 96, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .shadow(color: Color.black.opacity(0.25), radius: 8)
                .opacity(progress)
                .scaleEffect(0.5 + 0.5 * progress)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    
    // MARK: - Стопка карточек
    
    /// Стопка карточек, заголовок и кнопки поверх фото.
    /// - Parameter width: ширина области; от неё зависят поворот и улёт карточки.
    private func cardStack(width: CGFloat) -> some View {
        let cards = Array(viewModel.visibleCards.prefix(stackDepth))
        return ZStack {
            ForEach(Array(cards.enumerated()).reversed(), id: \.element.id) { index, card in
                let isTop = index == 0
                FeedCardView(viewModel: card)
                    .overlay { if isTop { swipeTint } }
                    .scaleEffect(1 - 0.04 * CGFloat(index))
                    .offset(y: 10 * CGFloat(index))
                    .offset(x: isTop ? dragOffset.width : 0, y: isTop ? dragOffset.height : 0)
                    .rotationEffect(.degrees(isTop ? Double(dragOffset.width / max(width, 1)) * 12 : 0))
                    .allowsHitTesting(isTop)
                    .accessibilityHidden(!isTop)
                    .accessibilityAction(named: Text("Нравится")) { if isTop { swipe(liked: true, width: width) } }
                    .accessibilityAction(named: Text("Пропустить")) { if isTop { swipe(liked: false, width: width) } }
                    .gesture(dragGesture(width: width))
            }
        }
        .padding(AppTheme.Spacing.s)
        .overlay(alignment: .bottom) { actionButtons(width: width) }
    }
    
    /// Кнопки «Пропустить» и «Нравится» поверх фото. Они же основной способ для VoiceOver.
    /// - Parameter width: ширина области, нужна для анимации улёта карточки.
    private func actionButtons(width: CGFloat) -> some View {
        HStack(spacing: AppTheme.Spacing.l) {
            Button {
                swipe(liked: false, width: width)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.feedAction(.dislike))
            .accessibilityLabel(Text("Пропустить"))
            
            Button {
                swipe(liked: true, width: width)
                print(viewModel.state)
            } label: {
                Image(systemName: "heart.fill")
            }
            .buttonStyle(.feedAction(.like))
            .accessibilityLabel(Text("Нравится"))
        }
        .disabled(isFlying)
        .padding(.bottom, AppTheme.Spacing.m + AppTheme.Spacing.s)
    }
    
    // MARK: - Жесты
    
    /// Перетаскивание верхней карточки.
    /// - Parameter width: ширина области для анимации улёта.
    /// - Returns: жест; по отпусканию карточка улетает или возвращается пружиной.
    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isFlying else { return }
                
                dragOffset = CGSize(width: value.translation.width, height: value.translation.height * 0.3)
            }
            .onEnded { value in
                guard !isFlying else { return }
                
                let translation = value.translation.width
                let projected = value.predictedEndTranslation.width
                
                if abs(translation) > swipeThreshold {
                    swipe(liked: translation > 0, width: width)
                } else if abs(projected) > swipeThreshold * 2 {
                    swipe(liked: projected > 0, width: width)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                }
            }
    }
    
    /// Уводит верхнюю карточку за край, затем сообщает модели о свайпе.
    /// - Parameters:
    ///   - liked: `true` — вправо (лайк), `false` — влево (дизлайк).
    ///   - width: ширина области, чтобы карточка улетела за экран.
    private func swipe(liked: Bool, width: CGFloat) {
        guard !isFlying, !viewModel.visibleCards.isEmpty else { return }
        
        isFlying = true
        let direction: CGFloat = liked ? 1 : -1
        
        withAnimation(.easeIn(duration: 0.22)) {
            dragOffset = CGSize(width: direction * width * 1.4, height: dragOffset.height)
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            
            withTransaction(transaction) {
                if liked {
                    viewModel.like()
                } else {
                    viewModel.dislike()
                }
                dragOffset = .zero
                isFlying = false
            }
        }
    }
}

// MARK: - Заглушка для превью

/// Заглушка модели ленты для превью: данные фиксированные, свайп просто убирает карточку.
@MainActor
@Observable
final class FeedViewModelStub {
    var state: FeedState
    var visibleCards: [FeedCardViewModel]
    var swipeErrorMessage: String?
    
    /// - Parameters:
    ///   - state: состояние экрана.
    ///   - cards: карточки стопки.
    ///   - swipeErrorMessage: текст ошибки свайпа или `nil`.
    init(
        state: FeedState = .ready,
        cards: [FeedCardViewModel] = FeedViewModelStub.sampleCards,
        swipeErrorMessage: String? = nil
    ) {
        self.state = state
        self.visibleCards = cards
        self.swipeErrorMessage = swipeErrorMessage
    }
    
    /// Пример карточек для превью (фото-заглушки без ссылок).
    static let sampleCards: [FeedCardViewModel] = [
        FeedCardViewModel(id: UUID(), title: "Алина, 26", bio: "Люблю горы и кофе", photoCount: 3, photoURLs: []),
        FeedCardViewModel(id: UUID(), title: "Мария, 24", bio: nil, photoCount: 1, photoURLs: []),
        FeedCardViewModel(id: UUID(), title: "Дана, 28", bio: "Путешествия и книги", photoCount: 2, photoURLs: [])
    ]
}

extension FeedViewModelStub: FeedViewModelProtocol {
    
    func load() async {}
    
    func reload() async {}
    
    func like() {
        if !visibleCards.isEmpty { visibleCards.removeFirst() }
    }
    
    func dislike() {
        if !visibleCards.isEmpty { visibleCards.removeFirst() }
    }
    
    func dismissSwipeError() {
        swipeErrorMessage = nil
    }
}

#Preview("Лента") {
    FeedView(viewModel: FeedViewModelStub())
}

#Preview("Лента: пусто") {
    FeedView(viewModel: FeedViewModelStub(state: .empty, cards: []))
}

#Preview("Лента: ошибка") {
    FeedView(viewModel: FeedViewModelStub(state: .failed("Не удалось загрузить ленту. Проверьте соединение."), cards: []))
}
