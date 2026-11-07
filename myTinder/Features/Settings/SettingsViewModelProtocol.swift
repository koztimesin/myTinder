//
//  SettingsViewModelProtocol.swift
//  myTinder
//
//  Created by Codex on 07.11.2026.
//

import Observation

/// Контракт экрана общих настроек приложения.
@MainActor
protocol SettingsViewModelProtocol: AnyObject, Observable {

    /// Выбранный режим оформления.
    var appearance: AppAppearance { get set }

    /// Открывает экран удаления аккаунта.
    func openDeleteAccount()
}
