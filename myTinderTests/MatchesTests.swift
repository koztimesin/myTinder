import Foundation
import Testing
@testable import myTinder

@Suite("Matches store")
@MainActor
struct MatchesStoreTests {
    @Test
    func firstLoadDoesNotCelebrateButNewIDsAreQueuedInServerOrder() async {
        let first = TestFixtures.match()
        let second = TestFixtures.match(id: UUID(), partnerID: UUID())
        let third = TestFixtures.match(id: UUID(), partnerID: UUID())
        let repository = MatchRepositoryStub(fetchResults: [
            .success([first]),
            .success([second, first, third])
        ])
        let store = MatchesStore(repository: repository)

        await store.reload()
        #expect(store.celebrations.isEmpty)

        await store.reload()
        #expect(store.matches.map(\.id) == [second.id, first.id, third.id])
        #expect(store.celebrations.map(\.id) == [second.id, third.id])

        store.dismissCelebration(id: third.id)
        #expect(store.currentCelebration?.id == second.id)
        store.dismissCelebration(id: second.id)
        #expect(store.currentCelebration?.id == third.id)
    }

    @Test
    func computesUnreadTotalAndPreservesLoadedContentOnError() async {
        let first = TestFixtures.match(unreadCount: 2)
        let second = TestFixtures.match(id: UUID(), partnerID: UUID(), unreadCount: 3)
        let repository = MatchRepositoryStub(fetchResults: [
            .success([first, second]),
            .failure(TestFailure.expected)
        ])
        let store = MatchesStore(repository: repository)

        await store.reload()
        #expect(store.unreadTotal == 5)
        await store.reload()

        #expect(store.matches.map(\.id) == [first.id, second.id])
        #expect(store.errorMessage != nil)
        #expect(store.isLoaded)
    }

    @Test
    func concurrentReloadsCoalesceIntoOneFollowUpRequest() async {
        let repository = ControlledMatchRepository()
        let store = MatchesStore(repository: repository)

        let firstReload = Task { await store.reload() }
        #expect(await eventually { repository.fetchCount == 1 })

        await store.reload()
        #expect(repository.fetchCount == 1)

        repository.resumeNext(with: [])
        #expect(await eventually { repository.fetchCount == 2 })
        repository.resumeNext(with: [TestFixtures.match()])
        await firstReload.value

        #expect(store.matches.map(\.id) == [TestFixtures.matchID])
        #expect(repository.fetchCount == 2)
    }
}

@Suite("Matches presentation")
@MainActor
struct MatchesViewModelTests {
    @Test
    func separatesNewMatchesFromDialogsAndPrefixesOwnMessage() async {
        let newMatch = TestFixtures.match()
        let dialog = TestFixtures.match(
            id: UUID(),
            partnerID: UUID(),
            message: LastMessage(body: "Привет", sentAt: .now, isFromMe: true),
            unreadCount: 2
        )
        let repository = MatchRepositoryStub(fetchResults: [.success([newMatch, dialog])])
        let store = MatchesStore(repository: repository)
        await store.reload()
        let viewModel = MatchesViewModel(
            store: store,
            photoURLProvider: PhotoURLProviderStub(),
            onOpenFeed: {},
            onSelectMatch: { _ in }
        )

        #expect(viewModel.state == MatchesScreenState.content)
        #expect(viewModel.newItems.map(\.id) == [newMatch.id])
        #expect(viewModel.dialogRows.map(\.id) == [dialog.id])
        #expect(viewModel.dialogRows.first?.preview == "Вы: Привет")
        #expect(viewModel.dialogRows.first?.unreadCount == 2)
    }
}
