//
//  CandidateViewModel.swift
//  myTinder
//
//  Created by Ismail on 31.10.2026.
//

import Foundation
import Observation

/// Всё, с чем работает раскрытая анкета в ленте: жалоба и блокировка.
/// Сама анкета (фото, имя, «О себе») рисуется карточкой, решение «Нравится» и «Пропустить»
/// принимает лента, так что здесь только модерация.
@MainActor
protocol CandidateViewModelProtocol: AnyObject, Observable {
    /// Модель шторки жалобы.
    associatedtype Report: ReportViewModelProtocol
    
    /// Идентификатор анкеты (профиля).
    var id: UUID { get }
    /// Идёт ли блокировка: меню и кнопки в это время неактивны.
    var isBusy: Bool { get }
    /// Текст ошибки действия, `nil` если ошибки нет.
    var errorMessage: String? { get }
    /// Заблокирован ли пользователь (из меню или вместе с жалобой). Лента по этому признаку
    /// сворачивает анкету и убирает карточку.
    var didBlock: Bool { get }
    /// Пояснение в alert блокировки.
    var blockConfirmationMessage: String { get }
    /// Модель жалобы; создаётся в `openReport()`.
    var report: Report? { get }
    /// Показана ли шторка жалобы.
    var isReportPresented: Bool { get set }
    /// Показан ли alert блокировки.
    var isBlockConfirmationPresented: Bool { get set }
    
    /// Открывает шторку жалобы.
    func openReport()
    /// Просит подтверждение блокировки.
    func requestBlock()
    /// Блокирует пользователя после подтверждения.
    func confirmBlock() async
    /// Скрывает ошибку.
    func dismissError()
}

@MainActor
@Observable
final class CandidateViewModel {
    
    let id: UUID
    
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    private(set) var didBlock = false
    private(set) var report: ReportViewModel?
    var isReportPresented = false
    var isBlockConfirmationPresented = false
    
    private let name: String
    @ObservationIgnored private let moderation: any ModerationRepositoryProtocol
    @ObservationIgnored private let makeReportViewModel: @MainActor (_ onFinished: @escaping @MainActor (Bool) -> Void) -> ReportViewModel
    
    /// - Parameters:
    ///   - card: анкета из ленты.
    ///   - moderation: источник блокировок.
    ///   - makeReportViewModel: собирает модель жалобы; принимает колбэк завершения.
    init(
        card: FeedCard,
        moderation: any ModerationRepositoryProtocol,
        makeReportViewModel: @escaping @MainActor (_ onFinished: @escaping @MainActor (Bool) -> Void) -> ReportViewModel
    ) {
        self.id = card.id
        self.name = card.name
        self.moderation = moderation
        self.makeReportViewModel = makeReportViewModel
    }
}

extension CandidateViewModel: CandidateViewModelProtocol {
    
    var blockConfirmationMessage: String {
        "«\(name)» больше не появится в ленте. Блокировку нельзя отменить."
    }
    
    func openReport() {
        guard !isBusy, !didBlock else { return }
        
        report = makeReportViewModel { [weak self] didBlock in
            self?.reportFinished(didBlock: didBlock)
        }
        isReportPresented = true
    }
    
    func requestBlock() {
        guard !isBusy, !didBlock else { return }
        
        isBlockConfirmationPresented = true
    }
    
    func confirmBlock() async {
        guard !isBusy, !didBlock else { return }
        
        isBusy = true
        errorMessage = nil
        do {
            try await moderation.block(userID: id)
            isBusy = false
            didBlock = true
        } catch {
            isBusy = false
            errorMessage = "Не удалось заблокировать. Проверьте соединение и попробуйте снова."
        }
    }
    
    func dismissError() {
        errorMessage = nil
    }
    
    /// Жалоба закрыта кнопками «Готово» или «Закрыть».
    /// - Parameter didBlock: заблокирован ли пользователь вместе с жалобой.
    private func reportFinished(didBlock: Bool) {
        isReportPresented = false
        
        if didBlock {
            self.didBlock = true
        }
    }
}

#if DEBUG
/// Заглушка модели анкеты для превью.
@MainActor
@Observable
final class CandidateViewModelStub {
    let id = UUID()
    var isBusy = false
    var errorMessage: String?
    var didBlock = false
    var isReportPresented = false
    var isBlockConfirmationPresented = false
    
    /// - Parameter errorMessage: текст ошибки или `nil`.
    init(errorMessage: String? = nil) {
        self.errorMessage = errorMessage
    }
}

extension CandidateViewModelStub: CandidateViewModelProtocol {
    var report: ReportViewModel? { nil }
    var blockConfirmationMessage: String { "«Алина» больше не появится в ленте. Блокировку нельзя отменить." }
    
    func openReport() { isReportPresented = true }
    func requestBlock() { isBlockConfirmationPresented = true }
    func confirmBlock() async { didBlock = true }
    func dismissError() { errorMessage = nil }
}
#endif
