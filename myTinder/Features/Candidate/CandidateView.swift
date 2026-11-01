//
//  CandidateView.swift
//  myTinder
//
//  Created by Ismail on 31.10.2026.
//

import SwiftUI

struct CandidateView<ViewModel: CandidateViewModelProtocol>: View {
    
    @Bindable var viewModel: ViewModel
    
    /// Позиция горизонтальной прокрутки фото (индекс показанного).
    @State private var photoIndex: Int? = 0
    
    /// Высота полоски индикатора.
    private let indicatorHeight: CGFloat = 4
    /// Доля высоты экрана под фото.
    private let photoHeightRatio: CGFloat = 0.62
    /// Размер круглых кнопок поверх фото.
    private let controlSize: CGFloat = 44
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    photoPager
                        .containerRelativeFrame(.vertical) { height, _ in height * photoHeightRatio }
                    
                    infoSheet
                        .padding(.top, -AppTheme.Radius.card)
                }
            }
            .ignoresSafeArea(edges: .top)
            .safeAreaInset(edge: .bottom) { actionBar }
            
            topBar
        }
        .background(AppTheme.Colors.background)
        .accessibilityAction(.escape) { viewModel.close() }
        .task(id: viewModel.errorMessage) {
            guard viewModel.errorMessage != nil else { return }
            
            try? await Task.sleep(for: .seconds(3))
            viewModel.dismissError()
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
    
    // MARK: - Фото
    
    /// Сколько страниц в прокрутке: по готовым ссылкам, а пока они грузятся, по числу фото.
    private var pageCount: Int {
        viewModel.photoURLs.isEmpty ? max(viewModel.photoCount, 1) : viewModel.photoURLs.count
    }
    
    /// Индекс показанного фото, ограниченный числом страниц.
    private var currentIndex: Int {
        min(max(photoIndex ?? 0, 0), pageCount - 1)
    }
    
    /// Горизонтальная прокрутка фото постранично.
    private var photoPager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0..<pageCount, id: \.self) { index in
                    page(at: index)
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $photoIndex)
        .background(AppTheme.Colors.surfaceMuted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Фотографии"))
        .accessibilityValue(Text("Фото \(currentIndex + 1) из \(pageCount)"))
        .accessibilityHint(Text("Проведите вверх или вниз, чтобы листать фото"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: showPhoto(at: currentIndex + 1)
            case .decrement: showPhoto(at: currentIndex - 1)
            @unknown default: break
            }
        }
    }
    
    /// Одна страница прокрутки: фото или заглушка.
    /// - Parameter index: номер фото.
    private func page(at index: Int) -> some View {
        AppTheme.Colors.surfaceMuted
            .overlay {
                if viewModel.photoURLs.indices.contains(index) {
                    AsyncImage(url: viewModel.photoURLs[index]) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        default:
                            ProgressView().tint(AppTheme.Colors.accent)
                        }
                    }
                } else {
                    ProgressView().tint(AppTheme.Colors.accent)
                }
            }
            .clipped()
    }
    
    /// Переходит к фото с ограничением по границам.
    /// - Parameter index: желаемый номер.
    private func showPhoto(at index: Int) {
        withAnimation {
            photoIndex = min(max(index, 0), pageCount - 1)
        }
    }
    
    // MARK: - Верх
    
    /// Полоски фото, шеврон закрытия и меню «⋯». Закреплены поверх содержимого.
    private var topBar: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            indicators
            
            HStack {
                circleButton(systemImage: "chevron.down", label: "Закрыть анкету") {
                    viewModel.close()
                }
                
                Spacer()
                
                actionsMenu
            }
        }
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.top, AppTheme.Spacing.s)
    }
    
    /// Полоски: сколько фото и какое показано.
    @ViewBuilder
    private var indicators: some View {
        if pageCount > 1 {
            HStack(spacing: AppTheme.Spacing.xs) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(index == currentIndex ? 1 : 0.4))
                        .frame(height: indicatorHeight)
                        .shadow(color: Color.black.opacity(0.3), radius: 2)
                }
            }
            .accessibilityHidden(true)
        }
    }
    
    /// Меню «Пожаловаться» и «Заблокировать».
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
            circleLabel(systemImage: "ellipsis")
        }
        .disabled(viewModel.isBusy)
        .accessibilityLabel("Действия с анкетой")
    }
    
    /// Круглая кнопка поверх фото.
    /// - Parameters:
    ///   - systemImage: имя SF Symbol.
    ///   - label: подпись для VoiceOver.
    ///   - action: действие.
    private func circleButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            circleLabel(systemImage: systemImage)
        }
        .disabled(viewModel.isBusy)
        .accessibilityLabel(Text(label))
    }
    
    /// Внешний вид круглой кнопки: тёмная подложка и стекло, чтобы значок читался на любом фото.
    /// - Parameter systemImage: имя SF Symbol.
    private func circleLabel(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: controlSize, height: controlSize)
            .background(Color.black.opacity(0.35), in: Circle())
            .appGlass(in: Circle())
    }
    
    // MARK: - Шторка
    
    /// Имя, возраст и «О себе» на шторке, наезжающей на фото.
    private var infoSheet: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
            Text(viewModel.title)
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            
            if let bio = viewModel.bio, !bio.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                    Text("О себе")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text(bio)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.top, AppTheme.Spacing.l)
        .padding(.bottom, AppTheme.Spacing.l)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(
            AppTheme.Colors.background,
            in: UnevenRoundedRectangle(
                topLeadingRadius: AppTheme.Radius.card,
                topTrailingRadius: AppTheme.Radius.card,
                style: .continuous
            )
        )
    }
    
    // MARK: - Низ
    
    /// Плашка ошибки и кнопки «Пропустить» и «Нравится», закреплены внизу.
    private var actionBar: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            if let message = viewModel.errorMessage {
                ErrorBannerView(viewModel: ErrorBannerViewModel(message: message))
                    .padding(.horizontal, AppTheme.Spacing.m)
                    .onTapGesture { viewModel.dismissError() }
            }
            
            HStack(spacing: AppTheme.Spacing.l) {
                Button {
                    viewModel.dislike()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.feedAction(.dislike))
                .accessibilityLabel(Text("Пропустить"))
                
                Button {
                    viewModel.like()
                } label: {
                    Image(systemName: "heart.fill")
                }
                .buttonStyle(.feedAction(.like))
                .accessibilityLabel(Text("Нравится"))
            }
            .disabled(viewModel.isBusy)
        }
        .padding(.vertical, AppTheme.Spacing.s)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(
                colors: [AppTheme.Colors.background.opacity(0), AppTheme.Colors.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Заглушка для превью

/// Заглушка модели анкеты для превью и для `FeedViewModelStub`.
@MainActor
@Observable
final class CandidateViewModelStub {
    let id = UUID()
    let title = "Алина, 26"
    let bio: String? = "Люблю горы, кофе и долгие прогулки. Ищу того, с кем можно молчать так же хорошо, как разговаривать."
    let photoURLs: [URL] = []
    let photoCount = 3
    var isBusy = false
    var errorMessage: String?
    var isReportPresented = false
    var isBlockConfirmationPresented = false
    
    /// - Parameter errorMessage: текст ошибки или `nil`.
    init(errorMessage: String? = nil) {
        self.errorMessage = errorMessage
    }
}

extension CandidateViewModelStub: @MainActor CandidateViewModelProtocol {
    var report: ReportViewModel? { nil }
    var blockConfirmationMessage: String { "«Алина» больше не появится в ленте. Блокировку нельзя отменить." }
    
    func like() {}
    func dislike() {}
    func close() {}
    func openReport() { isReportPresented = true }
    func requestBlock() { isBlockConfirmationPresented = true }
    func confirmBlock() async {}
    func dismissError() { errorMessage = nil }
}

#Preview("Анкета") {
    CandidateView(viewModel: CandidateViewModelStub())
}

#Preview("Анкета: тёмная") {
    CandidateView(viewModel: CandidateViewModelStub())
        .preferredColorScheme(.dark)
}

#Preview("Анкета: ошибка") {
    CandidateView(viewModel: CandidateViewModelStub(errorMessage: "Не удалось заблокировать. Проверьте соединение и попробуйте снова."))
}
