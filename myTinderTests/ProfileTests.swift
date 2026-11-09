import Foundation
import Testing
@testable import myTinder

@Suite("Profile validation")
@MainActor
struct ProfileValidationTests {
    @Test("Name is trimmed and constrained to 1...50 characters", arguments: [
        ("  Алина\n", "Алина"),
        ("", nil),
        (String(repeating: "а", count: 50), String(repeating: "а", count: 50)),
        (String(repeating: "а", count: 51), nil)
    ])
    func normalizesName(raw: String, expected: String?) {
        #expect(ProfileValidation.normalizedName(raw) == expected)
    }

    @Test
    func normalizesBioBoundaries() throws {
        let empty = try ProfileValidation.normalizedBio("  \n").get()
        let text = try ProfileValidation.normalizedBio(" text ").get()
        let maximum = try ProfileValidation.normalizedBio(String(repeating: "а", count: 500)).get()
        #expect(empty == nil)
        #expect(text == "text")
        #expect(maximum != nil)
        #expect(throws: ProfileValidation.ValidationError.self) {
            try ProfileValidation.normalizedBio(String(repeating: "а", count: 501)).get()
        }
    }

    @Test
    func validatesAgeAndDefaultDiscoveryRange() throws {
        let calendar = Calendar.utc
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 7)))
        let exactlyEighteen = try #require(calendar.date(from: DateComponents(year: 2008, month: 11, day: 7)))
        let oneDayTooYoung = try #require(calendar.date(from: DateComponents(year: 2008, month: 11, day: 8)))
        let ageTwentyFive = try #require(calendar.date(from: DateComponents(year: 2001, month: 11, day: 7)))

        #expect(ProfileValidation.isAdult(birthDate: exactlyEighteen, now: now, calendar: calendar))
        #expect(!ProfileValidation.isAdult(birthDate: oneDayTooYoung, now: now, calendar: calendar))
        #expect(ProfileValidation.defaultDiscoveryAgeRange(birthDate: exactlyEighteen, now: now, calendar: calendar) == 18...23)
        #expect(ProfileValidation.defaultDiscoveryAgeRange(birthDate: ageTwentyFive, now: now, calendar: calendar) == 20...30)
        #expect(ProfileValidation.isValidDiscoveryAgeRange(minAge: 18, maxAge: 99))
        #expect(!ProfileValidation.isValidDiscoveryAgeRange(minAge: 30, maxAge: 20))
    }

    @Test
    func mapsInterestOptionsBothWays() {
        #expect(InterestOption.male.genders == [.male])
        #expect(InterestOption.female.genders == [.female])
        #expect(Set(InterestOption.everyone.genders) == Set([.male, .female]))
        #expect(InterestOption(genders: [.female, .male]) == .everyone)
        #expect(InterestOption(genders: []) == nil)
    }
}

@Suite("Profile store")
@MainActor
struct ProfileStoreTests {
    @Test
    func transitionsThroughReadyMissingAndFailure() async {
        let profile = TestFixtures.profile()
        let repository = ProfileRepositoryStub()
        repository.fetchResults = [.success(profile), .success(nil), .failure(TestFailure.expected)]
        let store = ProfileStore(profiles: repository)

        await store.load()
        if case .ready(let loaded) = store.state {
            #expect(loaded == profile)
        } else {
            Issue.record("Expected ready profile")
        }

        await store.load()
        if case .needsProfile = store.state {} else { Issue.record("Expected needsProfile") }

        await store.load()
        if case .failed(let message) = store.state {
            #expect(message.contains("Не удалось загрузить профиль"))
        } else {
            Issue.record("Expected failed state")
        }
    }
}

