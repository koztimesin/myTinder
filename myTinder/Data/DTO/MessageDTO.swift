//
//  MessageDTO.swift
//  myTinder
//
//  Created by Ismail on 29.10.2026.
//

import Foundation

/// Строка таблицы `messages`.
nonisolated struct MessageDTO: Decodable {
    
    let id: UUID
    let matchID: UUID
    let senderID: UUID
    let body: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case matchID = "match_id"
        case senderID = "sender"
        case body
        case createdAt = "created_at"
    }
    
    /// Переводит строку в доменную модель.
    /// - Returns: сообщение.
    func toDomain() -> Message {
        Message(id: id, matchID: matchID, senderID: senderID, body: body, sentAt: createdAt)
    }
}

/// Параметры вставки сообщения. `created_at` задаёт сервер (прав на эту колонку у клиента нет).
nonisolated struct SendMessageParams: Encodable {
    
    let id: UUID
    let matchID: UUID
    let sender: UUID
    let body: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case matchID = "match_id"
        case sender
        case body
    }
}

/// Работа с датами в формате Postgres для чата.
nonisolated enum ChatDateCoding {
    
    /// Декодер для записей Realtime: даты приходят строкой с микросекундами.
    /// - Returns: декодер с собственной стратегией дат.
    static func makeRealtimeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = parse(string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Не удалось разобрать дату: \(string)"
                )
            }
            return date
        }
        return decoder
    }
    
    /// Строка для фильтра по `created_at`.
    /// - Parameter date: дата курсора.
    /// - Returns: ISO 8601 с миллисекундами.
    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return formatter.string(from: date)
    }
    
    /// Разбирает дату Postgres: дробную часть приводит к трём цифрам.
    /// - Parameter string: строка вида `2026-10-29T09:00:00.123456+00:00`.
    /// - Returns: дата или `nil`, если строка не разобралась.
    private static func parse(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: normalized(string)) {
            return date
        }
        
        formatter.formatOptions = [.withInternetDateTime]
        
        return formatter.date(from: string)
    }
    
    /// Обрезает или дополняет дробную часть секунд до трёх цифр.
    /// - Parameter string: исходная строка.
    /// - Returns: строка с ровно тремя цифрами после точки (если точка была).
    private static func normalized(_ string: String) -> String {
        guard let dot = string.firstIndex(of: ".") else { return string }
        
        let afterDot = string.index(after: dot)
        let digitsEnd = string[afterDot...].firstIndex(where: { !$0.isNumber }) ?? string.endIndex
        let fraction = String(string[afterDot..<digitsEnd].prefix(3))
            .padding(toLength: 3, withPad: "0", startingAt: 0)
        
        return String(string[..<dot]) + "." + fraction + String(string[digitsEnd...])
    }
}
