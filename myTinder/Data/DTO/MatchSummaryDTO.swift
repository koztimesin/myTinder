//
//  MatchSummaryDTO.swift
//  myTinder
//
//  Created by Ismail on 28.10.2026.
//

import Foundation

struct MatchSummaryDTO: Decodable {
    
    let matchID: UUID
    let matchedAt: Date
    let partnerID: UUID
    let partnerName: String
    let partnerPhotoPath: String?
    let lastMessageBody: String?
    let lastMessageAt: Date?
    let lastMessageSender: UUID?
    
    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case matchedAt = "matched_at"
        case partnerID = "partner_id"
        case partnerName = "partner_name"
        case partnerPhotoPath = "partner_photo_path"
        case lastMessageBody = "last_message_body"
        case lastMessageAt = "last_message_at"
        case lastMessageSender = "last_message_sender"
    }
    
    /// Переводит строку в доменную модель.
    /// - Parameter currentUserID: id текущего пользователя (нужен, чтобы понять, чьё последнее сообщение).
    /// - Returns: модель матча; последнее сообщение есть, только если пришли все его поля.
    func toDomain(currentUserID: UUID) -> MatchSummary {
        var lastMessage: LastMessage?
        
        if let body = lastMessageBody, let sentAt = lastMessageAt, let sender = lastMessageSender {
            lastMessage = LastMessage(body: body, sentAt: sentAt, isFromMe: sender == currentUserID)
        }
        
        return MatchSummary(
            id: matchID,
            matchedAt: matchedAt,
            partner: MatchPartner(id: partnerID, name: partnerName, photoPath: partnerPhotoPath),
            lastMessage: lastMessage
        )
    }
}

/// Запись о новом матче из Realtime: нужен только идентификатор.
struct MatchInsertDTO: Decodable {
    let id: UUID
}
