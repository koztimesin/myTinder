//
//  ReportViewModel.swift
//  myTinder
//
//  Created by Ismail on 31.10.2026.
//

import Foundation
import Observation

/// Состояние экрана жалобы.
enum ReportState: Equatable {
    /// Форма заполняется.
    case idle
    /// Идёт отправка.
    case sending
    /// Жалоба отправлена (и пользователь заблокирован, если это было выбрано).
    case sent
    /// Жалоба не отправлена; текст ошибки для пользователя.
    case failed(String)
    /// Жалоба отправлена, но заблокировать не удалось.
    case blockFailed
}

@MainActor
@Observable
final class ReportViewModel {
    
    /// Максимальная длина комментария (совпадает с ограничением в БД).
    private let maxDetailsLength = 1000
    
    private let userID: UUID
    private let name: String
    private let repository: ModerationRepositoryProtocol
    private let onFinished: @MainActor (_ didBlock: Bool) -> Void
    
    private var detailsStorage = ""
    /// Жалоба уже принята сервером (повторно её не отправляем).
    private var reportSent = false
    /// Пользователь уже заблокирован.
    private var didBlock = false
    
    var selectedCategory: ReportCategory?
    var alsoBlock = true
    private(set) var state: ReportState = .idle
    
    /// - Parameters:
    ///   - userID: на кого жалоба.
    ///   - name: имя пользователя для текстов.
    ///   - repository: источник жалоб и блокировок.
    ///   - onFinished: вызывается по «Готово» и «Закрыть»; параметр — заблокирован ли пользователь.
    init(
        userID: UUID,
        name: String,
        repository: ModerationRepositoryProtocol,
        onFinished: @escaping @MainActor (_ didBlock: Bool) -> Void
    ) {
        self.userID = userID
        self.name = name
        self.repository = repository
        self.onFinished = onFinished
    }
}

extension ReportViewModel: ReportViewModelProtocol {
    
    var categories: [ReportCategory] { ReportCategory.allCases }
    
    var details: String {
        get { detailsStorage }
        set { detailsStorage = String(newValue.prefix(maxDetailsLength)) }
    }
    
    var detailsCounter: String { "\(detailsStorage.count) / \(maxDetailsLength)" }
    
    var alsoBlockHint: String {
        "Вы больше не увидите друг друга, а диалог с «\(name)» будет удалён без возможности восстановления."
    }
    
    var canSubmit: Bool {
        guard selectedCategory != nil else { return false }
        
        switch state {
        case .idle, .failed: return true
        case .sending, .sent, .blockFailed: return false
        }
    }
    
    var canCancel: Bool {
        switch state {
        case .idle, .failed: return true
        case .sending, .sent, .blockFailed: return false
        }
    }
    
    var isDismissLocked: Bool {
        switch state {
        case .sending: return true
        case .sent: return didBlock
        case .idle, .failed, .blockFailed: return false
        }
    }
    
    var sentMessage: String {
        didBlock
        ? "Спасибо, мы рассмотрим её. Пользователь заблокирован, диалог удалён."
        : "Спасибо, мы рассмотрим её."
    }
    
    func submit() async {
        // Повтор после сбоя блокировки разрешён, даже если `canSubmit` для этого состояния ложен.
        let isRetryingBlock = state == .blockFailed
        guard let category = selectedCategory, canSubmit || isRetryingBlock else { return }
        
        state = .sending
        
        if !reportSent {
            let trimmed = detailsStorage.trimmingCharacters(in: .whitespacesAndNewlines)
            do {
                try await repository.report(
                    userID: userID,
                    category: category,
                    details: trimmed.isEmpty ? nil : trimmed
                )
                reportSent = true
            } catch {
                state = .failed("Не удалось отправить жалобу. Проверьте соединение и попробуйте снова.")
                return
            }
        }
        
        if alsoBlock && !didBlock {
            do {
                try await repository.block(userID: userID)
                didBlock = true
            } catch {
                state = .blockFailed
                return
            }
        }
        
        state = .sent
    }
    
    func finish() {
        onFinished(didBlock)
    }
}
