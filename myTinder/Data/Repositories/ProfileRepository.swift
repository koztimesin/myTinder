//
//  ProfileRepository.swift
//  myTinder
//
//  Created by Ismail on 22.10.2026.
//

import Foundation

enum ProfileError: LocalizedError {
    
    case invalidData
    case underage
    case alreadyExists
    case photoLimit
    
    var errorDescription: String? {
        switch self {
        case .invalidData: "Не удалось прочитать данные профиля."
        case .underage: "Регистрация доступна только с 18 лет."
        case .alreadyExists: "Профиль уже создан."
        case .photoLimit: "Можно загрузить не больше 6 фото."
        }
    }
}

struct NewProfile: Sendable {
    
    let name: String
    let birthDate: Date
    let bio: String?
    let gender: Gender
    let interestedIn: [Gender]
    let photoPaths: [String]
}

struct ProfileChanges: Sendable {
    
    var name: String
    var bio: String?
    var gender: Gender
    var interestedIn: [Gender]
    var photoPaths: [String]
}

protocol ProfileRepositoryProtocol: Sendable {
    
    func fetchMyProfile() async throws -> Profile?
    func create(_ new: NewProfile) async throws -> Profile
    func update(_ changes: ProfileChanges) async throws -> Profile
}

protocol PhotoRepositoryProtocol: Sendable {
    
    func upload(_ jpegData: Data) async throws -> String
    func delete(path: String) async throws
    func signedURLs(for paths: [String], expiresIn: Int) async throws -> [String: URL]
}
