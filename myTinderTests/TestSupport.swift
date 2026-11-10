import Foundation
import UIKit
@testable import myTinder

enum TestFailure: Error {
    case expected
}

enum TestFixtures {
    static let currentUserID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let partnerID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let matchID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    static func profile(
        id: UUID = partnerID,
        photoPaths: [String] = ["photo.jpg"],
        minAge: Int = 20,
        maxAge: Int = 30
    ) -> Profile {
        Profile(
            id: id,
            name: "Алина",
            birthDate: Date(timeIntervalSince1970: 0),
            bio: "О себе",
            gender: .female,
            interestedIn: [.male],
            photoPaths: photoPaths,
            minAge: minAge,
            maxAge: maxAge
        )
    }

    static func card(id: UUID = partnerID) -> FeedCard {
        FeedCard(id: id, name: "Алина", age: 25, bio: "О себе", photoPaths: ["photo.jpg"])
    }

    static func match(
        id: UUID = matchID,
        partnerID: UUID = partnerID,
        message: LastMessage? = nil,
        unreadCount: Int = 0
    ) -> MatchSummary {
        MatchSummary(
            id: id,
            matchedAt: Date(timeIntervalSince1970: 100),
            partner: MatchPartner(id: partnerID, name: "Алина", photoPath: "photo.jpg"),
            lastMessage: message,
            unreadCount: unreadCount
        )
    }

    static func message(
        id: UUID = UUID(),
        senderID: UUID = partnerID,
        body: String = "Привет",
        sentAt: Date = Date(timeIntervalSince1970: 1_000)
    ) -> Message {
        Message(id: id, matchID: matchID, senderID: senderID, body: body, sentAt: sentAt)
    }

    static func localPhoto() -> LocalPhoto {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
        let image = renderer.image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        return LocalPhoto(jpegData: image.jpegData(compressionQuality: 0.8)!)!
    }
}

@MainActor
final class AuthRepositoryStub: AuthRepositoryProtocol {
    var signUpResults: [Result<SignUpResult, Error>] = []
    var signInResults: [Result<Void, Error>] = []
    private(set) var signUpCalls: [(String, String)] = []
    private(set) var signInCalls: [(String, String)] = []

    func userStream() -> AsyncStream<AppUser?> {
        AsyncStream { $0.finish() }
    }

    func signUp(email: String, password: String) async throws -> SignUpResult {
        signUpCalls.append((email, password))
        guard !signUpResults.isEmpty else { throw TestFailure.expected }
        return try signUpResults.removeFirst().get()
    }

    func signIn(email: String, password: String) async throws {
        signInCalls.append((email, password))
        guard !signInResults.isEmpty else { throw TestFailure.expected }
        try signInResults.removeFirst().get()
    }

    func signOut() async throws {}
}

@MainActor
func eventually(
    attempts: Int = 200,
    _ condition: @MainActor () -> Bool
) async -> Bool {
    for _ in 0..<attempts {
        if condition() { return true }
        await Task.yield()
    }
    return false
}

@MainActor
final class ProfileRepositoryStub: ProfileRepositoryProtocol {
    var fetchResults: [Result<Profile?, Error>] = []
    var createResult: Result<Profile, Error> = .failure(TestFailure.expected)
    var updateResult: Result<Profile, Error> = .failure(TestFailure.expected)
    private(set) var createdProfiles: [NewProfile] = []
    private(set) var updates: [ProfileChanges] = []
    private(set) var fetchedProfileIDs: [UUID] = []

    func fetchMyProfile() async throws -> Profile? {
        guard !fetchResults.isEmpty else { return nil }
        return try fetchResults.removeFirst().get()
    }

    func fetchProfile(id: UUID) async throws -> Profile? {
        fetchedProfileIDs.append(id)
        guard !fetchResults.isEmpty else { return nil }
        return try fetchResults.removeFirst().get()
    }

    func create(_ new: NewProfile) async throws -> Profile {
        createdProfiles.append(new)
        return try createResult.get()
    }

    func update(_ changes: ProfileChanges) async throws -> Profile {
        updates.append(changes)
        return try updateResult.get()
    }
}

@MainActor
final class PhotoRepositoryStub: PhotoRepositoryProtocol {
    var uploadResults: [Result<String, Error>] = []
    private(set) var uploadedData: [Data] = []
    private(set) var deletedPaths: [String] = []

