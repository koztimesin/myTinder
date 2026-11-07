//
//  DeleteAccountViewModelProtocol.swift
//  myTinder
//
//  Created by Codex on 07.11.2026.
//

import Observation

/// Контракт экрана окончательного удаления аккаунта.
@MainActor
protocol DeleteAccountViewModelProtocol: AnyObject, Observable {

    /// Выполняется ли удаление прямо сейчас.
    var isDeleting: Bool { get }
    /// Понятное пользователю описание последней ошибки.
    var errorMessage: String? { get }

    /// Запускает необратимое удаление аккаунта.
    func deleteAccount() async
}
