//
//  FeedCardView.swift
//  myTinder
//
//  Created by Ismail on 27.10.2026.
//

import SwiftUI

extension FeedCardViewModel {
    
    /// Сколько полосок показывать вверху: по готовым ссылкам, а пока они грузятся, по числу фото.
    var indicatorCount: Int {
        photoURLs.isEmpty ? max(photoCount, 1) : photoURLs.count
    }
}

/// Карточка анкеты. Раскрывается на месте: фото сжимается вверх, снизу подъезжает шторка
/// с именем и «О себе». Степень раскрытия задаёт `expansion`, поэтому ленту можно вести пальцем.
struct FeedCardView: View {
    
    /// Высота полоски индикатора. Нужна и ленте, чтобы разместить кнопки под полосками.
    static let indicatorHeight: CGFloat = 4
    
    let viewModel: FeedCardViewModel
    /// Раскрытие карточки: 0 — карточка, 1 — анкета.
    let expansion: CGFloat
    /// Отступ под статус-бар; нужен, когда карточка раскрыта на весь экран.
    let topInset: CGFloat
    
    /// Индекс показанного фото (локальное состояние интерфейса).
    @State private var photoIndex = 0
    
    /// Доля высоты карточки под фото в раскрытом виде.
    private let expandedPhotoRatio: CGFloat = 0.55
    /// Место справа под кнопку открытия анкеты: отступ, кнопка 44 pt, зазор.
    private let openButtonReserve: CGFloat = AppTheme.Spacing.m + 44 + AppTheme.Spacing.s
    
    /// - Parameters:
    ///   - viewModel: модель карточки.
    ///   - expansion: раскрытие от 0 до 1 (по умолчанию карточка свёрнута).
    ///   - topInset: отступ под статус-бар (по умолчанию 0).
    init(viewModel: FeedCardViewModel, expansion: CGFloat = 0, topInset: CGFloat = 0) {
        self.viewModel = viewModel
        self.expansion = expansion
        self.topInset = topInset
    }
    
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let progress = expansion
            let photoHeight = height * (1 - (1 - expandedPhotoRatio) * progress)
            let sheetHeight = height * (1 - expandedPhotoRatio) + AppTheme.Radius.card
            
