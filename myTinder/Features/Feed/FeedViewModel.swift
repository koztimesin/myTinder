//
//  FeedViewModel.swift
//  myTinder
//
//  Created by Ismail on 26.10.2026.
//

import Foundation
import Observation

/// Как создаётся модель жалобы для анкеты: кто, имя, колбэк завершения.
typealias ReportViewModelFactory = @MainActor (
    _ userID: UUID,
    _ name: String,
    _ onFinished: @escaping @MainActor (Bool) -> Void
) -> ReportViewModel

/// Состояние экрана ленты.
enum FeedState: Equatable {
    /// Первая загрузка или ожидание пакета.
    case loading
    /// Есть карточки.
    case ready
    /// Анкеты закончились.
    case empty
    /// Не удалось загрузить; текст для показа.
    case failed(String)
}

/// Модель одной карточки для `FeedCardView`.
struct FeedCardViewModel: Identifiable, Equatable {
    /// Идентификатор профиля.
    let id: UUID
    /// Заголовок вида «Анна, 27».
    let title: String
    /// Описание «о себе».
    let bio: String?
    /// Сколько всего фото (для индикатора, пока ссылки грузятся).
    let photoCount: Int
    /// Готовые signed URL; пусто, пока не получены.
    let photoURLs: [URL]
}

extension FeedCardViewModel {
    /// Собирает модель карточки.
    /// - Parameters:
    ///   - card: данные анкеты.
    ///   - photoURLs: уже полученные ссылки на фото.
    init(card: FeedCard, photoURLs: [URL]) {
        self.init(
            id: card.id,
            title: "\(card.name), \(card.age)",
            bio: card.bio,
            photoCount: card.photoPaths.count,
            photoURLs: photoURLs
        )
    }
}

/// Всё, с чем работает `FeedView`.
@MainActor
protocol FeedViewModelProtocol: AnyObject, Observable {
    
    /// Модель анкеты кандидата.
    associatedtype Candidate: CandidateViewModelProtocol

    /// Открытая анкета, `nil` если не открыта.
    var candidate: Candidate? { get }
    /// Открывает анкету карточки; игнорируется, если анкета уже открыта или карточки нет в очереди.
    func openCandidate(cardID: UUID)
    /// Сбрасывает анкету (вызывается, когда SwiftUI закрыл её сам).
    func closeCandidate()
    /// Вызывается после закрытия анкеты. Если пользователь заблокировал кандидата,
    /// убирает его карточку из очереди. Если принял решение, возвращает его: свайп
    /// с анимацией запускает экран.
    /// - Returns: решение для свайпа или `nil`.
    func candidateDidDismiss() -> CandidateDecision?
    
    /// Текущее состояние экрана.
    var state: FeedState { get }
    /// Верхние карточки стопки, активная первая.
    var visibleCards: [FeedCardViewModel] { get }
    /// Текст ошибки неудавшегося свайпа, `nil` если ошибки нет.
    var swipeErrorMessage: String? { get }
    /// Первая загрузка; безопасно вызывать повторно.
    func load() async
    /// Сбрасывает ленту и грузит заново.
    func reload() async
    /// Лайк верхней карточки.
    func like()
    /// Дизлайк верхней карточки.
    func dislike()
    /// Скрывает ошибку свайпа.
    func dismissSwipeError()
}

/// Модель экрана ленты: очередь анкет, предзагрузка, оптимистичные свайпы.
@MainActor
@Observable
final class FeedViewModel {
    
    /// Чем закончилась анкета; применяется после закрытия, чтобы zoom-переход шёл к существующей карточке.
    private enum CandidateOutcome {
        case decision(CandidateDecision)
        case blocked(UUID)
    }

    private(set) var candidate: CandidateViewModel?
    @ObservationIgnored private var pendingOutcome: CandidateOutcome?
    @ObservationIgnored private let moderation: any ModerationRepositoryProtocol
    @ObservationIgnored private let makeReportViewModel: ReportViewModelFactory
    
    private(set) var state: FeedState = .loading
    private(set) var swipeErrorMessage: String?
    
    /// Очередь анкет, активная первая.
    private var queue: [FeedCard] = []
    /// Готовые ссылки на фото по идентификатору анкеты.
    private var photoURLs: [UUID: [URL]] = [:]
    /// Может ли сервер ещё что-то выдать.
    private var hasMore = true
    /// Идёт ли загрузка пакета.
    private var isLoadingBatch = false
    /// Номер «поколения» ленты; растёт при `reload`, чтобы отбросить устаревшие ответы.
    private var generation = 0
    
    @ObservationIgnored private let useCase: any FeedUseCaseProtocol
    @ObservationIgnored private let photoURLProvider: any PhotoURLProviderProtocol
    /// Сколько верхних карточек показывать в стопке.
    @ObservationIgnored private let visibleCount = 3
    /// Когда в очереди остаётся столько анкет или меньше, грузим следующий пакет.
    @ObservationIgnored private let refillThreshold = 5
    
    /// - Parameters:
    ///   - useCase: подготовка ленты и отправка свайпов.
    ///   - photoURLProvider: источник signed URL (кэш из этапа 2).
    init(
        useCase: FeedUseCaseProtocol,
        photoURLProvider: PhotoURLProviderProtocol,
        moderation: ModerationRepositoryProtocol,
        makeReportViewModel: @escaping ReportViewModelFactory
    ) {
        self.useCase = useCase
        self.photoURLProvider = photoURLProvider
        self.moderation = moderation
        self.makeReportViewModel = makeReportViewModel
    }
    
