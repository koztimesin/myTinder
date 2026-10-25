//
//  OnboardingViewModelProtocol.swift
//  myTinder
//
//  Created by Ismail on 24.10.2026.
//

import Foundation
import Observation
import PhotosUI
import SwiftUI

@MainActor
protocol OnboardingViewModelProtocol: Observable, AnyObject, Sendable {
    
    var name: String { get set }
    var birthDate: Date { get set }
    var bio: String { get set }
    var gender: Gender? { get set }
    /// Выбранный вариант «Кого ищете» или `nil`, пока пользователь не выбрал.
    var interest: InterestOption? { get set }
    /// Плитки выбранных фото в порядке показа, первая главная.
    var tiles: [PhotoTileViewModel] { get }
    /// Идёт создание профиля.
    var isSubmitting: Bool { get }
    /// Сколько фото уже загружено.
    var uploadedCount: Int { get }
    /// Идёт обработка выбранных фото.
    var isLoadingPhotos: Bool { get }
    /// Текст ошибки для показа или `nil`.
    var errorMessage: String? { get }
    /// Самая поздняя допустимая дата рождения.
    var latestBirthDate: Date { get }
    /// Сколько ещё фото можно добавить.
    var remainingSlots: Int { get }
    /// Описание длиннее допустимого.
    var isBioTooLong: Bool { get }
    /// Можно ли нажать «Готово».
    var canSubmit: Bool { get }
    
    /// Обрабатывает фото, выбранные в `PhotosPicker`.
    func addPhotos(from items: [PhotosPickerItem]) async
    /// Проверяет форму и создаёт профиль.
    func submit() async
    /// Выходит из аккаунта.
    func signOut()
}
