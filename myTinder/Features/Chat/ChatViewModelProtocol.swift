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
    /// Тип модели экрана жалобы.
    associatedtype ReportModel: ReportViewModelProtocol
    
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
    
    /// Модель шторки жалобы; создаётся при открытии.
    var report: ReportModel? { get }
    /// Показана ли шторка жалобы.
    var isReportPresented: Bool { get set }
    /// Показано ли подтверждение блокировки.
    var isBlockConfirmationPresented: Bool { get set }
    /// Пояснение в подтверждении блокировки.
    var blockConfirmationMessage: String { get }
    /// Идёт ли блокировка (меню недоступно).
    var isModerationBusy: Bool { get }
    /// Ошибка последнего действия модерации; сама пропадает через несколько секунд.
    var actionError: ErrorBannerViewModel? { get }
    
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
    /// Открывает шторку жалобы.
    func openReport()
    /// Показывает подтверждение блокировки.
    func requestBlock()
    /// Блокирует собеседника после подтверждения; при успехе закрывает чат.
    func confirmBlock() async
}
