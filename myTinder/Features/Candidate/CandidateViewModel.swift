//
//  CandidateViewModel.swift
//  myTinder
//
//  Created by Ismail on 31.10.2026.
//

import Foundation
import Observation

/// Решение, принятое в анкете.
enum CandidateDecision: Equatable {
    /// «Нравится».
    case like
    /// «Пропустить».
    case dislike
}

@MainActor
protocol CandidateViewModelProtocol: AnyObject, Observable, Identifiable where ID == UUID {
    /// Модель шторки жалобы.
    associatedtype Report: ReportViewModelProtocol
    
    /// Заголовок вида «Анна, 27».
    var title: String { get }
    /// Описание «о себе».
    var bio: String? { get }
    /// Готовые signed URL; пусто, пока не получены.
    var photoURLs: [URL] { get }
    /// Сколько всего фото (для полосок, пока ссылки грузятся).
    var photoCount: Int { get }
    /// Идёт ли блокировка: кнопки в это время неактивны.
    var isBusy: Bool { get }
    /// Текст ошибки действия, `nil` если ошибки нет.
    var errorMessage: String? { get }
    /// Пояснение в alert блокировки.
    var blockConfirmationMessage: String { get }
    /// Модель жалобы; создаётся в `openReport()`.
    var report: Report? { get }
    /// Показана ли шторка жалобы.
    var isReportPresented: Bool { get set }
    /// Показан ли alert блокировки.
    var isBlockConfirmationPresented: Bool { get set }
    
    /// «Нравится».
    func like()
    /// «Пропустить».
    func dislike()
    /// Закрывает анкету без решения.
    func close()
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
    let title: String
    let bio: String?
    let photoURLs: [URL]
    let photoCount: Int
    
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    private(set) var report: ReportViewModel?
    var isReportPresented = false
    var isBlockConfirmationPresented = false
    
    private let name: String
    @ObservationIgnored private let moderation: any ModerationRepositoryProtocol
    @ObservationIgnored private let makeReportViewModel: @MainActor (_ onFinished: @escaping @MainActor (Bool) -> Void) -> ReportViewModel
    @ObservationIgnored private let onDecision: @MainActor (CandidateDecision) -> Void
    @ObservationIgnored private let onClose: @MainActor () -> Void
    @ObservationIgnored private let onBlocked: @MainActor () -> Void
    
    /// - Parameters:
    ///   - card: анкета из ленты.
    ///   - photoURLs: уже полученные ссылки на фото верхней карточки.
    ///   - moderation: источник блокировок.
    ///   - makeReportViewModel: собирает модель жалобы; принимает колбэк завершения.
    ///   - onDecision: вызывается по «Нравится» и «Пропустить».
    ///   - onClose: вызывается по шеврону.
    ///   - onBlocked: вызывается после успешной блокировки (из меню или из жалобы).
    init(
        card: FeedCard,
        photoURLs: [URL],
        moderation: any ModerationRepositoryProtocol,
        makeReportViewModel: @escaping @MainActor (_ onFinished: @escaping @MainActor (Bool) -> Void) -> ReportViewModel,
        onDecision: @escaping @MainActor (CandidateDecision) -> Void,
        onClose: @escaping @MainActor () -> Void,
        onBlocked: @escaping @MainActor () -> Void
    ) {
        self.id = card.id
        self.name = card.name
        self.title = "\(card.name), \(card.age)"
        self.bio = card.bio
        self.photoURLs = photoURLs
        self.photoCount = card.photoPaths.count
        self.moderation = moderation
        self.makeReportViewModel = makeReportViewModel
        self.onDecision = onDecision
        self.onClose = onClose
        self.onBlocked = onBlocked
    }
}

extension CandidateViewModel: @MainActor CandidateViewModelProtocol {
    
    var blockConfirmationMessage: String {
        "«\(name)» больше не появится в ленте. Блокировку нельзя отменить."
    }
    
    func like() {
        guard !isBusy else { return }
        
        onDecision(.like)
    }
    
    func dislike() {
        guard !isBusy else { return }
        
        onDecision(.dislike)
    }
    
    func close() {
        guard !isBusy else { return }
        
        onClose()
    }
    
    func openReport() {
        guard !isBusy else { return }
        
        report = makeReportViewModel { [weak self] didBlock in
            self?.reportFinished(didBlock: didBlock)
        }
        isReportPresented = true
    }
    
    func requestBlock() {
        guard !isBusy else { return }
        
        isBlockConfirmationPresented = true
    }
    
    func confirmBlock() async {
        guard !isBusy else { return }
        
        isBusy = true
        errorMessage = nil
        do {
            try await moderation.block(userID: id)
            isBusy = false
            onBlocked()
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
            onBlocked()
        }
    }
}
