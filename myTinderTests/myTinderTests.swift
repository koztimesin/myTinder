//
//  myTinderTests.swift
//  myTinderTests
//
//  Created by Ismail on 16.10.2026.
//

import Foundation
import Testing
@testable import myTinder

/// Тесты доменной логики ленты.
@MainActor
struct FeedUseCaseTests {

    /// Проверяет, что один профиль не выдаётся дважды, а `reset` начинает новую сессию.
    @Test
    func removesDuplicatesUntilReset() async throws {
        let profile = TestFixtures.profile()
        let repository = FeedRepositoryStub(profiles: [profile])
        let useCase = FeedUseCase(repository: repository)

        let first = try await useCase.loadNextBatch()
        let second = try await useCase.loadNextBatch()
        useCase.reset()
        let afterReset = try await useCase.loadNextBatch()

        #expect(first.map(\.id) == [profile.id])
        #expect(second.isEmpty)
        #expect(afterReset.map(\.id) == [profile.id])
    }
}

/// Тесты конкурентных переходов состояния ленты.
@MainActor
struct FeedViewModelTests {

    /// Незавершённый свайп не должен создать дубль карточки, если во время запроса перезагрузить ленту.
    @Test
    func failedSwipeDuringReloadRestoresOneCard() async {
        let card = FeedCard(profile: TestFixtures.profile())
        let useCase = ControlledFeedUseCase(card: card)
        let moderation = ModerationRepositoryStub()
        let viewModel = FeedViewModel(
            useCase: useCase,
            photoURLProvider: PhotoURLProviderStub(),
            moderation: moderation,
            makeReportViewModel: { userID, name, onFinished in
                ReportViewModel(
                    userID: userID,
                    name: name,
                    repository: moderation,
                    onFinished: onFinished
                )
            }
        )

        await viewModel.load()
        #expect(viewModel.visibleCards.map(\.id) == [card.id])

        viewModel.like()
        #expect(await eventually { useCase.hasPendingSwipe })

        await viewModel.reload()
        useCase.failSwipe()
        #expect(await eventually { viewModel.swipeErrorMessage != nil })

        #expect(viewModel.visibleCards.map(\.id) == [card.id])
    }
}

/// Тесты граничных условий профиля.
@MainActor
struct ProfileValidationTests {

    /// Ровно восемнадцать лет допустимо, а день до дня рождения — нет.
    @Test
    func validatesAdultBoundary() throws {
        let calendar = Calendar.utc
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 7)))
        let exactlyEighteen = try #require(calendar.date(from: DateComponents(year: 2008, month: 11, day: 7)))
        let oneDayTooYoung = try #require(calendar.date(from: DateComponents(year: 2008, month: 11, day: 8)))

        #expect(ProfileValidation.isAdult(birthDate: exactlyEighteen, now: now, calendar: calendar))
        #expect(!ProfileValidation.isAdult(birthDate: oneDayTooYoung, now: now, calendar: calendar))
    }
}

/// Ошибки, которыми управляют тестовые дубли.
private enum TestFailure: Error {
    case swipe
}

/// Фабрика стабильных доменных моделей для тестов.
private enum TestFixtures {

    /// Создаёт валидный профиль с заданным идентификатором.
    static func profile(id: UUID = UUID()) -> Profile {
        Profile(
            id: id,
            name: "Алина",
            birthDate: Date(timeIntervalSince1970: 0),
            bio: "О себе",
            gender: .female,
            interestedIn: [.male],
            photoPaths: ["photo.jpg"]
        )
    }
}

/// Ждёт выполнения условия на главном акторе без блокировки потока.
/// - Parameter condition: проверяемое условие.
/// - Returns: `true`, если условие успело выполниться.
@MainActor
private func eventually(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0..<100 {
        if condition() { return true }
        await Task.yield()
    }
    return false
}

/// Репозиторий, возвращающий один и тот же набор профилей.
@MainActor
private final class FeedRepositoryStub {
    private let profiles: [Profile]

    /// Сохраняет ответ для всех запросов ленты.
    init(profiles: [Profile]) {
        self.profiles = profiles
    }
}

extension FeedRepositoryStub: FeedRepositoryProtocol {
    func fetchFeed(limit: Int) async throws -> [Profile] { profiles }
    func sendSwipe(targetID: UUID, liked: Bool) async throws {}
}

/// Use case с ручным завершением свайпа для воспроизведения гонок.
@MainActor
private final class ControlledFeedUseCase {
    private let card: FeedCard
    private var swipeContinuation: CheckedContinuation<Void, Error>?
    var hasPendingSwipe: Bool { swipeContinuation != nil }

    /// Сохраняет карточку, которую будет возвращать каждая загрузка.
    init(card: FeedCard) {
        self.card = card
    }

    /// Завершает ожидающий свайп ошибкой.
    func failSwipe() {
        swipeContinuation?.resume(throwing: TestFailure.swipe)
        swipeContinuation = nil
    }
}

extension ControlledFeedUseCase: FeedUseCaseProtocol {
    func loadNextBatch() async throws -> [FeedCard] { [card] }

    func swipe(on card: FeedCard, liked: Bool) async throws {
        try await withCheckedThrowingContinuation { continuation in
            swipeContinuation = continuation
        }
    }

    func reset() {}
}

/// Заглушка выдачи signed URL.
private struct PhotoURLProviderStub: PhotoURLProviderProtocol {
    func urls(for paths: [String]) async -> [String: URL] { [:] }
}

/// Заглушка жалоб и блокировки, не выполняющая сетевых операций.
private struct ModerationRepositoryStub: ModerationRepositoryProtocol {
    func report(userID: UUID, category: ReportCategory, details: String?) async throws {}
    func block(userID: UUID) async throws {}
}
