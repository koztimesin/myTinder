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
            defaults.set(appearance.rawValue, forKey: AppAppearance.storageKey)
        }
    }

    private let onOpenDeleteAccount: @MainActor () -> Void
    private let defaults: UserDefaults

    /// Создаёт модель из сохранённой темы.
    /// - Parameters:
    ///   - defaults: хранилище выбранной темы.
    ///   - onOpenDeleteAccount: открывает экран удаления аккаунта.
    init(
        defaults: UserDefaults = .standard,
        onOpenDeleteAccount: @escaping @MainActor () -> Void
    ) {
        self.defaults = defaults
        let rawValue = defaults.string(forKey: AppAppearance.storageKey)
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
