//
//  OnboardingViewModel.swift
//  myTinder
//
//  Created by Ismail on 24.10.2026.
//

import SwiftUI
import Observation
import PhotosUI

@MainActor
@Observable
final class OnboardingViewModel {
    
    // MARK: Поля формы
    
    var name = ""
    var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
    var bio = ""
    var gender: Gender?
    
    // MARK: Состояние
    
    var interest: InterestOption?
    private(set) var photos: [LocalPhoto] = []
    private(set) var isSubmitting = false
    private(set) var uploadedCount = 0
    private(set) var isLoadingPhotos = false
    private(set) var errorMessage: String?
    
    // MARK: Зависимости
    
    private let profiles: ProfileRepositoryProtocol
    private let photoRepository: PhotoRepositoryProtocol
    private let onCreated: @MainActor (Profile) -> Void
    private let onSignOut: @MainActor () -> Void
    
    /// - Parameters:
    ///   - profiles: репозиторий профилей.
    ///   - photoRepository: репозиторий фото.
    ///   - onCreated: вызывается, когда профиль создан (или уже существовал); обычно `ProfileStore.didCreate`.
    ///   - onSignOut: выход из аккаунта, чтобы пользователь не застрял на онбординге.
    init(
        profiles: ProfileRepositoryProtocol,
        photoRepository: PhotoRepositoryProtocol,
        onCreated: @escaping @MainActor (Profile) -> Void,
        onSignOut: @escaping @MainActor () -> Void
    ) {
        self.profiles = profiles
        self.photoRepository = photoRepository
        self.onCreated = onCreated
        self.onSignOut = onSignOut
    }
    
    // MARK: Private
    
    /// Удаляет файлы, загруженные в рамках неудавшейся попытки.
    /// Выполняется в отдельной `Task`, которая не наследует отмену: иначе при закрытии
    /// экрана запросы на удаление отменились бы сразу, а файлы остались бы в Storage.
    /// Ошибки удаления игнорируются: они не должны перекрывать исходную ошибку.
    private func rollback(_ paths: [String]) async {
        guard !paths.isEmpty else { return }
        
        let repository = photoRepository
        
        await Task {
            for path in paths { try? await repository.delete(path: path) }
        }.value
    }
    
    /// Обрабатывает ошибку создания профиля.
    /// Отмену не показывает. Если профиль уже существует (ответ на прошлую попытку потерялся),
    /// завершает онбординг с найденным профилем. Остальное превращает в понятное сообщение.
    private func handle(_ error: Error) async {
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
        
        if let profileError = error as? ProfileError, case .alreadyExists = profileError {
            if let existing = try? await profiles.fetchMyProfile() {
                onCreated(existing)
                return
            }
        }
        
        errorMessage = Self.message(for: error)
    }
    
    /// Понятный пользователю текст вместо сырой ошибки.
    private static func message(for error: Error) -> String {
        
        if let profileError = error as? ProfileError, let text = profileError.errorDescription {
            return text
        }
        
        if error is URLError {
            return "Нет соединения. Проверьте интернет и попробуйте ещё раз."
        }
        
        return "Не удалось создать профиль. Попробуйте ещё раз."
    }
}

// MARK: - OnboardingViewModelProtocol
extension OnboardingViewModel: OnboardingViewModelProtocol {
    