    func upload(_ jpegData: Data) async throws -> String {
        uploadedData.append(jpegData)
        guard !uploadResults.isEmpty else { throw TestFailure.expected }
        return try uploadResults.removeFirst().get()
    }

    func delete(path: String) async throws {
        deletedPaths.append(path)
    }

    func signedURLs(for paths: [String], expiresIn: Int) async throws -> [String: URL] { [:] }
}

struct PhotoURLProviderStub: PhotoURLProviderProtocol {
    var result: [String: URL] = [:]
    func urls(for paths: [String]) async -> [String: URL] { result }
}

@MainActor
final class FeedRepositoryStub: FeedRepositoryProtocol {
    var results: [Result<[Profile], Error>]
    private(set) var swipes: [(UUID, Bool)] = []

    init(results: [Result<[Profile], Error>]) {
        self.results = results
    }

    func fetchFeed(limit: Int) async throws -> [Profile] {
        guard !results.isEmpty else { return [] }
        return try results.removeFirst().get()
    }

    func sendSwipe(targetID: UUID, liked: Bool) async throws {
        swipes.append((targetID, liked))
    }
}

@MainActor
final class FeedUseCaseStub: FeedUseCaseProtocol {
    var batches: [Result<[FeedCard], Error>]
    var swipeResult: Result<Void, Error> = .success(())
    private(set) var swipes: [(UUID, Bool)] = []
    private(set) var resetCount = 0

    init(batches: [Result<[FeedCard], Error>]) {
        self.batches = batches
    }

    func loadNextBatch() async throws -> [FeedCard] {
        guard !batches.isEmpty else { return [] }
        return try batches.removeFirst().get()
    }

    func swipe(on card: FeedCard, liked: Bool) async throws {
        swipes.append((card.id, liked))
        try swipeResult.get()
    }

    func reset() { resetCount += 1 }
}

@MainActor
final class ControlledFeedUseCase: FeedUseCaseProtocol {
    private let card: FeedCard
    private var swipeContinuation: CheckedContinuation<Void, Error>?
    var hasPendingSwipe: Bool { swipeContinuation != nil }

    init(card: FeedCard) {
        self.card = card
    }

    func loadNextBatch() async throws -> [FeedCard] { [card] }

    func swipe(on card: FeedCard, liked: Bool) async throws {
        try await withCheckedThrowingContinuation { continuation in
            swipeContinuation = continuation
        }
    }

    func reset() {}

    func failSwipe() {
        swipeContinuation?.resume(throwing: TestFailure.expected)
        swipeContinuation = nil
    }
}

@MainActor
final class ControlledLoadFeedUseCase: FeedUseCaseProtocol {
    private var loadContinuations: [CheckedContinuation<[FeedCard], Error>] = []
    var pendingLoadCount: Int { loadContinuations.count }

    func loadNextBatch() async throws -> [FeedCard] {
        try await withCheckedThrowingContinuation { loadContinuations.append($0) }
    }

    func swipe(on card: FeedCard, liked: Bool) async throws {}
    func reset() {}

    func resumeNext(with cards: [FeedCard]) {
        loadContinuations.removeFirst().resume(returning: cards)
    }
}

@MainActor
final class ModerationRepositoryStub: ModerationRepositoryProtocol {
    var reportResults: [Result<Void, Error>] = []
    var blockResults: [Result<Void, Error>] = []
    private(set) var reports: [(UUID, ReportCategory, String?)] = []
    private(set) var blockedIDs: [UUID] = []

    func report(userID: UUID, category: ReportCategory, details: String?) async throws {
        reports.append((userID, category, details))
        if !reportResults.isEmpty { try reportResults.removeFirst().get() }
    }

    func block(userID: UUID) async throws {
        blockedIDs.append(userID)
        if !blockResults.isEmpty { try blockResults.removeFirst().get() }
    }
}

@MainActor
final class AccountRepositoryStub: AccountRepositoryProtocol {
    var result: Result<Void, Error> = .success(())
    private(set) var callCount = 0

    func deleteAccount() async throws {
        callCount += 1
        try result.get()
    }
}

@MainActor
final class MatchRepositoryStub: MatchRepositoryProtocol {
    var fetchResults: [Result<[MatchSummary], Error>]
    private(set) var fetchCount = 0

    init(fetchResults: [Result<[MatchSummary], Error>]) {
        self.fetchResults = fetchResults
    }

