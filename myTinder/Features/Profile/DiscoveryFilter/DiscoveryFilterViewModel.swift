import Foundation
import Observation

@MainActor
@Observable
final class DiscoveryFilterViewModel {

    var interest: InterestOption?
    var minAge: Double
    var maxAge: Double

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    private var profile: Profile
    private let profiles: ProfileRepositoryProtocol
    private let onApplied: @MainActor (Profile) -> Void

    init(
        profile: Profile,
        profiles: ProfileRepositoryProtocol,
        onApplied: @escaping @MainActor (Profile) -> Void
    ) {
        self.profile = profile
        self.profiles = profiles
        self.onApplied = onApplied
        interest = InterestOption(genders: profile.interestedIn)
        minAge = Double(profile.minAge)
        maxAge = Double(profile.maxAge)
    }

    var canApply: Bool {
        guard let interest else { return false }
        let lower = Int(minAge.rounded())
        let upper = Int(maxAge.rounded())
        let changed = Set(interest.genders) != Set(profile.interestedIn)
            || lower != profile.minAge
            || upper != profile.maxAge

        return !isSaving
            && changed
            && ProfileValidation.isValidDiscoveryAgeRange(minAge: lower, maxAge: upper)
    }

    func apply() async {
        guard canApply, let interest else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let updated = try await profiles.update(
                ProfileChanges(
                    bio: profile.bio,
                    interestedIn: interest.genders,
                    photoPaths: profile.photoPaths,
                    minAge: Int(minAge.rounded()),
                    maxAge: Int(maxAge.rounded())
                )
            )
            profile = updated
            onApplied(updated)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error is URLError
                ? "Нет соединения. Проверьте интернет и попробуйте ещё раз."
                : "Не удалось применить фильтры. Попробуйте ещё раз."
        }
    }
}
