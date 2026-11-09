//
//  FeedView.swift
//  myTinder
//
//  Created by Ismail on 27.10.2026.
//

import SwiftUI

struct FeedView<ViewModel: FeedViewModelProtocol>: View {
    
    /// Ось, по которой пошло перетаскивание: выбирается один раз в начале жеста.
    private enum DragAxis {
        /// Свайп карточки (лайк или дизлайк).
        case horizontal
        /// Раскрытие и сворачивание анкеты.
        case vertical
    }
    
    /// Модель экрана.
    @State private var viewModel: ViewModel
    /// Главное фото текущего пользователя для кнопки профиля.
    let profilePhotoURL: URL?
    /// Открывает фильтры выдачи.
    let onOpenFilters: @MainActor () -> Void
    /// Переключает на вкладку профиля.
    let onOpenProfile: @MainActor () -> Void
    /// Смещение верхней карточки при перетаскивании.
    @State private var dragOffset: CGSize = .zero
    /// Летит ли карточка прочь: на это время новые жесты и нажатия игнорируются.
    @State private var isFlying = false
    /// Раскрытие анкеты верхней карточки: 0 — карточка, 1 — анкета на весь экран.
    @State private var expansion: CGFloat = 0
    /// Раскрытие на момент начала вертикального перетаскивания.
    @State private var expansionDragStart: CGFloat?
    /// Ось текущего перетаскивания.
    @State private var dragAxis: DragAxis?
    /// Сворачивается ли анкета: на это время жесты и кнопки игнорируются.
    @State private var isCollapsing = false
    /// Убирает декоративное движение, если пользователь включил системную настройку.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    /// Смещение, после которого отпускание засчитывается как свайп.
    private let swipeThreshold: CGFloat = 110
    /// Сколько карточек видно в стопке.
    private let stackDepth = 3
    /// Максимальная непрозрачность цветной подсветки (при смещении от порога и дальше).
    private let maxTintOpacity: Double = 0.3
    /// Сколько точек протягивания соответствует полному раскрытию.
    private let expansionDragRange: CGFloat = 320
    /// Размер круглых кнопок поверх фото.
    private let circleControlSize: CGFloat = 44
    /// Пружина раскрытия и сворачивания.
    private let expandAnimation = Animation.spring(response: 0.5, dampingFraction: 0.85)
    
    /// - Parameters:
    ///   - viewModel: модель экрана, собирается снаружи (`AppContainer.makeFeedViewModel()`).
    ///   - profilePhotoURL: главное фото текущего пользователя.
    ///   - onOpenFilters: открывает модальную шторку фильтров.
    ///   - onOpenProfile: открывает профиль.
    init(
        viewModel: ViewModel,
        profilePhotoURL: URL? = nil,
        onOpenFilters: @escaping @MainActor () -> Void = {},
        onOpenProfile: @escaping @MainActor () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.profilePhotoURL = profilePhotoURL
        self.onOpenFilters = onOpenFilters
        self.onOpenProfile = onOpenProfile
    }
    
