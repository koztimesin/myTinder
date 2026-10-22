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
}

enum ProfileValidation {
    
    enum ValidationError: Error {
        case bioTooLong
    }
    
    static let maxPhotos = 6
    
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
