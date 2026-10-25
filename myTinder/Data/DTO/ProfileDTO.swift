//
//  ProfileDTO.swift
//  myTinder
//
//  Created by Ismail on 22.10.2026.
//

import Foundation

struct ProfileDTO: Decodable {
    let id: UUID
    let name: String
    let birthDate: String
    let bio: String?
    let gender: String?
    let interestedIn: [String]?
    let photoPaths: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, bio, gender
        case birthDate = "birth_date"
        case interestedIn = "interested_in"
        case photoPaths = "photo_paths"
    }
}

struct ProfileInsertDTO: Encodable {
    let id: UUID
    let name: String
    let birthDate: String
    let bio: String?
    let gender: String
    let interestedIn: [String]
    let photoPaths: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, name, bio, gender
        case birthDate = "birth_date"
        case interestedIn = "interested_in"
        case photoPaths = "photo_paths"
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(birthDate, forKey: .birthDate)
        try c.encode(bio, forKey: .bio)
        try c.encode(gender, forKey: .gender)
        try c.encode(interestedIn, forKey: .interestedIn)
        try c.encode(photoPaths, forKey: .photoPaths)
    }
}

struct ProfileUpdateDTO: Encodable {
    
    let bio: String?
    let interestedIn: [String]
    let photoPaths: [String]
    
    enum CodingKeys: String, CodingKey {
        case bio
        case interestedIn = "interested_in"
        case photoPaths = "photo_paths"
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(bio, forKey: .bio)
        try c.encode(interestedIn, forKey: .interestedIn)
        try c.encode(photoPaths, forKey: .photoPaths)
    }
}

enum DateOnly {
    
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    /// Переносит выбранную в `DatePicker` дату в UTC, сохраняя день, месяц и год.
    /// Без этого в часовых поясах восточнее UTC день «съезжает» на сутки назад.
    static func utcDate(fromLocal date: Date, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return Calendar.utc.date(from: parts) ?? date
    }
}

extension ProfileDTO {
    
    func toDomain() throws -> Profile {
        
        guard let date = DateOnly.formatter.date(from: birthDate),
              let gender = gender.flatMap(Gender.init(rawValue:)) else {
            throw ProfileError.invalidData
        }
        
        return Profile(
            id: id, name: name, birthDate: date, bio: bio, gender: gender,
            interestedIn: (interestedIn ?? []).compactMap(Gender.init(rawValue:)),
            photoPaths: photoPaths ?? []
        )
    }
}
