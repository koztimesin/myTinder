//
//  DeleteAccountViewModel.swift
//  myTinder
//
//  Created by Codex on 07.11.2026.
//

import Observation

/// Управляет состоянием необратимого удаления аккаунта.
@MainActor
@Observable
final class DeleteAccountViewModel {

    private let repository: AccountRepositoryProtocol

    private(set) var isDeleting = false
    private(set) var errorMessage: String?

    /// - Parameter repository: серверные операции над аккаунтом.
    init(repository: AccountRepositoryProtocol) {
        self.repository = repository
    }
}

extension DeleteAccountViewModel: DeleteAccountViewModelProtocol {

    func deleteAccount() async {
        guard !isDeleting else { return }

        isDeleting = true
        errorMessage = nil

        do {
            try await repository.deleteAccount()
        } catch {
            errorMessage = "Не удалось удалить аккаунт. Проверьте соединение и попробуйте снова."
        }

        isDeleting = false
    }
}