            ZStack(alignment: .bottom) {
                photoBlock(width: width, height: photoHeight)
                    .frame(width: width, height: height, alignment: .top)
                
                caption
                    .opacity(Double(1 - min(progress * 2, 1)))
                
                sheet
                    .frame(width: width, height: sheetHeight)
                    .offset(y: (1 - progress) * sheetHeight)
                    .allowsHitTesting(progress > 0.99)
            }
            .frame(width: width, height: height)
        }
        .background(AppTheme.Colors.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.photoCard * (1 - expansion), style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityValue(Text("Фото \(currentIndex + 1) из \(viewModel.indicatorCount)"))
        .accessibilityHint(Text("Проведите вверх или вниз, чтобы листать фото"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: showNextPhoto()
            case .decrement: showPreviousPhoto()
            @unknown default: break
            }
        }
    }
    
    // MARK: - Части карточки
    
    /// Фото с полосками сверху.
    /// - Parameters:
    ///   - width: ширина карточки.
    ///   - height: текущая высота фото (уменьшается при раскрытии).
    private func photoBlock(width: CGFloat, height: CGFloat) -> some View {
        photoLayer(width: width, height: height)
            .overlay(alignment: .top) { indicators }
    }
    
    /// Фото с обработкой тапов по краям.
    /// - Parameters:
    ///   - width: ширина карточки.
    ///   - height: текущая высота фото.
    private func photoLayer(width: CGFloat, height: CGFloat) -> some View {
        photo
            .frame(width: width, height: height)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture(count: 1, coordinateSpace: .local) { location in
                if location.x < width * 0.4 {
                    showPreviousPhoto()
                } else {
                    showNextPhoto()
                }
            }
    }
    
    /// Текущее фото или заглушка, пока ссылки не получены.
    @ViewBuilder
    private var photo: some View {
        if let url = currentURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    placeholder(systemImage: "photo")
                default:
                    placeholder(systemImage: nil)
                }
            }
            .id(url)
        } else {
            placeholder(systemImage: nil)
        }
    }
    
    /// Заглушка: индикатор загрузки или иконка ошибки.
    /// - Parameter systemImage: имя SF Symbol; `nil` показывает индикатор загрузки.
    /// - Returns: вью-заглушка на всю карточку.
    private func placeholder(systemImage: String?) -> some View {
        ZStack {
            AppTheme.Colors.surfaceMuted
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            } else {
                ProgressView().tint(AppTheme.Colors.accent)
            }
        }
    }
    
    /// Полоски над фото: сколько фото и какое показано. В раскрытом виде опускаются под статус-бар.
    @ViewBuilder
    private var indicators: some View {
        if viewModel.indicatorCount > 1 {
            HStack(spacing: AppTheme.Spacing.xs) {
                ForEach(0..<viewModel.indicatorCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(index == currentIndex ? 1 : 0.4))
                        .frame(height: Self.indicatorHeight)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.top, AppTheme.Spacing.m + topInset * expansion)
            .accessibilityHidden(true)
        }
    }
    
    /// Имя, возраст и описание на градиенте. Снизу оставлено место под кнопки ленты.
    private var caption: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(viewModel.title)
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(Color.white)
            if let bio = viewModel.bio, !bio.isEmpty {
                Text(bio)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(Color.white.opacity(0.9))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, AppTheme.Spacing.m)
        .padding(.trailing, openButtonReserve)
        .padding(.top, AppTheme.Spacing.xl * 2)
        .padding(.bottom, AppTheme.Size.likeButton + AppTheme.Spacing.l + AppTheme.Spacing.m)
        .background(AppTheme.Colors.photoGradient)
        .allowsHitTesting(false)
    }
    
    /// Шторка анкеты: имя, возраст и «О себе». Прокручивается, снизу оставлено место под кнопки ленты.
    private var sheet: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: AppTheme.Radius.card,
            topTrailingRadius: AppTheme.Radius.card,
            style: .continuous
        )
        
        return ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                Text(viewModel.title)
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                if let bio = viewModel.bio, !bio.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                        Text("О себе")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        
                        Text(bio)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.top, AppTheme.Spacing.l)
            .padding(.bottom, AppTheme.Size.likeButton + AppTheme.Spacing.l + AppTheme.Spacing.m + AppTheme.Spacing.s)
        }
        .background(AppTheme.Colors.background, in: shape)
        .clipShape(shape)
    }
    
    // MARK: - Логика
    
    /// Индекс, ограниченный числом готовых фото.
    private var currentIndex: Int {
        min(photoIndex, max(viewModel.photoURLs.count - 1, 0))
    }
    
    /// Ссылка на показанное фото, если ссылки уже получены.
    private var currentURL: URL? {
        viewModel.photoURLs.indices.contains(currentIndex) ? viewModel.photoURLs[currentIndex] : nil
    }
    
    /// Текст для VoiceOver: имя, возраст и описание.
    private var accessibilityText: String {
        [viewModel.title, viewModel.bio].compactMap { $0 }.joined(separator: ". ")
    }
    
    /// Переключает на следующее фото, если оно есть.
    private func showNextPhoto() {
        photoIndex = min(currentIndex + 1, max(viewModel.photoURLs.count - 1, 0))
    }
    
    /// Переключает на предыдущее фото, если оно есть.
    private func showPreviousPhoto() {
        photoIndex = max(currentIndex - 1, 0)
    }
}

#Preview("Карточка") {
    FeedCardView(
        viewModel: FeedCardViewModel(
            id: UUID(),
            title: "Алина, 26",
            bio: "Люблю горы, кофе и долгие прогулки",
            photoCount: 3,
            photoURLs: []
        )
    )
    .padding(AppTheme.Spacing.s)
    .background(AppTheme.Colors.background)
}

#Preview("Карточка: раскрыта") {
    FeedCardView(
        viewModel: FeedCardViewModel(
            id: UUID(),
            title: "Алина, 26",
            bio: "Люблю горы, кофе и долгие прогулки. Ищу того, с кем можно молчать так же хорошо, как разговаривать.",
            photoCount: 3,
            photoURLs: []
        ),
        expansion: 1
    )
    .background(AppTheme.Colors.background)
}
