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

struct FeedCardView: View {
    
    let viewModel: FeedCardViewModel
    
    /// Индекс показанного фото (локальное состояние интерфейса).
    @State private var photoIndex = 0
    
    /// Высота полоски индикатора.
    private let indicatorHeight: CGFloat = 4
    
    var body: some View {
        photoLayer
            .overlay(alignment: .top) { indicators }
            .overlay(alignment: .bottom) { caption }
            .background(AppTheme.Colors.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.photoCard, style: .continuous))
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
    
    /// Фото с обработкой тапов по краям.
    private var photoLayer: some View {
        GeometryReader { proxy in
            photo
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture(count: 1, coordinateSpace: .local) { location in
                    if location.x < proxy.size.width * 0.4 {
                        showPreviousPhoto()
                    } else {
                        showNextPhoto()
                    }
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
    
    /// Полоски над фото: сколько фото и какое показано.
    @ViewBuilder
    private var indicators: some View {
        if viewModel.indicatorCount > 1 {
            HStack(spacing: AppTheme.Spacing.xs) {
                ForEach(0..<viewModel.indicatorCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(index == currentIndex ? 1 : 0.4))
                        .frame(height: indicatorHeight)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.top, AppTheme.Spacing.m)
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
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.top, AppTheme.Spacing.xl * 2)
        .padding(.bottom, AppTheme.Size.likeButton + AppTheme.Spacing.l + AppTheme.Spacing.m)
        .background(AppTheme.Colors.photoGradient)
        .allowsHitTesting(false)
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
