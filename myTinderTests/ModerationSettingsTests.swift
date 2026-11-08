import Foundation
import Testing
@testable import myTinder

@Suite("Reports and blocking")
@MainActor
struct ModerationViewModelTests {
    @Test
    func sendsTrimmedReportWithoutBlocking() async {
        let repository = ModerationRepositoryStub()
        var finished: Bool?
        let viewModel = ReportViewModel(
            userID: TestFixtures.partnerID,
            name: "Алина",
            repository: repository,
            onFinished: { finished = $0 }
        )
        viewModel.selectedCategory = .spam
        viewModel.details = "  подозрительная ссылка  "
        viewModel.alsoBlock = false

        await viewModel.submit()
        viewModel.finish()

        #expect(viewModel.state == .sent)
        #expect(repository.reports.count == 1)
        #expect(repository.reports.first?.1 == .spam)
        #expect(repository.reports.first?.2 == "подозрительная ссылка")
        #expect(repository.blockedIDs.isEmpty)
        #expect(finished == false)
    }

    @Test
    func retriesOnlyBlockAfterReportWasAccepted() async {
        let repository = ModerationRepositoryStub()
        repository.blockResults = [.failure(TestFailure.expected), .success(())]
        var finished: Bool?
        let viewModel = ReportViewModel(
            userID: TestFixtures.partnerID,
            name: "Алина",
            repository: repository,
            onFinished: { finished = $0 }
        )
        viewModel.selectedCategory = .fake

        await viewModel.submit()
        #expect(viewModel.state == .blockFailed)
        #expect(repository.reports.count == 1)

        await viewModel.submit()
        viewModel.finish()

        #expect(viewModel.state == .sent)
        #expect(repository.reports.count == 1)
        #expect(repository.blockedIDs.count == 2)
        #expect(finished == true)
    }

    @Test
    func exposesReportFailureAndAllowsRetry() async {
        let repository = ModerationRepositoryStub()
        repository.reportResults = [.failure(TestFailure.expected), .success(())]
        let viewModel = ReportViewModel(
            userID: TestFixtures.partnerID,
            name: "Алина",
            repository: repository,
            onFinished: { _ in }
        )
        viewModel.selectedCategory = .harassment
        viewModel.alsoBlock = false

        await viewModel.submit()
        guard case .failed(let message) = viewModel.state else {
            Issue.record("Expected failed report")
            return
        }
        #expect(message.contains("Не удалось отправить жалобу"))
        #expect(viewModel.canSubmit)

        await viewModel.submit()
        #expect(viewModel.state == .sent)
        #expect(repository.reports.count == 2)
    }

    @Test
    func candidateReflectsSuccessfulAndFailedBlock() async {
        let repository = ModerationRepositoryStub()
        repository.blockResults = [.failure(TestFailure.expected), .success(())]
        let candidate = CandidateViewModel(
            card: TestFixtures.card(),
            moderation: repository,
            makeReportViewModel: { onFinished in
                ReportViewModel(
                    userID: TestFixtures.partnerID,
                    name: "Алина",
                    repository: repository,
                    onFinished: onFinished
                )
            }
        )

        await candidate.confirmBlock()
        #expect(!candidate.didBlock)
        #expect(candidate.errorMessage != nil)
        candidate.dismissError()

        await candidate.confirmBlock()
        #expect(candidate.didBlock)
        #expect(candidate.errorMessage == nil)
    }

    @Test
    func chatBlockNotifiesOnlyAfterSuccess() async {
        let repository = ChatRepositoryStub(fetchResults: [])
        let moderation = ModerationRepositoryStub()
        moderation.blockResults = [.failure(TestFailure.expected), .success(())]
        var blockedCount = 0
        let viewModel = makeChatViewModel(
            repository: repository,
            moderation: moderation,
            onBlocked: { blockedCount += 1 }
        )

        await viewModel.confirmBlock()
        #expect(blockedCount == 0)
        #expect(viewModel.actionError != nil)

        await viewModel.confirmBlock()
        #expect(blockedCount == 1)
        #expect(moderation.blockedIDs.count == 2)
    }
}

@Suite("Settings")
@MainActor
struct SettingsViewModelTests {
    @Test
    func loadsPersistsAppearanceAndOpensDeleteAccount() {
        let suiteName = "SettingsViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(AppAppearance.dark.rawValue, forKey: AppAppearance.storageKey)
        var opened = false
        let viewModel = SettingsViewModel(defaults: defaults) { opened = true }

        #expect(viewModel.appearance == .dark)
        viewModel.appearance = .light
        viewModel.openDeleteAccount()

        #expect(defaults.string(forKey: AppAppearance.storageKey) == AppAppearance.light.rawValue)
        #expect(opened)
    }

    @Test
    func fallsBackToSystemForUnknownStoredValue() {
        let suiteName = "SettingsViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("unknown", forKey: AppAppearance.storageKey)

        let viewModel = SettingsViewModel(defaults: defaults, onOpenDeleteAccount: {})

        #expect(viewModel.appearance == .system)
    }
}

@Suite("Delete account")
@MainActor
struct DeleteAccountViewModelTests {
    @Test
    func reportsSuccessAndFailure() async {
        let repository = AccountRepositoryStub()
        let viewModel = DeleteAccountViewModel(repository: repository)

        await viewModel.deleteAccount()
        #expect(repository.callCount == 1)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isDeleting)

        repository.result = .failure(TestFailure.expected)
        await viewModel.deleteAccount()
        #expect(repository.callCount == 2)
        #expect(viewModel.errorMessage?.contains("Не удалось удалить аккаунт") == true)
        #expect(!viewModel.isDeleting)
    }
}
