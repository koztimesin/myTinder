//
//  ChatViewModelProtocol.swift
//  myTinder
//
//  Created by Ismail on 29.10.2026.
//

import Foundation
import Observation

@MainActor
protocol ChatViewModelProtocol: AnyObject, Observable {
    /// Имя собеседника для шапки.
    var title: String { get }
    /// Аватар собеседника для шапки.
    var avatar: MatchAvatarViewModel { get }
    /// Что показывать на экране.
    var state: ChatScreenState { get }
    /// Строки списка: разделители дней и сообщения.
    var rows: [ChatRowViewModel] { get }
    /// Идентификатор последней строки (для прокрутки вниз).
    var lastRowID: String? { get }
    /// Есть ли более старые сообщения на сервере.
    var hasMoreHistory: Bool { get }
    /// Модель панели ввода.
    var inputBar: ChatInputBarViewModel { get }
    /// Загружает историю и держит подписку, пока задача не отменена.
    func run() async
    /// Повторяет первую загрузку после ошибки.
    func retryLoad() async
    /// Подгружает страницу более старых сообщений.
    func loadOlder() async
    /// Получает ссылку на фото собеседника.
    func loadPhotos() async
    /// Сообщает об изменении активности приложения.
    /// - Parameter isActive: `true`, когда приложение на переднем плане.
    func sceneDidChange(isActive: Bool) async
}
