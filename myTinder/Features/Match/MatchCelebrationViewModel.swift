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
    
    private let match: MatchSummary
    private let myPhotoPath: String?
    private let photoURLProvider: PhotoURLProviderProtocol
    private let onWrite: @MainActor () -> Void
    private let onDismiss: @MainActor () -> Void
    private var myPhotoURL: URL?
    private var partnerPhotoURL: URL?
    
    /// - Parameters:
    ///   - match: новый матч.
    ///   - myPhotoPath: путь главного фото текущего пользователя.
    ///   - photoURLProvider: выдача ссылок на фото.
    ///   - onWrite: что делать по «Написать».
    ///   - onDismiss: что делать по «Продолжить».
    init(
        match: MatchSummary,
        myPhotoPath: String?,
        photoURLProvider: PhotoURLProviderProtocol,
        onWrite: @escaping @MainActor () -> Void,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.match = match
        self.myPhotoPath = myPhotoPath
        self.photoURLProvider = photoURLProvider
        self.onWrite = onWrite
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
    
    func loadPhotos() async {
        let paths = [myPhotoPath, match.partner.photoPath].compactMap { $0 }
        guard !paths.isEmpty else { return }
        let urls = await photoURLProvider.urls(for: paths)
        myPhotoURL = myPhotoPath.flatMap { urls[$0] }
        partnerPhotoURL = match.partner.photoPath.flatMap { urls[$0] }
    }
    
    func write() {
        onWrite()
    }
    
    func dismiss() {
        onDismiss()
    }
}
