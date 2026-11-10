import Foundation
import Observation

enum PartnerProfileState: Equatable {
    case loading
    case content
    case failed
}

@MainActor
@Observable
final class PartnerProfileViewModel {

    private let partnerID: UUID
    private let fallbackName: String
    private let profiles: ProfileRepositoryProtocol
    private let photoURLProvider: PhotoURLProviderProtocol
    private let moderation: ModerationRepositoryProtocol
    private let makeReportViewModel: @MainActor (@escaping @MainActor (Bool) -> Void) -> ReportViewModel
    private let onBlocked: @MainActor () -> Void

    private var profile: Profile?
    private(set) var photoURLs: [URL] = []
    private(set) var state: PartnerProfileState = .loading
    private var loadingTask: Task<Void, Never>?
    private(set) var isModerationBusy = false
    private(set) var actionError: String?
    private(set) var report: ReportViewModel?
    var isReportPresented = false
    var isBlockConfirmationPresented = false

    init(
        partnerID: UUID,
        fallbackName: String,
        profiles: ProfileRepositoryProtocol,
        photoURLProvider: PhotoURLProviderProtocol,
        moderation: ModerationRepositoryProtocol,
        makeReportViewModel: @escaping @MainActor (@escaping @MainActor (Bool) -> Void) -> ReportViewModel,
        onBlocked: @escaping @MainActor () -> Void
    ) {
        self.partnerID = partnerID
        self.fallbackName = fallbackName
        self.profiles = profiles
        self.photoURLProvider = photoURLProvider
        self.moderation = moderation
        self.makeReportViewModel = makeReportViewModel
        self.onBlocked = onBlocked
    }

    var title: String {
        guard let profile,
              let age = ProfileValidation.age(birthDate: profile.birthDate)
        else { return profile?.name ?? fallbackName }
        return "\(profile.name), \(age)"
    }

    var bio: String? { profile?.bio }

    var card: FeedCardViewModel? {
        guard let profile else { return nil }
        return FeedCardViewModel(
            card: FeedCard(profile: profile),
            photoURLs: photoURLs
        )
    }

    var blockConfirmationMessage: String {
        "Вы больше не увидите друг друга, а диалог с «\(profile?.name ?? fallbackName)» будет удалён без возможности восстановления."
    }

    func load() async {
        guard profile == nil else { return }
        if let loadingTask {
            await loadingTask.value
            return
        }

        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await performLoad()
        }
        loadingTask = task
        await task.value
        loadingTask = nil
    }

    private func performLoad() async {
        state = .loading
        do {
            guard let loaded = try await profiles.fetchProfile(id: partnerID) else {
                state = .failed
                return
            }
            let urls = await photoURLProvider.urls(for: loaded.photoPaths)
            profile = loaded
            photoURLs = loaded.photoPaths.compactMap { urls[$0] }
            state = .content
            await PhotoImagePipeline.shared.prefetch(photoURLs)
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed
        }
    }

    func retry() async {
        profile = nil
        await load()
    }

    func openReport() {
        report = makeReportViewModel { [weak self] didBlock in
            guard let self else { return }
            isReportPresented = false
            if didBlock { onBlocked() }
        }
        isReportPresented = true
    }

    func requestBlock() {
        isBlockConfirmationPresented = true
    }

    func confirmBlock() async {
        guard !isModerationBusy else { return }
        isModerationBusy = true
        actionError = nil
        defer { isModerationBusy = false }
        do {
            try await moderation.block(userID: partnerID)
            onBlocked()
        } catch is CancellationError {
            return
        } catch {
            actionError = "Не удалось заблокировать. Проверьте соединение и попробуйте снова."
        }
    }
}
