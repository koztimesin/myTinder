//
//  MatchesViewModelProtocol.swift
//  myTinder
//
//  Created by Ismail on 28.10.2026.
//

import Foundation
import Observation

@MainActor
protocol MatchesViewModelProtocol: AnyObject, Observable {
    /// Что показывать на экране.
    var state: MatchesScreenState { get }
    /// Текст ошибки загрузки, если она была.
    var errorMessage: String? { get }
    /// Элементы ряда «Новые».
    var newItems: [NewMatchItemViewModel] { get }
    /// Строки диалогов.
    var dialogRows: [MatchRowViewModel] { get }
    /// Пути фото, для которых нужны ссылки (триггер для `loadPhotos`).
    var photoPaths: [String] { get }
    /// Получает ссылки на фото собеседников.
    func loadPhotos() async
    /// Перезагружает матчи и ссылки (pull to refresh и «Повторить»).
    func refresh() async
    /// Открывает ленту (кнопка в пустом состоянии).
    func openFeed()
}
