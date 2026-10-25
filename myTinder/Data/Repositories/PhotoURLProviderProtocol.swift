//
//  PhotoURLProviderProtocol.swift
//  myTinder
//
//  Created by Ismail on 25.10.2026.
//

import Foundation

/// Контракт выдачи временных ссылок на фото.
protocol PhotoURLProviderProtocol: Sendable {
    
    /// Возвращает ссылки для путей.
    /// - Parameter paths: пути файлов в бакете.
    /// - Returns: словарь «путь → ссылка». Пути, для которых ссылку получить не удалось
    ///   (нет сети, файл удалён), в словарь не попадают.
    func urls(for paths: [String]) async -> [String: URL]
}
