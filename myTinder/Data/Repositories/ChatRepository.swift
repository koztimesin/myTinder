//
//  ChatRepository.swift
//  myTinder
//
//  Created by Ismail on 29.10.2026.
//

import Foundation
import Supabase

/// Событие потока чата.
enum ChatEvent: Sendable {
    /// Канал (пере)подключён: пора догрузить сообщения, пришедшие за время разрыва.
    case subscribed
    /// Пришло новое сообщение (своё или собеседника).
    case message(Message)
}

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

struct SupabaseChatRepository {
    
    let client: SupabaseClient
}

extension SupabaseChatRepository: ChatRepositoryProtocol {
    
    func fetchMessages(matchID: UUID, before: Date?, limit: Int) async throws -> [Message] {
        
        var query = client
            .from("messages")
            .select()
            .eq("match_id", value: matchID.uuidString)
        
        if let before {
            query = query.lt("created_at", value: ChatDateCoding.string(from: before))
        }
        
        let dtos: [MessageDTO] = try await query
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return dtos.reversed().map { $0.toDomain() }
    }
    
    func send(id: UUID, matchID: UUID, body: String) async throws {
        let userID = try await client.auth.session.user.id
        let params = SendMessageParams(id: id, matchID: matchID, sender: userID, body: body)
        
        do {
            try await client.from("messages").insert(params).execute()
        } catch let error as PostgrestError where error.code == PostgresErrorCode.uniqueViolation {
            // Сообщение с таким id уже есть: прошлая попытка дошла, ответ потерялся.
        }
    }
    
    func markRead(matchID: UUID) async throws {
        try await client
            .rpc("mark_match_read", params: ["p_match_id": matchID.uuidString])
            .execute()
    }
    
    func events(matchID: UUID) -> AsyncStream<ChatEvent> {
        
        AsyncStream { continuation in
            
            let task = Task {
                // Уникальное имя, чтобы не попасть на ещё не закрытый канал прошлого открытия чата.
                let topic = "chat-\(matchID.uuidString)-\(UUID().uuidString.prefix(8))"
                let channel = client.realtimeV2.channel(topic)
                let inserts = channel.postgresChange(
                    InsertAction.self, schema: "public", table: "messages",
                    filter: "match_id=eq.\(matchID.uuidString)"
                )
                let statuses = channel.statusChange
                await channel.subscribe()
                
                let decoder = ChatDateCoding.makeRealtimeDecoder()
                
                await withTaskGroup(of: Void.self) { group in
                    
                    group.addTask {
                        for await status in statuses where status == .subscribed {
                            continuation.yield(.subscribed)
                        }
                    }
                    
                    group.addTask {
                        for await action in inserts {
                            if let dto = try? action.decodeRecord(as: MessageDTO.self, decoder: decoder) {
                                continuation.yield(.message(dto.toDomain()))
                            }
                        }
                    }
                    
                    await group.next()
                    group.cancelAll()
                }
                
                await client.realtimeV2.removeChannel(channel)
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
