import Foundation
import SwiftUI
import Testing
@testable import myTinder

@Suite("Chat view model")
@MainActor
struct ChatViewModelTests {
    @Test
    func loadsSortsAndDeduplicatesMessagesByID() async {
        let duplicatedID = UUID()
        let newer = TestFixtures.message(id: UUID(), body: "Второе", sentAt: Date(timeIntervalSince1970: 2_000))
        let oldVersion = TestFixtures.message(id: duplicatedID, body: "Старое", sentAt: Date(timeIntervalSince1970: 1_000))
        let serverVersion = TestFixtures.message(id: duplicatedID, body: "Обновлённое", sentAt: Date(timeIntervalSince1970: 1_000))
        let repository = ChatRepositoryStub(fetchResults: [.success([newer, oldVersion, serverVersion])])
        let viewModel = makeChatViewModel(repository: repository)

        await viewModel.retryLoad()

        #expect(viewModel.state == .content)
        #expect(viewModel.messageBubblesForTesting.map(\.text) == ["Обновлённое", "Второе"])
        #expect(repository.fetchCalls.first?.1 == 50)
        #expect(repository.markReadCount == 1)
    }

    @Test
    func sendsTrimmedMessageAndSupportsRetryAndDiscardAfterFailure() async {
        let repository = ChatRepositoryStub(fetchResults: [.success([])])
        repository.sendResults = [.failure(TestFailure.expected), .success(())]
        let viewModel = makeChatViewModel(repository: repository)
        await viewModel.retryLoad()

        viewModel.inputBar.text.wrappedValue = "  Привет  "
        viewModel.inputBar.onSend()
        #expect(await eventually { viewModel.messageBubblesForTesting.last?.delivery == .failed })

        var failedBubble = try! #require(viewModel.messageBubblesForTesting.last)
        #expect(failedBubble.text == "Привет")
        #expect(repository.sendCalls.first?.1 == "Привет")

        failedBubble.onRetry()
        #expect(await eventually { viewModel.messageBubblesForTesting.last?.delivery == .sent })
        #expect(repository.sendCalls.count == 2)

        repository.sendResults = [.failure(TestFailure.expected)]
        viewModel.inputBar.text.wrappedValue = "Удалить"
        viewModel.inputBar.onSend()
        #expect(await eventually { viewModel.messageBubblesForTesting.last?.delivery == .failed })
        failedBubble = try! #require(viewModel.messageBubblesForTesting.last)
        failedBubble.onDiscard()
        #expect(!viewModel.messageBubblesForTesting.contains { $0.text == "Удалить" })
    }

    @Test
    func limitsDraftToDatabaseMaximum() async {
        let repository = ChatRepositoryStub(fetchResults: [.success([])])
        let viewModel = makeChatViewModel(repository: repository)
        await viewModel.retryLoad()

        viewModel.inputBar.text.wrappedValue = String(repeating: "а", count: 2_100)

        #expect(viewModel.inputBar.text.wrappedValue.count == 2_000)
        #expect(viewModel.inputBar.canSend)
    }

    @Test
    func paginatesFromOldestSentMessage() async {
        let page = (0..<50).map { index in
            TestFixtures.message(sentAt: Date(timeIntervalSince1970: TimeInterval(1_000 + index)))
        }
        let older = TestFixtures.message(body: "Самое старое", sentAt: Date(timeIntervalSince1970: 500))
        let repository = ChatRepositoryStub(fetchResults: [.success(page), .success([older])])
        let viewModel = makeChatViewModel(repository: repository)

        await viewModel.retryLoad()
        #expect(viewModel.hasMoreHistory)
        await viewModel.loadOlder()

        #expect(viewModel.messageBubblesForTesting.first?.text == "Самое старое")
        #expect(repository.fetchCalls.count == 2)
        #expect(repository.fetchCalls[1].0 == page.first?.sentAt)
        #expect(!viewModel.hasMoreHistory)
    }

    @Test
    func defersMarkReadInBackgroundAndMarksAfterReturningActive() async {
        let message = TestFixtures.message()
        let repository = ChatRepositoryStub(fetchResults: [.success([message]), .success([message])])
        var readCallbacks = 0
        let viewModel = makeChatViewModel(repository: repository, onRead: { readCallbacks += 1 })

        await viewModel.sceneDidChange(isActive: false)
        await viewModel.retryLoad()
        #expect(repository.markReadCount == 0)

        await viewModel.sceneDidChange(isActive: true)
        #expect(repository.markReadCount == 1)
        #expect(readCallbacks == 1)
    }

    @Test
    func mergesRealtimeMessageWithoutCreatingDuplicate() async {
        let id = UUID()
        let initial = TestFixtures.message(id: id, body: "Черновик сервера")
        let realtime = TestFixtures.message(id: id, body: "Финальная версия")
        let repository = ChatRepositoryStub(fetchResults: [.success([initial])])
        let viewModel = makeChatViewModel(repository: repository)
        let runTask = Task { await viewModel.run() }

        #expect(await eventually { repository.hasEventSubscriber })
        repository.sendEvent(.message(realtime))
        #expect(await eventually { viewModel.messageBubblesForTesting.first?.text == "Финальная версия" })

        #expect(viewModel.messageBubblesForTesting.count == 1)
        runTask.cancel()
        repository.finishEvents()
        await runTask.value
    }
}
