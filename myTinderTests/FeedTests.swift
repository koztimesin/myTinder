import Foundation
import Testing
@testable import myTinder

@Suite("Feed use case")
@MainActor
struct FeedUseCaseTests {
    @Test
    func removesDuplicatesUntilResetAndForwardsSwipe() async throws {
        let profile = TestFixtures.profile()
        let repository = FeedRepositoryStub(results: [.success([profile]), .success([profile]), .success([profile])])
        let useCase = FeedUseCase(repository: repository)

        let first = try await useCase.loadNextBatch()
        let second = try await useCase.loadNextBatch()
        try await useCase.swipe(on: first[0], liked: true)
        useCase.reset()
        let afterReset = try await useCase.loadNextBatch()

        #expect(first.map(\.id) == [profile.id])
        #expect(second.isEmpty)
        #expect(afterReset.map(\.id) == [profile.id])
        #expect(repository.swipes.count == 1)
        #expect(repository.swipes.first?.0 == profile.id)
        #expect(repository.swipes.first?.1 == true)
    }
}

@Suite("Feed view model")
@MainActor
struct FeedViewModelTests {
    @Test
    func representsLoadedEmptyAndFailedStates() async {
        let loaded = makeFeedViewModel(useCase: FeedUseCaseStub(batches: [.success([TestFixtures.card()])]))
        await loaded.load()
        #expect(loaded.state == .ready)
        #expect(loaded.visibleCards.map(\.id) == [TestFixtures.partnerID])

        let empty = makeFeedViewModel(useCase: FeedUseCaseStub(batches: [.success([])]))
        await empty.load()
        #expect(empty.state == .empty)

        let failed = makeFeedViewModel(useCase: FeedUseCaseStub(batches: [.failure(TestFailure.expected)]))
        await failed.load()
        guard case .failed(let message) = failed.state else {
            Issue.record("Expected failed feed")
            return
        }
        #expect(message.contains("Не удалось загрузить ленту"))
    }

    @Test
    func successfulSwipeRemovesCardAndRefillsQueue() async {
        let first = TestFixtures.card()
        let second = TestFixtures.card(id: UUID())
        let useCase = FeedUseCaseStub(batches: [.success([first]), .success([second])])
        let viewModel = makeFeedViewModel(useCase: useCase)
        await viewModel.load()

        viewModel.like()

        #expect(await eventually { useCase.swipes.count == 1 && viewModel.visibleCards.first?.id == second.id })
        #expect(useCase.swipes.first?.0 == first.id)
        #expect(useCase.swipes.first?.1 == true)
        #expect(viewModel.swipeErrorMessage == nil)
    }

    @Test
    func failedSwipeDuringReloadRestoresOnlyOneCard() async {
        let card = TestFixtures.card()
        let useCase = ControlledFeedUseCase(card: card)
        let viewModel = makeFeedViewModel(useCase: useCase)

        await viewModel.load()
        viewModel.like()
        #expect(await eventually { useCase.hasPendingSwipe })

        await viewModel.reload()
        useCase.failSwipe()

        #expect(await eventually { viewModel.swipeErrorMessage != nil })
        #expect(viewModel.visibleCards.map(\.id) == [card.id])
    }

    @Test
    func reloadDiscardsResponseFromPreviousGeneration() async {
        let stale = TestFixtures.card()
        let fresh = TestFixtures.card(id: UUID())
        let useCase = ControlledLoadFeedUseCase()
        let viewModel = makeFeedViewModel(useCase: useCase)

        let initialLoad = Task { await viewModel.load() }
        #expect(await eventually { useCase.pendingLoadCount == 1 })

        let reload = Task { await viewModel.reload() }
        #expect(await eventually { useCase.pendingLoadCount == 2 })

        useCase.resumeNext(with: [stale])
        await initialLoad.value
        #expect(viewModel.visibleCards.isEmpty)

        useCase.resumeNext(with: [fresh])
        await reload.value
        #expect(viewModel.visibleCards.map(\.id) == [fresh.id])
    }

    @Test
    func closingNormallyKeepsCardButClosingBlockedCandidateRemovesIt() async {
        let card = TestFixtures.card()
        let moderation = ModerationRepositoryStub()
        let useCase = FeedUseCaseStub(batches: [.success([card]), .success([])])
        let viewModel = makeFeedViewModel(useCase: useCase, moderation: moderation)
        await viewModel.load()

        viewModel.openCandidate(cardID: card.id)
        viewModel.closeCandidate()
        #expect(viewModel.visibleCards.map(\.id) == [card.id])

        viewModel.openCandidate(cardID: card.id)
        await viewModel.candidate?.confirmBlock()
        viewModel.closeCandidate()

        #expect(viewModel.visibleCards.isEmpty)
        #expect(moderation.blockedIDs == [card.id])
        #expect(await eventually { viewModel.state == .empty })
    }
}
