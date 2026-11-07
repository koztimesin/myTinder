//
//  SettingsViewModel.swift
//  myTinder
//
//  Created by Codex on 07.11.2026.
//

import Foundation
import Observation

/// Управляет локальными настройками приложения и маршрутами аккаунта.
@MainActor
@Observable
final class SettingsViewModel {

    /// Выбранная тема; изменение сразу сохраняется для следующих запусков.
    var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: AppAppearance.storageKey)
        }
    }

    private let onOpenDeleteAccount: @MainActor () -> Void

    /// Создаёт модель из сохранённой темы.
    /// - Parameter onOpenDeleteAccount: открывает экран удаления аккаунта.
    init(onOpenDeleteAccount: @escaping @MainActor () -> Void) {
        let rawValue = UserDefaults.standard.string(forKey: AppAppearance.storageKey)
        appearance = rawValue.flatMap(AppAppearance.init(rawValue:)) ?? .system
        self.onOpenDeleteAccount = onOpenDeleteAccount
    }
}

// MARK: - SettingsViewModelProtocol

extension SettingsViewModel: SettingsViewModelProtocol {

    func openDeleteAccount() {
        onOpenDeleteAccount()
    }
}
