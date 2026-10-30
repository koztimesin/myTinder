//
//  ReportViewModelProtocol.swift
//  myTinder
//
//  Created by Ismail on 31.10.2026.
//

import Foundation
import Observation

@MainActor
protocol ReportViewModelProtocol: AnyObject, Observable {
    /// Причины для списка.
    var categories: [ReportCategory] { get }
    /// Выбранная причина.
    var selectedCategory: ReportCategory? { get set }
    /// Комментарий (обрезается до допустимой длины).
    var details: String { get set }
    /// Счётчик символов комментария, например «12 / 1000».
    var detailsCounter: String { get }
    /// Заблокировать вместе с отправкой жалобы.
    var alsoBlock: Bool { get set }
    /// Пояснение под переключателем блокировки.
    var alsoBlockHint: String { get }
    /// Состояние экрана.
    var state: ReportState { get }
    /// Можно ли отправлять (причина выбрана, отправка не идёт).
    var canSubmit: Bool { get }
    /// Показывать ли кнопку «Отмена» (до отправки).
    var canCancel: Bool { get }
    /// Запрещено ли закрывать шторку жестом (идёт отправка или чат уже должен закрыться).
    var isDismissLocked: Bool { get }
    /// Текст подтверждения после успешной отправки.
    var sentMessage: String { get }
    /// Отправляет жалобу, затем при необходимости блокирует. Повторный вызов после сбоя
    /// блокировки не отправляет жалобу второй раз.
    func submit() async
    /// Завершает сценарий (кнопки «Готово» и «Закрыть»).
    func finish()
}
