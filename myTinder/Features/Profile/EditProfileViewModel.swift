//
//  EditProfileViewModel.swift
//  myTinder
//
//  Created by Ismail on 25.10.2026.
//

import Observation
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class EditProfileViewModel {
    
    // MARK: Поля формы
    
    var bio: String
    var interest: InterestOption?
    
    // MARK: Состояние
    
    /// Последняя сохранённая на сервере версия профиля.
    private(set) var profile: Profile
    /// Загруженные ссылки на фото: путь → ссылка.
    private(set) var photoURLs: [String: URL] = [:]
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    private var canRemovePhotos: Bool { profile.photoPaths.count > 1 }
    
    // MARK: Зависимости
    
    private let profiles: ProfileRepositoryProtocol
    private let photoRepository: PhotoRepositoryProtocol
    private let urlProvider: PhotoURLProviderProtocol
    private let onUpdated: @MainActor (Profile) -> Void
    private let onSignOut: @MainActor () -> Void
    
    /// - Parameters:
    ///   - profile: текущий профиль.
    ///   - profiles: репозиторий профилей.
    ///   - photoRepository: репозиторий фото.
    ///   - urlProvider: источник временных ссылок на фото.
    ///   - onUpdated: вызывается после каждого успешного изменения профиля (обычно `ProfileStore.didUpdate`).
    ///   - onSignOut: выход из аккаунта.
    init(
        profile: Profile,
        profiles: ProfileRepositoryProtocol,
        photoRepository: PhotoRepositoryProtocol,
        urlProvider: PhotoURLProviderProtocol,
        onUpdated: @escaping @MainActor (Profile) -> Void,
        onSignOut: @escaping @MainActor () -> Void
    ) {
        self.profile = profile
        self.bio = profile.bio ?? ""
        self.interest = InterestOption(genders: profile.interestedIn)
        self.profiles = profiles
        self.photoRepository = photoRepository
        self.urlProvider = urlProvider
        self.onUpdated = onUpdated
        self.onSignOut = onSignOut
    }
    
    // MARK: Private
    
    /// Выполняет операцию с защитой от параллельных нажатий: пока одна идёт, остальные игнорируются.
    /// - Parameters:
    ///   - refreshesPhotos: обновить ссылки на фото после операции (даже если она не удалась).
    ///   - operation: сама операция; её ошибки превращаются в сообщение для пользователя.
    private func perform(refreshesPhotos: Bool = false, _ operation: () async throws -> Void) async {
        guard !isBusy else { return }
        
        isBusy = true
        errorMessage = nil
        
        defer { isBusy = false }
        
        do {
            try await operation()
        } catch {
            handle(error)
        }
        
        if refreshesPhotos {
            await refreshURLs()
        }
    }
    
    /// Запрашивает ссылки для текущего списка фото.
    private func refreshURLs() async {
        photoURLs = await urlProvider.urls(for: profile.photoPaths)
    }
    
    /// Изменения на основе последней сохранённой версии, но с новым списком фото.
    /// Несохранённые правки формы сюда намеренно не попадают: операция с фото
    /// не должна тайком сохранять недописанное имя или описание.
    private func changes(photoPaths: [String]) -> ProfileChanges {
        ProfileChanges(
            bio: profile.bio,
            interestedIn: profile.interestedIn,
            photoPaths: photoPaths
        )
    }
    
    /// Применяет профиль, вернувшийся с сервера, и сообщает об изменении наружу.
    private func apply(_ updated: Profile) {
        profile = updated
        onUpdated(updated)
    }
    
    /// Загружает файл, затем добавляет его путь в профиль. Если запись пути не удалась,
    /// файл удаляется, чтобы в Storage не копились «сироты».
    private func attach(_ jpeg: Data) async throws {
        let path = try await photoRepository.upload(jpeg)
        
        do {
            let updated = try await profiles.update(changes(photoPaths: profile.photoPaths + [path]))
            apply(updated)
        } catch {
            await discard(path)
            throw error
        }
    }
    
    /// Удаляет файл из хранилища. Ошибки игнорируются: лишний файл лучше, чем потерянная
    /// ошибка пользователя. Выполняется в отдельной `Task`, которая не наследует отмену,
    /// иначе при закрытии экрана удаление отменилось бы сразу.
    private func discard(_ path: String) async {
        let repository = photoRepository
        await Task {
            _ = try? await repository.delete(path: path)
        }.value
    }
    
    /// Превращает ошибку в сообщение. Отмену не показывает.
    private func handle(_ error: Error) {
        if error is CancellationError || (error as? URLError)?.code == .cancelled {
            return
        }
        
        errorMessage = Self.message(for: error)
    }
    
    private static func message(for error: Error) -> String {
        if let profileError = error as? ProfileError, let text = profileError.errorDescription {
            return text
        }
        
        if error is URLError {
            return "Нет соединения. Проверьте интернет и попробуйте ещё раз."
        }
        
        return "Не удалось сохранить изменения. Попробуйте ещё раз."
    }
    
    /// Возвращает поля формы к значениям сохранённого профиля.
    private func fillForm(from profile: Profile) {
        bio = profile.bio ?? ""
        interest = InterestOption(genders: profile.interestedIn)
    }
    
    /// Удаляет фото. Сначала обновляется массив на сервере, потом удаляется файл:
    /// лишний файл безобиднее битой ссылки в профиле.
    /// - Parameter path: путь удаляемого фото.
    private func removePhoto(path: String) async {
        await perform(refreshesPhotos: true) {
            guard profile.photoPaths.count > 1 else {
                errorMessage = "В профиле должно остаться хотя бы одно фото."
                return
            }
            let remaining = profile.photoPaths.filter { $0 != path }
            let updated = try await profiles.update(changes(photoPaths: remaining))
            apply(updated)
            await discard(path)
        }
    }
    
    /// Переносит фото на первое место.
    /// - Parameter path: путь фото, которое станет главным.
    private func makeMain(path: String) async {
        await perform(refreshesPhotos: true) {
            guard let index = profile.photoPaths.firstIndex(of: path), index > 0 else { return }
            var paths = profile.photoPaths
            let moved = paths.remove(at: index)
            paths.insert(moved, at: 0)
            let updated = try await profiles.update(changes(photoPaths: paths))
            apply(updated)
        }
    }
}