    var body: some View {
        GeometryReader { proxy in
            // Здесь safe area ещё учтён, поэтому отступ статус-бара настоящий.
            let insets = proxy.safeAreaInsets
            let size = CGSize(width: proxy.size.width, height: proxy.size.height + insets.top)
            
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                content(size: size, insets: insets)
                    .padding(.top, viewModel.state == .ready ? 0 : insets.top)
            }
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .top) {
                errorBanner
                    .padding(.top, insets.top)
            }
            .overlay(alignment: .top) {
                if expansion < 0.5 {
                    feedHeader
                        .padding(.top, insets.top + AppTheme.Spacing.s)
                        .padding(.horizontal, AppTheme.Spacing.m)
                        .transition(.opacity)
                }
            }
            // Поднимаем область к верхнему краю экрана: раскрытая карточка уходит под статус-бар.
            .offset(y: -insets.top)
        }
        .alert(
            "Заблокировать пользователя?",
            isPresented: isBlockConfirmationPresented
        ) {
            Button("Отмена", role: .cancel) {}
            Button("Заблокировать", role: .destructive) {
                Task { await viewModel.candidate?.confirmBlock() }
            }
        } message: {
            Text(viewModel.candidate?.blockConfirmationMessage ?? "")
        }
        .sheet(isPresented: isReportPresented) {
            if let report = viewModel.candidate?.report {
                ReportView(viewModel: report)
            }
        }
        .task { await viewModel.load() }
        .task(id: viewModel.swipeErrorMessage) {
            guard viewModel.swipeErrorMessage != nil else { return }
            
            try? await Task.sleep(for: .seconds(3))
            viewModel.dismissSwipeError()
        }
        .task(id: viewModel.candidate?.errorMessage) {
            guard viewModel.candidate?.errorMessage != nil else { return }
            
            try? await Task.sleep(for: .seconds(3))
            viewModel.candidate?.dismissError()
        }
        // Пользователь заблокирован: сворачиваем анкету, карточку уберёт `closeCandidate()`.
        .onChange(of: viewModel.candidate?.didBlock ?? false) { _, didBlock in
            if didBlock { collapse() }
        }
        // Модель анкеты сбросили снаружи (например, «Обновить»): возвращаем карточку в исходный вид.
        .onChange(of: viewModel.candidate?.id) { _, id in
            if id == nil, expansion > 0, !isCollapsing { expansion = 0 }
        }
        // Верхняя карточка сменилась, пока анкета открыта (например, после сбоя свайпа): закрываем анкету.
        .onChange(of: viewModel.visibleCards.first?.id) { _, topID in
            if let candidate = viewModel.candidate, candidate.id != topID {
                viewModel.closeCandidate()
            }
        }
    }

    /// Заголовок ленты с фильтрами и быстрым переходом в профиль.
    private var feedHeader: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            Text("myTinder")
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Spacer()

            Button(action: onOpenFilters) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .frame(width: AppTheme.Size.minTapTarget, height: AppTheme.Size.minTapTarget)
                    .background(AppTheme.Colors.surface, in: Circle())
            }
            .accessibilityLabel("Открыть фильтры")

            Button(action: onOpenProfile) {
                AsyncImage(url: profilePhotoURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        AppTheme.Colors.surfaceMuted
                            .overlay {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(AppTheme.Colors.secondaryAccent)
                            }
                    }
                }
                .frame(width: AppTheme.Size.minTapTarget, height: AppTheme.Size.minTapTarget)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.Colors.accent, lineWidth: 2))
            }
            .accessibilityLabel("Открыть профиль")
        }
        .padding(AppTheme.Spacing.s)
        .background(AppTheme.Colors.background.opacity(0.9), in: Capsule())
    }
    
    // MARK: - Состояния
    
    /// Содержимое по состоянию модели.
    /// - Parameters:
    ///   - size: размер области вместе с верхним safe area.
    ///   - insets: отступы safe area.
    @ViewBuilder
    private func content(size: CGSize, insets: EdgeInsets) -> some View {
        switch viewModel.state {
        case .loading:
            LoadingIndicatorView(viewModel: LoadingIndicatorViewModel(title: "Загружаем анкеты"))
        case .ready:
            cardStack(size: size, insets: insets)
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
    
    /// Плашка ошибки сверху экрана: сбой блокировки в анкете или неудавшийся свайп.
    @ViewBuilder
    private var errorBanner: some View {
        if let message = viewModel.candidate?.errorMessage ?? viewModel.swipeErrorMessage {
            ErrorBannerView(viewModel: ErrorBannerViewModel(message: message))
                .padding(.horizontal, AppTheme.Spacing.m)
                .padding(.top, AppTheme.Spacing.s)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture {
                    dismissError()
                }
                .accessibilityAction(named: Text("Закрыть сообщение")) { dismissError() }
        }
    }

    /// Закрывает любую временную ошибку ленты или открытой анкеты.
    private func dismissError() {
        viewModel.dismissSwipeError()
        viewModel.candidate?.dismissError()
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
    
    // MARK: - Привязки модерации
    
    /// Привязка к alert блокировки в модели анкеты.
    private var isBlockConfirmationPresented: Binding<Bool> {
        Binding(
            get: { viewModel.candidate?.isBlockConfirmationPresented ?? false },
            set: { viewModel.candidate?.isBlockConfirmationPresented = $0 }
        )
    }
    
    /// Привязка к шторке жалобы в модели анкеты.
    private var isReportPresented: Binding<Bool> {
        Binding(
            get: { viewModel.candidate?.isReportPresented ?? false },
            set: { viewModel.candidate?.isReportPresented = $0 }
        )
    }
    
    // MARK: - Стопка карточек
    
    /// Стопка карточек, кнопки поверх фото и элементы раскрытой анкеты.
    /// - Parameters:
    ///   - size: размер области вместе с верхним safe area.
    ///   - insets: отступы safe area.
    private func cardStack(size: CGSize, insets: EdgeInsets) -> some View {
        let cards = Array(viewModel.visibleCards.prefix(stackDepth))
        let progress = expansion
        
        return ZStack {
            ForEach(Array(cards.enumerated()).reversed(), id: \.element.id) { index, card in
                let isTop = index == 0
                FeedCardView(viewModel: card, expansion: isTop ? progress : 0, topInset: insets.top)
                    .overlay { if isTop { swipeTint } }
                    .padding(cardPadding(isTop: isTop, insets: insets))
                    .opacity(isTop ? 1 : Double(1 - progress))
                    .scaleEffect(1 - 0.04 * CGFloat(index))
                    .offset(y: 10 * CGFloat(index))
                    .offset(x: isTop ? dragOffset.width : 0, y: isTop ? dragOffset.height : 0)
                    .rotationEffect(.degrees(isTop ? Double(dragOffset.width / max(size.width, 1)) * 12 : 0))
                    .allowsHitTesting(isTop)
                    .accessibilityHidden(!isTop)
                    .accessibilityAction(named: Text("Нравится")) { if isTop { decide(liked: true, width: size.width) } }
                    .accessibilityAction(named: Text("Пропустить")) { if isTop { decide(liked: false, width: size.width) } }
                    .accessibilityAction(named: Text("Открыть анкету")) { if isTop { expand(cardID: card.id) } }
                    .gesture(dragGesture(width: size.width, cardID: card.id))
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .bottom) { actionButtons(width: size.width) }
        .overlay(alignment: .bottomTrailing) { openButton(cardID: cards.first?.id) }
        .overlay(alignment: .top) { expandedControls(insets: insets) }
        .accessibilityAction(.escape) { if expansion > 0 { collapse() } }
    }
    
    /// Отступы карточки. Нижние карточки всегда вписаны в safe area с отступом,
    /// верхняя по мере раскрытия растёт до краёв области (под статус-бар сверху).
    /// - Parameters:
    ///   - isTop: верхняя ли это карточка.
    ///   - insets: отступы safe area.
    private func cardPadding(isTop: Bool, insets: EdgeInsets) -> EdgeInsets {
        let factor = isTop ? 1 - expansion : 1
        let side = AppTheme.Spacing.s * factor
        
        return EdgeInsets(
            top: (insets.top + AppTheme.Spacing.s) * factor,
            leading: side,
            bottom: side,
            trailing: side
        )
    }
    
    /// Кнопки «Пропустить» и «Нравится» поверх фото. Они же основной способ для VoiceOver.
    /// - Parameter width: ширина области, нужна для анимации улёта карточки.
    private func actionButtons(width: CGFloat) -> some View {
        HStack(spacing: AppTheme.Spacing.l) {
            Button {
                decide(liked: false, width: width)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.feedAction(.dislike))
            .accessibilityLabel(Text("Пропустить"))
            
            Button {
                decide(liked: true, width: width)
            } label: {
                Image(systemName: "heart.fill")
            }
            .buttonStyle(.feedAction(.like))
            .accessibilityLabel(Text("Нравится"))
        }
        .disabled(isFlying || isCollapsing || (viewModel.candidate?.isBusy ?? false))
        .padding(.bottom, AppTheme.Spacing.m + AppTheme.Spacing.s)
    }
    
    // MARK: - Элементы анкеты
    
    /// Стеклянная кнопка со стрелкой вверх: раскрывает анкету. Гаснет по мере раскрытия.
    /// Для VoiceOver есть действие «Открыть анкету», поэтому кнопка скрыта.
    /// - Parameter cardID: идентификатор верхней карточки; `nil`, если карточек нет.
    @ViewBuilder
    private func openButton(cardID: UUID?) -> some View {
        if let cardID {
            Button {
                expand(cardID: cardID)
            } label: {
                circleLabel(systemImage: "arrow.up")
            }
            .opacity(Double(1 - expansion))
            .allowsHitTesting(expansion < 0.01 && !isFlying)
            .padding(.trailing, AppTheme.Spacing.s + AppTheme.Spacing.m)
            .padding(.bottom, AppTheme.Spacing.m + AppTheme.Spacing.s + (AppTheme.Size.likeButton - circleControlSize) / 2)
            .accessibilityHidden(true)
        }
    }
    
    /// Шеврон закрытия и меню «⋯» поверх раскрытой анкеты. Появляются по мере раскрытия.
    /// - Parameter insets: отступы safe area.
    @ViewBuilder
    private func expandedControls(insets: EdgeInsets) -> some View {
        if let candidate = viewModel.candidate {
            HStack {
                Button {
                    collapse()
                } label: {
                    circleLabel(systemImage: "chevron.down")
                }
                .accessibilityLabel(Text("Закрыть анкету"))
                
                Spacer()
                
                actionsMenu(candidate: candidate)
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.top, controlsTopPadding(insets: insets))
            .opacity(Double(expansion))
            .allowsHitTesting(expansion > 0.99 && !isCollapsing)
            .accessibilityHidden(expansion < 0.99)
        }
    }
    
    /// Отступ сверху для шеврона и меню: сразу под полосками фото верхней карточки.
    /// - Parameter insets: отступы safe area.
    private func controlsTopPadding(insets: EdgeInsets) -> CGFloat {
        let cardTop = (insets.top + AppTheme.Spacing.s) * (1 - expansion)
        let indicatorsTop = AppTheme.Spacing.m + insets.top * expansion
        
        return cardTop + indicatorsTop + FeedCardView.indicatorHeight + AppTheme.Spacing.s
    }
    
    /// Меню «Пожаловаться» и «Заблокировать».
    /// - Parameter candidate: модель анкеты.
    private func actionsMenu(candidate: ViewModel.Candidate) -> some View {
        Menu {
            Button {
                candidate.openReport()
            } label: {
                Label("Пожаловаться", systemImage: "exclamationmark.bubble")
            }
            
            Button(role: .destructive) {
                candidate.requestBlock()
            } label: {
                Label("Заблокировать", systemImage: "hand.raised")
            }
        } label: {
            circleLabel(systemImage: "ellipsis")
        }
        .disabled(candidate.isBusy)
        .accessibilityLabel("Действия с анкетой")
    }
    
    /// Внешний вид круглой кнопки: тёмная подложка и стекло, чтобы значок читался на любом фото.
    /// - Parameter systemImage: имя SF Symbol.
    private func circleLabel(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: circleControlSize, height: circleControlSize)
            .background(Color.black.opacity(0.35), in: Circle())
            .appGlass(in: Circle())
    }
    
    // MARK: - Раскрытие
    
    /// Раскрывает анкету карточки; игнорируется во время улёта, сворачивания и перетаскивания.
    /// - Parameter cardID: идентификатор верхней карточки.
    private func expand(cardID: UUID) {
        guard !isFlying, !isCollapsing, dragOffset == .zero else { return }
        
        if viewModel.candidate == nil {
            viewModel.openCandidate(cardID: cardID)
        }
        settleExpanded()
    }
    
    /// Доводит раскрытие до конца пружиной.
    private func settleExpanded() {
        withAnimation(reduceMotion ? nil : expandAnimation) {
            expansion = 1
        }
    }
    
    /// Сворачивает анкету пружиной. По окончании сбрасывает модель анкеты (если пользователь
    /// заблокирован, лента заодно уберёт карточку) и выполняет `action`.
    /// - Parameter action: что сделать после сворачивания (например, свайп).
    private func collapse(then action: (() -> Void)? = nil) {
        guard !isCollapsing else { return }
        guard expansion > 0 else {
            viewModel.closeCandidate()
            action?()
            return
        }
        
        isCollapsing = true
        guard !reduceMotion else {
            expansion = 0
            isCollapsing = false
            viewModel.closeCandidate()
            action?()
            return
        }

        withAnimation(expandAnimation) {
            expansion = 0
        } completion: {
            isCollapsing = false
            viewModel.closeCandidate()
            action?()
        }
    }
    
    /// Ведёт раскрытие за пальцем. Модель анкеты создаётся в начале раскрытия.
    /// - Parameters:
    ///   - translation: вертикальное смещение пальца от начала жеста (вверх — отрицательное).
    ///   - cardID: идентификатор верхней карточки.
    private func dragExpansion(by translation: CGFloat, cardID: UUID) {
        let start = expansionDragStart ?? expansion
        expansionDragStart = start
        let value = min(max(start - translation / expansionDragRange, 0), 1)
        
        if value > 0, viewModel.candidate == nil {
            viewModel.openCandidate(cardID: cardID)
        }
        expansion = value
    }
    
    /// Завершает вертикальное перетаскивание: раскрывает или сворачивает с учётом скорости.
    /// - Parameter predictedTranslation: смещение, к которому палец пришёл бы по инерции.
    private func finishExpansionDrag(predictedTranslation: CGFloat) {
        let start = expansionDragStart ?? expansion
        let predicted = start - predictedTranslation / expansionDragRange
        
        if predicted > 0.5 {
            settleExpanded()
        } else {
            collapse()
        }
    }
    
    // MARK: - Жесты
    
    /// Перетаскивание верхней карточки. В начале выбирается ось: по горизонтали идёт свайп,
    /// по вертикали раскрытие анкеты. Пока анкета раскрыта, работает только вертикаль.
    /// - Parameters:
    ///   - width: ширина области для анимации улёта.
    ///   - cardID: идентификатор карточки, для которой раскрывается анкета.
    private func dragGesture(width: CGFloat, cardID: UUID) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isFlying, !isCollapsing else { return }
                
                if dragAxis == nil {
                    let isVertical = expansion > 0 || abs(value.translation.height) > abs(value.translation.width)
                    dragAxis = isVertical ? .vertical : .horizontal
                }
                
                switch dragAxis {
                case .vertical:
                    dragExpansion(by: value.translation.height, cardID: cardID)
                case .horizontal:
                    dragOffset = CGSize(width: value.translation.width, height: value.translation.height * 0.3)
                case nil:
                    break
                }
            }
            .onEnded { value in
                defer {
                    dragAxis = nil
                    expansionDragStart = nil
                }
                guard !isFlying, !isCollapsing else { return }
                
                switch dragAxis {
                case .vertical:
                    finishExpansionDrag(predictedTranslation: value.predictedEndTranslation.height)
                case .horizontal:
                    finishSwipeDrag(value, width: width)
                case nil:
                    break
                }
            }
    }
    
    /// Завершает горизонтальное перетаскивание: карточка улетает или возвращается пружиной.
    /// - Parameters:
    ///   - value: значение жеста.
    ///   - width: ширина области для анимации улёта.
    private func finishSwipeDrag(_ value: DragGesture.Value, width: CGFloat) {
        let translation = value.translation.width
        let projected = value.predictedEndTranslation.width
        
        if abs(translation) > swipeThreshold {
            swipe(liked: translation > 0, width: width)
        } else if abs(projected) > swipeThreshold * 2 {
            swipe(liked: projected > 0, width: width)
        } else {
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7)) {
                dragOffset = .zero
            }
        }
    }
    
    /// Решение по верхней карточке из кнопок и действий VoiceOver. Если анкета раскрыта,
    /// сначала сворачивает её, потом запускает свайп.
    /// - Parameters:
    ///   - liked: `true` — лайк, `false` — дизлайк.
    ///   - width: ширина области для анимации улёта.
    private func decide(liked: Bool, width: CGFloat) {
        guard !isFlying, !isCollapsing else { return }
        
        if expansion > 0 {
            collapse { swipe(liked: liked, width: width) }
        } else {
            swipe(liked: liked, width: width)
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

        guard !reduceMotion else {
            completeSwipe(liked: liked)
            return
        }
        
        withAnimation(.easeIn(duration: 0.22)) {
            dragOffset = CGSize(width: direction * width * 1.4, height: dragOffset.height)
        } completion: {
            completeSwipe(liked: liked)
        }
    }

    /// Применяет решение по карточке и без анимации возвращает состояние свайпа в исходное.
    /// - Parameter liked: `true` — лайк, `false` — дизлайк.
    private func completeSwipe(liked: Bool) {
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

// MARK: - Заглушка для превью

/// Заглушка модели ленты для превью: данные фиксированные, свайп просто убирает карточку.
@MainActor
@Observable
final class FeedViewModelStub {
    var state: FeedState
    var visibleCards: [FeedCardViewModel]
    var swipeErrorMessage: String?
    var candidate: CandidateViewModelStub?
    
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
    
    func openCandidate(cardID: UUID) {
        candidate = CandidateViewModelStub()
    }
    
    func closeCandidate() {
        candidate = nil
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
