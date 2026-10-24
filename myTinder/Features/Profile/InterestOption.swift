//
//  InterestOption.swift
//  myTinder
//
//  Created by Ismail on 25.10.2026.
//

import Foundation

enum InterestOption: CaseIterable, Identifiable {
    
    case male, female, everyone
    
    var id: Self { self }
    
    /// Подпись сегмента.
    var title: String {
        switch self {
        case .male: "Мужчин"
        case .female: "Женщин"
        case .everyone: "Всех"
        }
    }
    
    /// Полы, которые уйдут в `interested_in`.
    var genders: [Gender] {
        switch self {
        case .male: [.male]
        case .female: [.female]
        case .everyone: [.male, .female]
        }
    }
}
