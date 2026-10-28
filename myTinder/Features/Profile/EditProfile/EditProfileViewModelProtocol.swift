//
//  EditProfileViewModelProtocol.swift
//  myTinder
//
//  Created by Ismail on 25.10.2026.
//

import Observation
import PhotosUI
import SwiftUI

@MainActor
protocol EditProfileViewModelProtocol: Observable, AnyObject {

    // MARK: Поля формы (меняются через привязки)

    var name: String { get }
    var bio: String { get set }
    var genderTitle: String { get }
    /// `nil` только если сохранённый набор не удалось сопоставить с вариантом.
    var interest: InterestOption? { get set }
    /// Дата рождения для показа (менять нельзя).
    var birthDateText: String { get }
    /// Плитки фото профиля в сохранённом порядке, первая главная.
    var tiles: [PhotoTileViewModel] { get }
    /// Идёт операция с сервером; экран заблокирован.
    var isBusy: Bool { get }
    /// Текст ошибки или `nil`.
    var errorMessage: String? { get }
    /// Сколько ещё фото можно добавить.
    var remainingSlots: Int { get }
    /// Описание длиннее допустимого.
    var isBioTooLong: Bool { get }
    /// Можно ли нажать «Сохранить».
    var canSave: Bool { get }

    /// Загружает ссылки на фото. Вызывается при появлении экрана.
    func load() async
    /// Добавляет выбранные в пикере фото в профиль.
    func addPhotos(from items: [PhotosPickerItem]) async
    /// Сохраняет изменения полей формы.
    func save() async
    /// Выходит из аккаунта.
    func signOut()
}
