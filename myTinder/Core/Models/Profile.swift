//
//  Profile.swift
//  myTinder
//
//  Created by Ismail on 22.10.2026.
//

import Foundation

enum Gender: String, CaseIterable, Codable, Sendable {
    
    case male
    case female
}

struct Profile: Equatable, Identifiable, Sendable {
    
    let id: UUID
    var name: String
    let birthDate: Date
    var bio: String?
    var gender: Gender
    var interestedIn: [Gender]
    var photoPaths: [String]
    /// Минимальный возраст кандидатов в ленте.
    var minAge: Int = ProfileValidation.minimumDiscoveryAge
    /// Максимальный возраст кандидатов в ленте.
    var maxAge: Int = ProfileValidation.maximumDiscoveryAge
}

enum ProfileValidation {
    
    enum ValidationError: Error {
        case bioTooLong
    }
    
    static let maxPhotos = 4
    /// Нижняя граница возрастного фильтра.
    static let minimumDiscoveryAge = 18
    /// Верхняя граница возрастного фильтра.
    static let maximumDiscoveryAge = 99
    /// Радиус начального диапазона относительно возраста пользователя.
    static let defaultDiscoveryAgeRadius = 5

    /// Вычисляет полный возраст на указанную дату.
    /// - Parameters:
    ///   - birthDate: дата рождения.
    ///   - now: дата, на которую считается возраст.
    ///   - calendar: календарь вычисления.
    /// - Returns: число полных лет или `nil` для даты рождения из будущего.
    static func age(
        birthDate: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int? {
        guard birthDate <= now else { return nil }
        return calendar.dateComponents([.year], from: birthDate, to: now).year
    }

    /// Строит начальный возрастной диапазон ±5 лет с ограничением 18...99.
    /// - Parameters:
    ///   - birthDate: дата рождения пользователя.
    ///   - now: текущая дата.
    ///   - calendar: календарь вычисления возраста.
    /// - Returns: допустимый закрытый диапазон.
    static func defaultDiscoveryAgeRange(
        birthDate: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ClosedRange<Int> {
        let calculatedAge = age(birthDate: birthDate, now: now, calendar: calendar)
            ?? minimumDiscoveryAge
        let center = min(max(calculatedAge, minimumDiscoveryAge), maximumDiscoveryAge)
        let lowerBound = max(minimumDiscoveryAge, center - defaultDiscoveryAgeRadius)
        let upperBound = min(maximumDiscoveryAge, center + defaultDiscoveryAgeRadius)
        return lowerBound...upperBound
    }

    /// Проверяет допустимость возрастного диапазона.
    /// - Parameters:
    ///   - minAge: нижняя граница.
    ///   - maxAge: верхняя граница.
    /// - Returns: `true`, если диапазон лежит внутри 18...99 и не перевёрнут.
    static func isValidDiscoveryAgeRange(minAge: Int, maxAge: Int) -> Bool {
        minimumDiscoveryAge <= minAge
            && minAge <= maxAge
            && maxAge <= maximumDiscoveryAge
    }
    
    static func normalizedName(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (1...50).contains(s.count) ? s : nil
    }
    
    static func normalizedBio(_ raw: String) -> Result<String?, ValidationError> {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !s.isEmpty else { return .success(nil) }
        
        return s.count <= 500 ? .success(s) : .failure(.bioTooLong)
    }
    
    static func isAdult(birthDate: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let eightTeen = calendar.date(byAdding: .year, value: 18, to: birthDate) else { return false }
        
        return eightTeen <= now
    }
}