    func fetchMatches() async throws -> [MatchSummary] {
        fetchCount += 1
        guard !fetchResults.isEmpty else { return [] }
        return try fetchResults.removeFirst().get()
    }

    func newMatchSignals() -> AsyncStream<UUID> { AsyncStream { $0.finish() } }
    func deletedMatchSignals() -> AsyncStream<UUID> { AsyncStream { $0.finish() } }
    func messageSignals() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}

@MainActor
final class ControlledMatchRepository: MatchRepositoryProtocol {
    private var continuations: [CheckedContinuation<[MatchSummary], Error>] = []
    private(set) var fetchCount = 0

    func fetchMatches() async throws -> [MatchSummary] {
        fetchCount += 1
        return try await withCheckedThrowingContinuation { continuations.append($0) }
    }

    func resumeNext(with matches: [MatchSummary]) {
        continuations.removeFirst().resume(returning: matches)
    }

    func newMatchSignals() -> AsyncStream<UUID> { AsyncStream { $0.finish() } }
    func deletedMatchSignals() -> AsyncStream<UUID> { AsyncStream { $0.finish() } }
    func messageSignals() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}

@MainActor
final class ChatRepositoryStub: ChatRepositoryProtocol {
    var fetchResults: [Result<[Message], Error>]
    var sendResults: [Result<Void, Error>] = []
    var markReadResults: [Result<Void, Error>] = []
    private(set) var fetchCalls: [(Date?, Int)] = []
    private(set) var sendCalls: [(UUID, String)] = []
    private(set) var markReadCount = 0
    private var eventContinuation: AsyncStream<ChatEvent>.Continuation?
    var hasEventSubscriber: Bool { eventContinuation != nil }

    init(fetchResults: [Result<[Message], Error>]) {
        self.fetchResults = fetchResults
    }

    func fetchMessages(matchID: UUID, before: Date?, limit: Int) async throws -> [Message] {
        fetchCalls.append((before, limit))
        guard !fetchResults.isEmpty else { return [] }
        return try fetchResults.removeFirst().get()
    }

    func send(id: UUID, matchID: UUID, body: String) async throws {
        sendCalls.append((id, body))
        if !sendResults.isEmpty { try sendResults.removeFirst().get() }
    }

    func markRead(matchID: UUID) async throws {
        markReadCount += 1
        if !markReadResults.isEmpty { try markReadResults.removeFirst().get() }
    }

    func events(matchID: UUID) -> AsyncStream<ChatEvent> {
        AsyncStream { eventContinuation = $0 }
    }

    func sendEvent(_ event: ChatEvent) {
        eventContinuation?.yield(event)
    }

    func finishEvents() {
        eventContinuation?.finish()
    }
}

@MainActor
func makeFeedViewModel(
    useCase: any FeedUseCaseProtocol,
    moderation: ModerationRepositoryStub = ModerationRepositoryStub()
) -> FeedViewModel {
    FeedViewModel(
        useCase: useCase,
        photoURLProvider: PhotoURLProviderStub(),
        moderation: moderation,
        makeReportViewModel: { userID, name, onFinished in
            ReportViewModel(userID: userID, name: name, repository: moderation, onFinished: onFinished)
        }
    )
}

@MainActor
func makeChatViewModel(
    repository: ChatRepositoryStub,
    moderation: ModerationRepositoryStub = ModerationRepositoryStub(),
    onBlocked: @escaping @MainActor () -> Void = {},
    onRead: @escaping @MainActor () -> Void = {},
    onOpenPartnerProfile: @escaping @MainActor () -> Void = {}
) -> ChatViewModel {
    ChatViewModel(
        matchID: TestFixtures.matchID,
        partner: MatchPartner(id: TestFixtures.partnerID, name: "Алина", photoPath: "photo.jpg"),
        currentUserID: TestFixtures.currentUserID,
        repository: repository,
        photoURLProvider: PhotoURLProviderStub(),
        moderation: moderation,
        makeReportViewModel: { onFinished in
            ReportViewModel(
                userID: TestFixtures.partnerID,
                name: "Алина",
                repository: moderation,
                onFinished: onFinished
            )
        },
        onBlocked: onBlocked,
        onRead: onRead,
        onOpenPartnerProfile: onOpenPartnerProfile
    )
}

extension ChatViewModel {
    var messageBubblesForTesting: [MessageBubbleViewModel] {
        rows.compactMap { row in
            guard case .message(let bubble) = row else { return nil }
            return bubble
        }
    }
}
