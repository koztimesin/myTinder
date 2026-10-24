//
//  Gender+Title.swift
//  myTinder
//
//  Created by Ismail on 24.10.2026.
//

import Foundation

extension Gender {
    
    /// Подпись для выбора `Ваш пол`
    var title: String {
        switch self {
        case .male: "Мужчина"
        case .female: "Женщина"
        }
    }
    
    /// Подпись для выбора `Кого ищете`
    var interestTitle: String {
        switch self {
        case .male: "Мужчин"
        case .female: "Женщин"
        }
    }
}
