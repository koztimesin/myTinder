//
//  ChatRepositoryProtocol.swift
//  myTinder
//
//  Created by Ismail on 09.11.2026.
//

import Foundation

/// Доступ к сообщениям диалога.
protocol ChatRepositoryProtocol: Sendable {
    
    /// Загружает страницу истории.
    /// - Parameters:
    ///   - matchID: матч.
    ///   - before: если задано, только сообщения старше этой даты.
    ///   - limit: размер страницы.
    /// - Returns: сообщения по возрастанию времени (самое старое первым).
    func fetchMessages(matchID: UUID, before: Date?, limit: Int) async throws -> [Message]
    
    /// Отправляет сообщение. Повторная отправка с тем же `id` считается успехом.
    /// - Parameters:
    ///   - id: клиентский идентификатор сообщения.
    ///   - matchID: матч.
    ///   - body: текст (уже без пробелов по краям).
    func send(id: UUID, matchID: UUID, body: String) async throws
    
    /// Отмечает диалог прочитанным для текущего пользователя.
    /// - Parameter matchID: матч.
    func markRead(matchID: UUID) async throws
    
    /// Открывает подписку на новые сообщения диалога.
    /// - Parameter matchID: матч.
    /// - Returns: поток событий. Завершается при ошибке подключения или когда потребитель
    ///   перестаёт его читать (подписка при этом закрывается).
    func events(matchID: UUID) -> AsyncStream<ChatEvent>
}