    /// Самая поздняя допустимая дата рождения в `DatePicker` (сегодня минус 18 лет).
    var latestBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: .now) ?? .now
    }
    
    /// Сколько ещё фото можно добавить.
    var remainingSlots: Int {
        max(0, ProfileValidation.maxPhotos - photos.count)
    }
    
    /// Описание длиннее допустимого (лимит совпадает с серверным `check`).
    var isBioTooLong: Bool {
        bio.trimmingCharacters(in: .whitespacesAndNewlines).count > 500
    }
    
    /// Можно ли нажать «Готово».
    var canSubmit: Bool {
        !isSubmitting
        && !isLoadingPhotos
        && ProfileValidation.normalizedName(name) != nil
        && gender != nil
        && interest != nil
        && !photos.isEmpty
        && !isBioTooLong
    }
    
    /// Обрабатывает фото, выбранные в `PhotosPicker`: загружает данные, уменьшает, добавляет в список.
    /// Лишние фото сверх лимита игнорируются. Если часть фото не удалось прочитать, показывает ошибку.
    /// - Parameter items: выбранные элементы пикера.
    func addPhotos(from items: [PhotosPickerItem]) async {
        errorMessage = nil
        isLoadingPhotos = true
        
        defer { isLoadingPhotos = false }
        
        var hadFailure = false
        
        for item in items {
            guard photos.count < ProfileValidation.maxPhotos else { break }
            
            do {
                guard let raw = try await item.loadTransferable(type: Data.self) else {
                    hadFailure = true
                    continue
                }
                // Уменьшение и перекодирование уводим с главного потока.
                let jpeg = await Task.detached(priority: .userInitiated) {
                    ImageProcessor.makeJPEG(from: raw)
                }.value
                
                if let jpeg, let photo = LocalPhoto(jpegData: jpeg) {
                    photos.append(photo)
                } else {
                    hadFailure = true
                }
            } catch {
                hadFailure = true
            }
        }
        
        if hadFailure {
            errorMessage = "Не удалось добавить часть фото."
        }
    }
    
    /// Убирает фото из списка. На сервере его ещё нет, поэтому удалять там нечего.
    /// - Parameter photo: фото, которое нужно убрать.
    func removePhoto(_ photo: LocalPhoto) {
        photos.removeAll { $0.id == photo.id }
    }
    
    /// Делает фото главным, то есть переносит его на первое место.
    /// - Parameter photo: фото, которое станет главным.
    func makeMain(_ photo: LocalPhoto) {
        guard let index = photos.firstIndex(of: photo), index > 0 else { return }
        
        photos.move(fromOffsets: IndexSet(integer: index), toOffset: 0)
    }
    
    /// Проверяет форму, загружает фото, затем создаёт профиль.
    ///
    /// Порядок важен: сначала файлы, потом строка в БД. Если что-то упало, уже загруженные
    /// файлы удаляются, чтобы в Storage не копились «сироты». Повторные нажатия во время
    /// отправки игнорируются.
    func submit() async {
        guard !isSubmitting else { return }
        
        errorMessage = nil
        
        guard let cleanName = ProfileValidation.normalizedName(name),
              let gender,
              let interest,
              case .success(let cleanBio) = ProfileValidation.normalizedBio(bio)
        else {
            errorMessage = "Проверьте имя и описание."
            return
        }
        
        // Сервер считает возраст по UTC, поэтому дату переносим в UTC и проверяем в нём же.
        let birth = DateOnly.utcDate(fromLocal: birthDate)
        
        guard ProfileValidation.isAdult(birthDate: birth, calendar: .utc) else {
            errorMessage = ProfileError.underage.errorDescription
            return
        }
        
        isSubmitting = true
        uploadedCount = 0
        
        defer { isSubmitting = false }
        
        var uploadedPaths: [String] = []
        do {
            for photo in photos {
                uploadedPaths.append(try await photoRepository.upload(photo.jpegData))
                uploadedCount += 1
            }
            let newProfile = NewProfile(
                name: cleanName,
                birthDate: birth,
                bio: cleanBio,
                gender: gender,
                interestedIn: interest.genders,
                photoPaths: uploadedPaths
            )
            let profile = try await profiles.create(newProfile)
            onCreated(profile)
        } catch {
            await rollback(uploadedPaths)
            await handle(error)
        }
    }
    
    /// Выходит из аккаунта (кнопка в тулбаре).
    func signOut() {
        onSignOut()
    }
}