@Suite("Onboarding")
@MainActor
struct OnboardingViewModelTests {
    @Test
    func createsNormalizedProfileWithDefaultFilters() async {
        let created = TestFixtures.profile(photoPaths: ["new.jpg"])
        let profiles = ProfileRepositoryStub()
        profiles.createResult = .success(created)
        let photos = PhotoRepositoryStub()
        photos.uploadResults = [.success("new.jpg")]
        var received: Profile?
        let viewModel = OnboardingViewModel(
            profiles: profiles,
            photoRepository: photos,
            initialPhotos: [TestFixtures.localPhoto()],
            onCreated: { received = $0 },
            onSignOut: {}
        )
        viewModel.name = "  Алина "
        viewModel.birthDate = Calendar.utc.date(byAdding: .year, value: -25, to: .now)!
        viewModel.bio = "  О себе  "
        viewModel.gender = .female
        viewModel.interest = .male

        await viewModel.submit()

        let payload = profiles.createdProfiles.first
        #expect(payload?.name == "Алина")
        #expect(payload?.bio == "О себе")
        #expect(payload?.photoPaths == ["new.jpg"])
        if let birthDate = payload?.birthDate {
            let expectedRange = ProfileValidation.defaultDiscoveryAgeRange(
                birthDate: birthDate,
                calendar: .utc
            )
            #expect(payload?.minAge == expectedRange.lowerBound)
            #expect(payload?.maxAge == expectedRange.upperBound)
        } else {
            Issue.record("Expected create payload")
        }
        #expect(received == created)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func rollsBackUploadedFilesWhenCreateDefinitelyFailed() async {
        let profiles = ProfileRepositoryStub()
        profiles.createResult = .failure(TestFailure.expected)
        profiles.fetchResults = [.success(nil)]
        let photos = PhotoRepositoryStub()
        photos.uploadResults = [.success("orphan.jpg")]
        let viewModel = configuredOnboarding(profiles: profiles, photos: photos)

        await viewModel.submit()

        #expect(photos.deletedPaths == ["orphan.jpg"])
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func reconcilesLostCreateResponseWithoutDeletingReferencedPhoto() async {
        let existing = TestFixtures.profile(photoPaths: ["committed.jpg"])
        let profiles = ProfileRepositoryStub()
        profiles.createResult = .failure(TestFailure.expected)
        profiles.fetchResults = [.success(existing)]
        let photos = PhotoRepositoryStub()
        photos.uploadResults = [.success("committed.jpg")]
        var received: Profile?
        let viewModel = configuredOnboarding(profiles: profiles, photos: photos) { received = $0 }

        await viewModel.submit()

        #expect(received == existing)
        #expect(photos.deletedPaths.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    private func configuredOnboarding(
        profiles: ProfileRepositoryStub,
        photos: PhotoRepositoryStub,
        onCreated: @escaping @MainActor (Profile) -> Void = { _ in }
    ) -> OnboardingViewModel {
        let viewModel = OnboardingViewModel(
            profiles: profiles,
            photoRepository: photos,
            initialPhotos: [TestFixtures.localPhoto()],
            onCreated: onCreated,
            onSignOut: {}
        )
        viewModel.name = "Алина"
        viewModel.birthDate = Calendar.utc.date(byAdding: .year, value: -25, to: .now)!
        viewModel.gender = .female
        viewModel.interest = .male
        return viewModel
    }
}

@Suite("Edit profile")
@MainActor
struct EditProfileViewModelTests {
    @Test
    func savesBioWithoutChangingDiscoveryPreferences() async {
        var updated = TestFixtures.profile()
        updated.bio = "Новое описание"
        let profiles = ProfileRepositoryStub()
        profiles.updateResult = .success(updated)
        let photos = PhotoRepositoryStub()
        var received: Profile?
        let viewModel = EditProfileViewModel(
            profile: TestFixtures.profile(),
            profiles: profiles,
            photoRepository: photos,
            urlProvider: PhotoURLProviderStub(),
            onUpdated: { received = $0 }
        )
        viewModel.bio = " Новое описание "

        await viewModel.save()

        let changes = profiles.updates.first
        #expect(changes?.bio == "Новое описание")
        #expect(changes?.interestedIn == [.male])
        #expect(changes?.minAge == 20)
        #expect(changes?.maxAge == 30)
        #expect(received == updated)
        #expect(!viewModel.canSave)
    }
}
