//
//  MatchCelebrationViewModel.swift
//  myTinder
//
//  Created by Ismail on 28.10.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class MatchCelebrationViewModel {

    private let maxBodyLength = 2000
    
    private let match: MatchSummary
    private let myPhotoPath: String?
    private let photoURLProvider: PhotoURLProviderProtocol
    private let chatRepository: ChatRepositoryProtocol
    private let onSent: @MainActor () -> Void
    private let onDismiss: @MainActor () -> Void
    private var myPhotoURL: URL?
    private var partnerPhotoURL: URL?
    private var pendingMessageID: UUID?
    private var pendingBody: String?

    var draft = "" {
        didSet {
            if draft.count > maxBodyLength {
                draft = String(draft.prefix(maxBodyLength))
                return
            }
            if draft.trimmingCharacters(in: .whitespacesAndNewlines) != pendingBody {
                pendingMessageID = nil
                pendingBody = nil
            }
        }
    }
    private(set) var isSending = false
    private(set) var errorMessage: String?
    
    /// - Parameters:
    ///   - match: новый матч.
    ///   - myPhotoPath: путь главного фото текущего пользователя.
    ///   - photoURLProvider: выдача ссылок на фото.
    ///   - chatRepository: отправка быстрого сообщения.
    ///   - onSent: открыть диалог после успешной отправки.
    ///   - onDismiss: закрыть окно без сообщения.
    init(
        match: MatchSummary,
        myPhotoPath: String?,
        photoURLProvider: PhotoURLProviderProtocol,
        chatRepository: ChatRepositoryProtocol,
        onSent: @escaping @MainActor () -> Void,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.match = match
        self.myPhotoPath = myPhotoPath
        self.photoURLProvider = photoURLProvider
        self.chatRepository = chatRepository
        self.onSent = onSent
        self.onDismiss = onDismiss
    }
}

extension MatchCelebrationViewModel: MatchCelebrationViewModelProtocol {
    
    var title: String { "Это матч!" }
    
    var subtitle: String { "Вы и \(match.partner.name) понравились друг другу" }
    
    var myAvatar: MatchAvatarViewModel {
        MatchAvatarViewModel(name: "Вы", photoURL: myPhotoURL, diameter: 150, showsRing: true)
    }
    
    var partnerAvatar: MatchAvatarViewModel {
        MatchAvatarViewModel(name: match.partner.name, photoURL: partnerPhotoURL, diameter: 150, showsRing: true)
    }

    var canSend: Bool {
        !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func loadPhotos() async {
        let paths = [myPhotoPath, match.partner.photoPath].compactMap { $0 }
        guard !paths.isEmpty else { return }
        let urls = await photoURLProvider.urls(for: paths)
        myPhotoURL = myPhotoPath.flatMap { urls[$0] }
        partnerPhotoURL = match.partner.photoPath.flatMap { urls[$0] }
    }
    
    func send() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend, !body.isEmpty else { return }

        let id = pendingMessageID ?? UUID()
        pendingMessageID = id
        pendingBody = body
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            try await chatRepository.send(id: id, matchID: match.id, body: body)
            pendingMessageID = nil
            pendingBody = nil
            draft = ""
            onSent()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "Не удалось отправить сообщение. Попробуйте ещё раз."
        }
    }
    
    func dismiss() {
        onDismiss()
    }
}
