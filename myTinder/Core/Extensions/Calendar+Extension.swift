//
//  Calendar+Extension.swift
//  myTinder
//
//  Created by Ismail on 24.10.2026.
//

import Foundation

extension Calendar {
    
    /// Григорианский календарь в UTC. Сервер считает 18 лет и хранит `birth_date` именно по UTC.
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        
        return calendar
    }()
}