    var visibleCards: [FeedCardViewModel] {
        queue.prefix(visibleCount).map {
            FeedCardViewModel(card: $0, photoURLs: photoURLs[$0.id] ?? [])
        }
    }
    
    func load() async {
        guard queue.isEmpty, hasMore else { return }
        await fetchNextBatch()
    }
    
    func reload() async {
        generation += 1
        isLoadingBatch = false
        candidate = nil
        pendingOutcome = nil
        useCase.reset()
        queue = []
        photoURLs = [:]
        hasMore = true
        state = .loading
        await fetchNextBatch()
    }
    
    func like() { swipe(liked: true) }
    
    func dislike() { swipe(liked: false) }
    
    func dismissSwipeError() { swipeErrorMessage = nil }
    
    // MARK: - Приватная логика
    
    /// Убирает верхнюю карточку и отправляет свайп в фоне.
    /// - Parameter liked: `true` — лайк, `false` — дизлайк.
    private func swipe(liked: Bool) {
        guard let card = queue.first else { return }
        queue.removeFirst()
        photoURLs[card.id] = nil
        swipeErrorMessage = nil
        updateState()
        Task { await send(card, liked: liked) }
        Task { await refill() }
    }
    
    /// Отправляет свайп; при сбое возвращает карточку наверх и показывает ошибку.
    private func send(_ card: FeedCard, liked: Bool) async {
        do {
            try await useCase.swipe(on: card, liked: liked)
        } catch {
            queue.insert(card, at: 0)
            updateState()
            swipeErrorMessage = "Не удалось сохранить выбор. Попробуйте ещё раз."
            await resolveVisiblePhotos()
        }
    }
    
    /// Подгружает пакет, если очередь заканчивается, и готовит фото верхних карточек.
    private func refill() async {
        if hasMore, queue.count <= refillThreshold {
            await fetchNextBatch()
        }
        await resolveVisiblePhotos()
    }
    
    /// Загружает следующий пакет и добавляет его в очередь.
    private func fetchNextBatch() async {
        guard hasMore, !isLoadingBatch else { return }
        isLoadingBatch = true
        let currentGeneration = generation
        defer { if currentGeneration == generation { isLoadingBatch = false } }
        do {
            let batch = try await useCase.loadNextBatch()
            guard currentGeneration == generation else { return }
            if batch.isEmpty {
                hasMore = false
            } else {
                queue.append(contentsOf: batch)
            }
            updateState()
            await resolveVisiblePhotos()
        } catch {
            guard currentGeneration == generation, !Task.isCancelled else { return }
            // Если карточки ещё есть, ошибка не мешает: повторим при следующем свайпе.
            if queue.isEmpty {
                state = .failed("Не удалось загрузить ленту. Проверьте соединение.")
            }
        }
    }
    
    /// Выставляет состояние по очереди и признаку «есть ещё».
    private func updateState() {
        if !queue.isEmpty {
            state = .ready
        } else {
            state = hasMore ? .loading : .empty
        }
    }
    
    /// Получает ссылки на фото для верхних карточек, у которых их ещё нет.
    /// Все пути уходят в провайдер одним вызовом.
    private func resolveVisiblePhotos() async {
        let pending = queue.prefix(visibleCount).filter { photoURLs[$0.id] == nil }
        
        guard !pending.isEmpty else { return }
        
        let urlsByPath = await photoURLProvider.urls(for: pending.flatMap(\.photoPaths))
        
        for card in pending {
            // Карточку могли свайпнуть, пока шёл запрос.
            guard queue.contains(where: { $0.id == card.id }) else { continue }
            
            let urls = card.photoPaths.compactMap { urlsByPath[$0] }
            // Пустой результат не сохраняем: при следующем пополнении попробуем снова (например, вернулась сеть).
            if !urls.isEmpty {
                photoURLs[card.id] = urls
            }
        }
    }
}

extension FeedViewModel: @MainActor FeedViewModelProtocol {
    
    func openCandidate(cardID: UUID) {
        guard candidate == nil, let card = queue.first(where: { $0.id == cardID }) else { return }
        
        let factory = makeReportViewModel
        candidate = CandidateViewModel(
            card: card,
            photoURLs: photoURLs[card.id] ?? [],
            moderation: moderation,
            makeReportViewModel: { onFinished in factory(card.id, card.name, onFinished) },
            onDecision: { [weak self] in self?.finishCandidate(.decision($0)) },
            onClose: { [weak self] in self?.candidate = nil },
            onBlocked: { [weak self] in self?.finishCandidate(.blocked(card.id)) }
        )
    }

    func closeCandidate() { candidate = nil }

    func candidateDidDismiss() -> CandidateDecision? {
        guard let outcome = pendingOutcome else { return nil }
        
        pendingOutcome = nil
        switch outcome {
        case .decision(let decision):
            return decision
        case .blocked(let id):
            removeCard(id: id)
            return nil
        }
    }

    /// Запоминает итог и закрывает анкету.
    /// - Parameter outcome: решение или блокировка.
    private func finishCandidate(_ outcome: CandidateOutcome) {
        pendingOutcome = outcome
        candidate = nil
    }

    /// Убирает карточку заблокированного кандидата без запроса свайпа.
    /// - Parameter id: идентификатор анкеты.
    private func removeCard(id: UUID) {
        guard queue.contains(where: { $0.id == id }) else { return }
        
        queue.removeAll { $0.id == id }
        photoURLs[id] = nil
        updateState()
        Task { await refill() }
    }
}