// MARK: - EditProfileViewModelProtocol
extension EditProfileViewModel: EditProfileViewModelProtocol {
    
    var name: String {
        profile.name
    }
    
    var genderTitle: String {
        profile.gender.title
    }
    
    /// Дата рождения словами. Хранится в UTC, поэтому и форматируется в UTC,
    /// иначе в часовых поясах восточнее UTC день сдвинулся бы.
    var birthDateText: String {
        profile.birthDate.formatted(Date.FormatStyle(date: .long, time: .omitted, timeZone: .gmt))
    }
    
    /// Плитки для сетки: ссылка на картинку берётся из загруженных ссылок,
    /// удаление и смена главного идут на сервер.
    var tiles: [PhotoTileViewModel] {
        profile.photoPaths.enumerated().map { index, path in
            PhotoTileViewModel(
                id: path,
                position: index + 1,
                isMain: index == 0,
                canRemove: canRemovePhotos,
                source: .remote(photoURLs[path]),
                onRemove: { Task { await self.removePhoto(path: path) } },
                onMakeMain: { Task { await self.makeMain(path: path) } }
            )
        }
    }
    
    var remainingSlots: Int {
        max(0, ProfileValidation.maxPhotos - profile.photoPaths.count)
    }
    
    var isBioTooLong: Bool {
        bio.trimmingCharacters(in: .whitespacesAndNewlines).count > 500
    }
    
    /// Отличается ли форма от сохранённого профиля.
    /// Некорректные значения считаются изменением; кнопку при этом блокирует `canSave`.
    private var hasChanges: Bool {
        guard case .success(let cleanBio) = ProfileValidation.normalizedBio(bio) else { return true }
        
        let currentInterest: Set<Gender>? = interest.map { Set($0.genders) }
        
        return cleanBio != profile.bio
            || currentInterest != Set(profile.interestedIn)
    }

    var canSave: Bool {
        !isBusy && hasChanges && interest != nil && !isBioTooLong
    }
    
    func load() async {
        await refreshURLs()
    }
    
    /// Добавляет фото по одному: каждое загружается и сразу записывается в профиль,
    /// поэтому при сбое на середине уже добавленные остаются. Лишние сверх лимита игнорируются.
    /// - Parameter items: элементы, выбранные в `PhotosPicker`.
    func addPhotos(from items: [PhotosPickerItem]) async {
        await perform(refreshesPhotos: true) {
            var hadUnreadable = false
            for item in items {
                guard profile.photoPaths.count < ProfileValidation.maxPhotos else { break }
                
                guard let raw = try await item.loadTransferable(type: Data.self) else {
                    hadUnreadable = true
                    continue
                }
                // Уменьшение и перекодирование уводим с главного потока.
                let jpeg = await Task.detached(priority: .userInitiated) {
                    ImageProcessor.makeJPEG(from: raw)
                }.value
                
                guard let jpeg else {
                    hadUnreadable = true
                    continue
                }
                try await attach(jpeg)
            }
            
            if hadUnreadable {
                errorMessage = "Не удалось добавить часть фото."
            }
        }
    }
    
    /// Проверяет поля формы и сохраняет их. Дата рождения и фото здесь не меняются.
    func save() async {
        await perform {
            guard let interest,
                  case .success(let cleanBio) = ProfileValidation.normalizedBio(bio) else {
                errorMessage = "Проверьте имя и описание."
                return
            }
            
            let edited = ProfileChanges(
                bio: cleanBio,
                interestedIn: interest.genders,
                photoPaths: profile.photoPaths
            )
            
            let updated = try await profiles.update(edited)
            apply(updated)
            fillForm(from: updated)
        }
    }
    
    func signOut() {
        onSignOut()
    }
}
