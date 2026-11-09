//
//  AccountRepositoryProtocol.swift
//  myTinder
//
//  Created by Ismail on 09.11.2026.
//

import Foundation

/// Необратимые операции над аккаунтом текущего пользователя.
protocol AccountRepositoryProtocol: Sendable {

    /// Удаляет аккаунт и связанные с ним данные на сервере.
    func deleteAccount() async throws
}
